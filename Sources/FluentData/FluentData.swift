//===----------------------------------------------------------------------===//
//
// This source file is part of the FluentData open source project
//
// Copyright (c) Dionysios Karatzas
// Licensed under the MIT license
//
// See LICENSE.txt for license information
//
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

import Logging
import NIOCore
import SQLiteKit
import Foundation
import FluentSQLiteDriver
import NIOConcurrencyHelpers
#if SQLCipher
    import SQLiteNIO
#endif

/// A client-compatible Fluent database manager for macOS and iOS apps.
///
/// `FluentData` provides database functionality without server-specific dependencies,
/// designed specifically for macOS, iOS, watchOS, and tvOS applications.
///
/// ## Features
/// - Multiple database support with DatabaseID extensions
/// - Query history tracking for debugging
/// - PageLimit pagination following Fluent's pattern
/// - Async/await support throughout
/// - Thread-safe operations using NIOLockedValueBox
/// - Automatic database cleanup and resource management
/// - SQLCipher encryption support (when available)
///
/// ## Usage
/// ```swift
/// let provider = FluentData(logger: Logger(label: "app"))
/// try await provider.configureSQLite(url: databaseURL)
/// provider.migrations.add(CreateUser())
/// try await provider.autoMigrate()
/// ```
public final class FluentData: Sendable {
    // MARK: - Properties

    let storage: Storage
    let logger: Logger

    // MARK: - Public Initialization

    /// Initialize a new FluentData instance.
    /// - Parameter logger: The logger to use for database operations. Defaults to "fluent-data".
    public init(logger: Logger = Logger(label: "fluent-data")) {
        self.logger = logger
        self.storage = Storage(logger: logger)
    }

    deinit {
        // Note: Cannot call async shutdown in deinit
        // Users should call shutdown() explicitly before deallocation
    }

    // MARK: - Public Database Access

    /// Get the default database
    public var db: any Database {
        self.db(nil)
    }

    /// Get a database by ID.
    /// - Parameter id: The database ID to retrieve, or nil for the default database.
    /// - Returns: The database instance for the specified ID.
    public func db(_ id: DatabaseID?) -> any Database {
        self.storage.databases.database(
            id,
            logger: self.logger,
            on: self.storage.eventLoopGroup.any(),
            history: self.storage.historyEnabled.withLockedValue { $0 } ? QueryHistory() : nil,
            pageSizeLimit: self.storage.pagination.withLockedValue { $0.pageSizeLimit.value }
        )!
    }

    /// Set a specific database as the default.
    /// - Parameter id: The database ID to set as default.
    public func setDefaultDatabase(_ id: DatabaseID) {
        self.storage.defaultDatabaseID.withLockedValue { $0 = id }
        self.databases.default(to: id)
    }

    /// Get the current default database ID
    public var defaultDatabaseID: DatabaseID? {
        self.storage.defaultDatabaseID.withLockedValue { $0 }
    }

    /// Check if a default database is already configured
    public var hasDefaultDatabase: Bool {
        self.defaultDatabaseID != nil
    }

    // MARK: - Public Database Managers

    /// Get the databases manager
    public var databases: Databases {
        self.storage.databases
    }

    /// Get the migrations manager
    public var migrations: Migrations {
        self.storage.migrations
    }

    /// Get the migrator
    public var migrator: Migrator {
        .init(
            databases: self.databases,
            migrations: self.migrations,
            logger: self.logger,
            on: self.storage.eventLoopGroup.any(),
            migrationLogLevel: self.storage.migrationLogLevel.withLockedValue { $0 }
        )
    }

    // MARK: - Public Migration Methods

    /// Automatically runs forward migrations without confirmation.
    /// - Throws: Migration errors if the migration process fails.
    public func autoMigrate() async throws {
        _ = try await self.migrator.setupIfNeeded().flatMap {
            self.migrator.prepareBatch()
        }.get()
    }

    /// Automatically runs reverse migrations without confirmation.
    /// - Throws: Migration errors if the revert process fails.
    public func autoRevert() async throws {
        _ = try await self.migrator.setupIfNeeded().flatMap {
            self.migrator.revertAllBatches()
        }.get()
    }

    // MARK: - Public Configuration Properties

    /// Set migration log level
    public var migrationLogLevel: Logger.Level {
        get { self.storage.migrationLogLevel.withLockedValue { $0 } }
        set { self.storage.migrationLogLevel.withLockedValue { $0 = newValue } }
    }

    /// Enable or disable query history
    public var historyEnabled: Bool {
        get { self.storage.historyEnabled.withLockedValue { $0 } }
        set { self.storage.historyEnabled.withLockedValue { $0 = newValue } }
    }

    /// Get the current query history
    public var history: [DatabaseQuery] {
        self.storage.history.withLockedValue { $0 }
    }

    /// Clear the query history
    public func clearHistory() {
        self.storage.history.withLockedValue { $0.removeAll() }
    }

    /// Set pagination page size limit
    public var pageSizeLimit: PageLimit {
        get { self.storage.pagination.withLockedValue { $0.pageSizeLimit } }
        set { self.storage.pagination.withLockedValue { $0.pageSizeLimit = newValue } }
    }

    // MARK: - Public Lifecycle Methods

    /// Shutdown the client and close all database connections
    public func shutdown() async {
        await self.storage.databases.shutdownAsync()
    }
}

// MARK: - Public Database Configuration

extension FluentData {
    /// Configure SQLite database for the client.
    /// - Parameter configuration: The database configuration including encryption settings.
    /// - Throws: `FluentDataError` if configuration fails.
    public func configureSQLite(configuration: FluentDataConfiguration) async throws {
        // Prevent multiple defaults for clarity
        if configuration.isDefault, let existing = defaultDatabaseID {
            throw FluentDataError.multipleDefaultDatabases(
                existing: existing.string,
                new: configuration.id.string
            )
        }

        // Build base SQLite configuration
        let sqliteConfig = SQLiteConfiguration(
            storage: .file(path: configuration.url.path)
        )

        // Connection configuration pipeline (encryption → user hook)
        let configureConn: @Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void> = { conn, logger in
            #if SQLCipher
                let setEncryption: EventLoopFuture<Void> = configuration.encryption.isEncrypted
                    ? self.setEncryptionKey(conn, encryption: configuration.encryption)
                    : conn.eventLoop.makeSucceededFuture(())
            #else
                let setEncryption: EventLoopFuture<Void> = conn.eventLoop.makeSucceededFuture(())
            #endif

            return setEncryption.flatMap {
                configuration.configureConnection?(conn, logger)
                    ?? conn.eventLoop.makeSucceededFuture(())
            }
        }

        // Register the driver
        databases.use(
            .sqlite(sqliteConfig, configureConnection: configureConn),
            as: configuration.id
        )

        // Make default if requested
        if configuration.isDefault {
            databases.default(to: configuration.id)
        }
    }
}

#if SQLCipher

    // MARK: - Public SQLCipher Encryption

    extension FluentData {
        /// Set encryption key for a database using encryption configuration.
        ///
        /// This method allows you to add encryption to an already configured database
        /// or change the encryption settings of an existing database.
        ///
        /// - Parameters:
        ///   - databaseID: The database ID to configure encryption for.
        ///   - encryption: The encryption configuration to apply.
        /// - Throws: `FluentDataError` if encryption setup fails.
        public func setEncryptionKey(for databaseID: DatabaseID, encryption: FluentDataEncryption) async throws {
            guard let database = self.databases.database(
                databaseID,
                logger: self.logger,
                on: self.storage.eventLoopGroup.any()
            ) else {
                throw FluentDataError.databaseNotConfigured
            }

            guard let sqliteDatabase = database as? SQLiteDatabase else {
                throw FluentDataError.notSQLiteDatabase
            }

            try await sqliteDatabase.withConnection { conn in
                try await self.setEncryptionKey(conn, encryption: encryption).get()
            }
        }

        /// Change the passphrase of an existing encrypted database.
        /// - Parameters:
        ///   - databaseID: The database ID to change the passphrase for.
        ///   - newEncryption: The new encryption configuration to apply.
        /// - Throws: `FluentDataError` if the passphrase change fails.
        public func changePassphrase(for databaseID: DatabaseID, newEncryption: FluentDataEncryption) async throws {
            guard let database = self.databases.database(
                databaseID,
                logger: self.logger,
                on: self.storage.eventLoopGroup.any()
            ) else {
                throw FluentDataError.databaseNotConfigured
            }

            guard let sqliteDatabase = database as? SQLiteDatabase else {
                throw FluentDataError.notSQLiteDatabase
            }

            do {
                try await sqliteDatabase.withConnection { conn in
                    try await self.changeEncryptionKey(conn, newEncryption: newEncryption).get()
                }
            } catch {
                throw FluentDataError.encryptionOperationFailed("Failed to change passphrase: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private SQLCipher Helpers

    extension FluentData {
        /// Private helper method to set encryption key for a connection.
        private func setEncryptionKey(_ connection: SQLiteConnection, encryption: FluentDataEncryption) -> EventLoopFuture<Void> {
            switch encryption {
            case .none:
                return connection.eventLoop.makeSucceededFuture(())
            case let .password(password):
                guard !password.isEmpty else {
                    return connection.eventLoop.makeFailedFuture(FluentDataError.invalidPassphrase)
                }
                return connection.usePassphrase(password)
            case let .data(data):
                guard !data.isEmpty else {
                    return connection.eventLoop.makeFailedFuture(FluentDataError.invalidPassphrase)
                }
                return connection.usePassphrase(data)
            }
        }

        /// Private helper method to change encryption key for a connection.
        private func changeEncryptionKey(_ connection: SQLiteConnection, newEncryption: FluentDataEncryption) -> EventLoopFuture<Void> {
            switch newEncryption {
            case .none:
                return connection.changePassphrase("")
            case let .password(password):
                guard !password.isEmpty else {
                    return connection.eventLoop.makeFailedFuture(FluentDataError.invalidPassphrase)
                }
                return connection.changePassphrase(password)
            case let .data(data):
                guard !data.isEmpty else {
                    return connection.eventLoop.makeFailedFuture(FluentDataError.invalidPassphrase)
                }
                return connection.changePassphrase(data)
            }
        }
    }
#endif

// MARK: - Internal Storage

extension FluentData {
    /// Internal storage for FluentData state and configuration
    final class Storage: Sendable {
        let databases: Databases
        let migrations: Migrations
        let eventLoopGroup: any EventLoopGroup
        let migrationLogLevel: NIOLockedValueBox<Logger.Level>
        let logger: Logger
        let historyEnabled: NIOLockedValueBox<Bool>
        let history: NIOLockedValueBox<[DatabaseQuery]>
        let pagination: NIOLockedValueBox<PaginationSettings>
        let defaultDatabaseID: NIOLockedValueBox<DatabaseID?>

        init(logger: Logger) {
            self.logger = logger
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            self.databases = Databases(threadPool: NIOThreadPool.singleton, on: self.eventLoopGroup)
            self.migrations = .init()
            self.migrationLogLevel = .init(.info)
            self.historyEnabled = .init(false)
            self.history = .init([])
            self.pagination = .init(PaginationSettings(pageSizeLimit: .noLimit))
            self.defaultDatabaseID = .init(nil)
        }
    }

    /// Internal pagination settings storage
    struct PaginationSettings {
        var pageSizeLimit: PageLimit
    }
}
