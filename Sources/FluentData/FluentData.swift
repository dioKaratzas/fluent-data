import Foundation
import Logging
import FluentSQLiteDriver
import NIOCore
import NIOConcurrencyHelpers
import SQLiteKit
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
    let storage: Storage
    let logger: Logger
    
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
    
    /// Shutdown the client and close all database connections
    public func shutdown() async {
        await self.storage.databases.shutdownAsync()
    }
    
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
}


// MARK: - Database Configuration

extension FluentData {
    /// Convenience method to configure SQLite database with URL only.
    /// - Parameters:
    ///   - url: The file URL for the SQLite database.
    ///   - id: The database ID to use. Defaults to "default".
    /// - Throws: `FluentDataError` if configuration fails.
    public func configureSQLite(url: URL, id: DatabaseID = DatabaseID(string: "default")) async throws {
#if SQLCipher
        try await configureSQLite(configuration: .init(id: id, url: url, encryption: .none, isDefault: true))
#else
        try await configureSQLite(configuration: .init(id: id, url: url, isDefault: true))
#endif
    }

    /// Configure SQLite database for the client.
    /// - Parameter configuration: The database configuration including encryption settings.
    /// - Throws: `FluentDataError` if configuration fails.
    public func configureSQLite(configuration: FluentDataConfiguration) async throws {
        // Validate that we don't have multiple default databases
        if configuration.isDefault {
            if let existingDefault = self.defaultDatabaseID {
                throw FluentDataError.multipleDefaultDatabases(
                    existing: existingDefault.string,
                    new: configuration.id.string
                )
            }
        }

        let sqliteConfig = SQLiteConfiguration(
            storage: .file(path: configuration.url.path)
        )

        self.databases.use(.sqlite(sqliteConfig), as: configuration.id)

        // Set as default if specified
        if configuration.isDefault {
            self.databases.default(to: configuration.id)
        }

#if SQLCipher
        // Set up encryption if configured
        if configuration.encryption.isEncrypted {
            try await setEncryptionKey(for: configuration.id, encryption: configuration.encryption)
        }
#endif
    }

#if SQLCipher
    // MARK: - SQLCipher Encryption
    
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
        guard let database = self.databases.database(databaseID, logger: self.logger, on: self.storage.eventLoopGroup.any()) else {
            throw FluentDataError.databaseNotConfigured
        }

        guard let sqliteDatabase = database as? SQLiteDatabase else {
            throw FluentDataError.notSQLiteDatabase
        }

        try await sqliteDatabase.withConnection { conn in
            switch encryption {
            case .none:
                break // No encryption needed
            case .password(let password):
                guard !password.isEmpty else {
                    throw FluentDataError.invalidPassphrase
                }
                try await conn.usePassphrase(password)
            case .data(let data):
                guard !data.isEmpty else {
                    throw FluentDataError.invalidPassphrase
                }
                try await conn.usePassphrase(data)
            }
        }
    }

    /// Change the passphrase of an existing encrypted database.
    /// - Parameters:
    ///   - databaseID: The database ID to change the passphrase for.
    ///   - newEncryption: The new encryption configuration to apply.
    /// - Throws: `FluentDataError` if the passphrase change fails.
    public func changePassphrase(for databaseID: DatabaseID, newEncryption: FluentDataEncryption) async throws {
        guard let database = self.databases.database(databaseID, logger: self.logger, on: self.storage.eventLoopGroup.any()) else {
            throw FluentDataError.databaseNotConfigured
        }

        guard let sqliteDatabase = database as? SQLiteDatabase else {
            throw FluentDataError.notSQLiteDatabase
        }

        do {
            try await sqliteDatabase.withConnection { conn in
                switch newEncryption {
                case .none:
                    // Remove encryption by setting empty passphrase
                    try await conn.changePassphrase("")
                case .password(let password):
                    guard !password.isEmpty else {
                        throw FluentDataError.invalidPassphrase
                    }
                    try await conn.changePassphrase(password)
                case .data(let data):
                    guard !data.isEmpty else {
                        throw FluentDataError.invalidPassphrase
                    }
                    try await conn.changePassphrase(data)
                }
            }
        } catch {
            throw FluentDataError.encryptionOperationFailed("Failed to change passphrase: \(error.localizedDescription)")
        }
    }
#endif

    /// Check if a default database is already configured
    public var hasDefaultDatabase: Bool {
        self.defaultDatabaseID != nil
    }
}

// MARK: - Internal Storage

extension FluentData {
    // Internal storage for FluentData state and configuration
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

    // Internal pagination settings storage
    struct PaginationSettings {
        var pageSizeLimit: PageLimit
    }
}
