//
//  Copyright © Dionysis Karatzas. All rights reserved.
//

import SQLiteNIO
import FluentKit
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
    public let url: URL
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
            url: URL,
            encryption: FluentDataEncryption = .none,
            isDefault: Bool = false,
            configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
        ) {
            self.id = id
            self.url = url
            self.encryption = encryption
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
            url: URL,
            password: String,
            isDefault: Bool = false,
            configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
        ) {
            self.init(
                id: id,
                url: url,
                encryption: .password(password),
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
            url: URL,
            passphraseData: Data,
            isDefault: Bool = false,
            configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
        ) {
            self.init(
                id: id,
                url: url,
                encryption: .data(passphraseData),
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
            url: URL,
            isDefault: Bool = false,
            configureConnection: (@Sendable (SQLiteConnection, Logger) -> EventLoopFuture<Void>)? = nil
        ) {
            self.id = id
            self.url = url
            self.isDefault = isDefault
            self.configureConnection = configureConnection
        }
    #endif
}
