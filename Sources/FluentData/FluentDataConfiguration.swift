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

import NIO
import SQLiteNIO
import FluentKit
import SQLiteKit
import Foundation

#if SQLCipher
    /// Encryption configuration for SQLCipher databases.
    ///
    /// Defines the encryption options available for SQLCipher-enabled databases.
    /// Supports string passwords, raw data passphrases, or no encryption.
    public enum FluentDataEncryption: Sendable {
        case none
        case password(String)
        case data(Data)

        // Check if encryption is enabled
        var isEncrypted: Bool {
            switch self {
            case .none:
                return false
            case .password, .data:
                return true
            }
        }
    }
#endif

/// Database configuration for FluentData.
///
/// Contains all the necessary information to configure a SQLite database,
/// including encryption settings when SQLCipher is available.
///
/// ## Usage
/// ```swift
/// // Basic configuration
/// let config = FluentDataConfiguration(id: .main, url: dbURL)
///
/// // With encryption
/// let config = FluentDataConfiguration(id: .main, url: dbURL, password: "secret")
/// ```
public struct FluentDataConfiguration: Sendable {
    public let id: DatabaseID
    public let sqliteConfiguration: SQLiteConfiguration
    public let connectionPoolTimeout: TimeAmount
    public let dataEncoder: SQLiteDataEncoder
    public let dataDecoder: SQLiteDataDecoder
    public let sqlLogLevel: Logger.Level
    #if SQLCipher
        public let encryption: FluentDataEncryption
    #endif
    public let isDefault: Bool
    public let configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)?

    #if SQLCipher
        /// Initialize a database configuration with encryption support.
        /// - Parameters:
        ///   - id: The database identifier.
        ///   - url: The file URL for the SQLite database.
        ///   - encryption: The encryption configuration. Defaults to no encryption.
        ///   - isDefault: Whether this should be the default database. Defaults to false.
        public init(
            id: DatabaseID,
            sqliteConfiguration: SQLiteConfiguration,
            encryption: FluentDataEncryption = .none,
            connectionPoolTimeout: TimeAmount = .seconds(10),
            dataEncoder: SQLiteDataEncoder = .init(),
            dataDecoder: SQLiteDataDecoder = .init(),
            sqlLogLevel: Logger.Level = .debug,
            isDefault: Bool = false,
            configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
        ) {
            self.id = id
            self.sqliteConfiguration = sqliteConfiguration
            self.encryption = encryption
            self.connectionPoolTimeout = connectionPoolTimeout
            self.dataEncoder = dataEncoder
            self.dataDecoder = dataDecoder
            self.sqlLogLevel = sqlLogLevel
            self.isDefault = isDefault
            self.configureConnection = configureConnection
        }

        /// Convenience initializer with string password.
        /// - Parameters:
        ///   - id: The database identifier.
        ///   - url: The file URL for the SQLite database.
        ///   - password: The string password for encryption.
        ///   - isDefault: Whether this should be the default database. Defaults to false.
        public init(
            id: DatabaseID,
            sqliteConfiguration: SQLiteConfiguration,
            password: String,
            connectionPoolTimeout: TimeAmount = .seconds(10),
            dataEncoder: SQLiteDataEncoder = .init(),
            dataDecoder: SQLiteDataDecoder = .init(),
            sqlLogLevel: Logger.Level = .debug,
            isDefault: Bool = false,
            configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
        ) {
            self.init(
                id: id,
                sqliteConfiguration: sqliteConfiguration,
                encryption: .password(password),
                connectionPoolTimeout: connectionPoolTimeout,
                dataEncoder: dataEncoder,
                dataDecoder: dataDecoder,
                sqlLogLevel: sqlLogLevel,
                isDefault: isDefault,
                configureConnection: configureConnection
            )
        }

        /// Convenience initializer with data passphrase.
        /// - Parameters:
        ///   - id: The database identifier.
        ///   - url: The file URL for the SQLite database.
        ///   - passphraseData: The raw data passphrase for encryption.
        ///   - isDefault: Whether this should be the default database. Defaults to false.
        public init(
            id: DatabaseID,
            sqliteConfiguration: SQLiteConfiguration,
            passphraseData: Data,
            connectionPoolTimeout: TimeAmount = .seconds(10),
            dataEncoder: SQLiteDataEncoder = .init(),
            dataDecoder: SQLiteDataDecoder = .init(),
            sqlLogLevel: Logger.Level = .debug,
            isDefault: Bool = false,
            configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
        ) {
            self.init(
                id: id,
                sqliteConfiguration: sqliteConfiguration,
                encryption: .data(passphraseData),
                connectionPoolTimeout: connectionPoolTimeout,
                dataEncoder: dataEncoder,
                dataDecoder: dataDecoder,
                sqlLogLevel: sqlLogLevel,
                isDefault: isDefault,
                configureConnection: configureConnection
            )
        }
    #else
        /// Initialize a database configuration without encryption support.
        /// - Parameters:
        ///   - id: The database identifier.
        ///   - url: The file URL for the SQLite database.
        ///   - isDefault: Whether this should be the default database. Defaults to false.
        public init(
            id: DatabaseID,
            sqliteConfiguration: SQLiteConfiguration,
            connectionPoolTimeout: TimeAmount = .seconds(10),
            dataEncoder: SQLiteDataEncoder = .init(),
            dataDecoder: SQLiteDataDecoder = .init(),
            sqlLogLevel: Logger.Level = .debug,
            isDefault: Bool = false,
            configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
        ) {
            self.id = id
            self.sqliteConfiguration = sqliteConfiguration
            self.connectionPoolTimeout = connectionPoolTimeout
            self.dataEncoder = dataEncoder
            self.dataDecoder = dataDecoder
            self.sqlLogLevel = sqlLogLevel
            self.isDefault = isDefault
            self.configureConnection = configureConnection
        }
    #endif
}
