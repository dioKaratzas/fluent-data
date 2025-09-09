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

import SQLiteNIO

/// Manages SQLite statement authorization for database observation.
///
/// `StatementAuthorizer` establishes a permanent base authorizer that prevents SQLite's
/// statement invalidation behavior. When authorizers are changed or removed, SQLite
/// invalidates all prepared statements, causing issues.
///
/// This class installs a permanent "allow-all" base authorizer that stays active.
/// Subsequent temporary authorizers can be layered on top without affecting the base,
/// and when they're removed, the base authorizer remains, preventing statement invalidation.
final class StatementAuthorizer: Sendable {
    let autorizerCancelToken: SQLiteNIO.SQLiteHookToken?

    /// Initializes a permanent base authorizer to prevent statement invalidation.
    ///
    /// This creates a pinned authorizer that permanently allows all database operations.
    /// The purpose is to establish a stable base so that when temporary authorizers
    /// are added and removed later, SQLite won't invalidate prepared statements.
    ///
    /// SQLite invalidates prepared statements whenever:
    /// - An authorizer is set for the first time
    /// - An authorizer is removed (set to NULL)
    /// - An authorizer callback is replaced
    ///
    /// By keeping this base authorizer permanently installed, temporary authorizers
    /// can be safely used without triggering statement invalidation.
    ///
    /// - Parameter connection: The SQLite connection to install the base authorizer on.
    /// - Throws: SQLite errors if the authorizer cannot be installed.
    init(connection: SQLiteConnection) async throws {
        autorizerCancelToken = try await connection.setAuthorizerValidator(lifetime: .pinned) { event in
            switch event.action {
            case .delete:
                // Use SQLITE_IGNORE for DELETE operations to prevent truncate optimization.
                // This ensures that sqlite3_update_hook notifies individual row deletions
                // to transaction observers instead of treating them as bulk truncate operations.
                // Without this, DELETE operations might be optimized away and observers
                // won't receive proper notifications for each deleted row.
                return .ignore
            default:
                // Allow all other operations (CREATE, DROP, INSERT, UPDATE, SELECT, etc.)
                // to proceed normally. This establishes a stable base authorizer that
                // prevents SQLite from invalidating prepared statements when temporary
                // authorizers are added/removed later.
                return .allow
            }
        }
    }

    deinit {
        autorizerCancelToken?.cancel()
    }
}
