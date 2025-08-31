//
//  Copyright © Dionysis Karatzas. All rights reserved.
//

import Foundation

/// Errors that can occur in FluentData.
///
/// All errors are organized by category and provide localized error descriptions
/// for better debugging and user experience.
public enum FluentDataError: Error, LocalizedError {
    // MARK: - Database Configuration Errors

    /// The requested database has not been configured.
    case databaseNotConfigured

    /// Multiple databases are configured as default.
    case multipleDefaultDatabases(existing: String, new: String)

    /// The database is not a SQLite database.
    case notSQLiteDatabase

    // MARK: - Encryption Errors

    /// The provided passphrase is invalid or empty.
    case invalidPassphrase

    /// An encryption operation failed.
    case encryptionOperationFailed(String)

    public var errorDescription: String? {
        switch self {
        // Database Configuration Errors
        case .databaseNotConfigured:
            return "Database is not configured"
        case let .multipleDefaultDatabases(existing, new):
            return "Multiple default databases configured. Existing: \(existing), New: \(new)"
        case .notSQLiteDatabase:
            return "Database is not a SQLite database"
        // Encryption Errors
        case .invalidPassphrase:
            return "Invalid passphrase provided"
        case let .encryptionOperationFailed(message):
            return "Encryption operation failed: \(message)"
        }
    }
}
