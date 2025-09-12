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
import NIOConcurrencyHelpers

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
    unowned private let connection: SQLiteConnection

    private let baseValidatorToken: SQLiteHookToken

    /// Thread-safe accumulators for the current tracking window.
    private struct Accumulators {
        /// What a statement reads.
        var region = DatabaseRegion.empty

        /// What a statement writes.
        var operations: [DatabaseEventOperation] = []

        /// Not nil if a statement is a BEGIN/COMMIT/ROLLBACK/RELEASE transaction or
        /// savepoint statement.
        var transactionEffect: TransactionEffect?

        fileprivate var isDropStatement = false
    }

    private let accumulators = NIOLockedValueBox(Accumulators())

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
        self.connection = connection

        baseValidatorToken = try await connection.setAuthorizerValidator(lifetime: .pinned) { event in
            switch event.action {
            case .delete:
                guard let tableName = event.parameter1 else {
                    return .allow
                }
                if Self.observesDeletions(tableName) {
                    // Use SQLITE_IGNORE for DELETE operations to prevent truncate optimization.
                    // This ensures that sqlite3_update_hook notifies individual row deletions
                    // to transaction observers instead of treating them as bulk truncate operations.
                    // Without this, DELETE operations might be optimized away and observers
                    // won't receive proper notifications for each deleted row.
                    return .ignore
                } else {
                    return .allow
                }
            default:
                // Allow all other operations (CREATE, DROP, INSERT, UPDATE, SELECT, etc.)
                // to proceed normally. This establishes a stable base authorizer that
                // prevents SQLite from invalidating prepared statements when temporary
                // authorizers are added/removed later.
                return .allow
            }
        }
    }

    static func observesDeletions(_ tableName: String) -> Bool {
        true
    }

    deinit {
        baseValidatorToken.cancel()
    }

    func withRegionTracking<T: Sendable>(_ body: @Sendable () async throws -> T) async throws -> (
        result: T,
        region: DatabaseRegion,
        operations: [DatabaseEventOperation],
        transactionEffect: TransactionEffect?
    ) {
        try await connection.withAuthorizerObserver { event in
            self.handleAuthorizerEvent(event)
        } body: {
            let result = try await body()

            let snapshot = accumulators.withLockedValue { $0 }
            guard snapshot.region.isEmpty == false else {
                fatalError("No database region was tracked during authorizer observation.")
            }
            return (result, snapshot.region, snapshot.operations, snapshot.transactionEffect)
        }
    }

    private func resetAccumulators() {
        accumulators.withLockedValue { $0 = Accumulators() }
    }

    private func handleAuthorizerEvent(_ event: SQLiteAuthorizerEvent) {
        accumulators.withLockedValue { accumulators in
            switch event.action {
            // --- DDL that invalidates schema ---
            case .dropTable, .dropVTable, .dropTempTable,
                 .dropIndex, .dropTempIndex,
                 .dropView, .dropTempView,
                 .dropTrigger, .dropTempTrigger:
                accumulators.isDropStatement = true

            case .read:
                guard let table = event.parameter1, let column = event.parameter2 else {
                    break
                }
                if column.isEmpty {
                    // SELECT COUNT(*) FROM table
                    accumulators.region.formUnion(DatabaseRegion(table: table))
                } else {
                    // SELECT column FROM table
                    accumulators.region.formUnion(DatabaseRegion(table: table, columns: [column]))
                }

            case .insert:
                guard let table = event.parameter1 else {
                    break
                }
                accumulators.operations.append(.insert(tableName: table))

            case .delete:
                guard accumulators.isDropStatement == false, let table = event.parameter1 else {
                    break
                }

                // Deletions from sqlite_master and sqlite_temp_master are not like
                // other deletions: `sqlite3_update_hook` does not notify them, and
                // they are prevented when the truncate optimization is disabled.
                // Let's always authorize such deletions by returning SQLITE_OK:
                guard table != "sqlite_master",
                      table != "sqlite_temp_master" else {
                    break
                }

                accumulators.operations.append(.delete(tableName: table))

            case .update:
                guard let table = event.parameter1, let column = event.parameter2 else {
                    break
                }
                for (index, eventOperation) in accumulators.operations.enumerated() {
                    if case let .update(t, columnNames) = eventOperation, t == table {
                        var columnNames = columnNames
                        columnNames.insert(column)
                        accumulators.operations[index] = .update(tableName: table, columnNames: columnNames)
                        return
                    }
                }
                accumulators.operations.append(.update(tableName: table, columnNames: [column]))

            case .transaction:
                guard let effect = event.parameter1 else {
                    break
                }

                switch effect {
                case "BEGIN": accumulators.transactionEffect = .beginTransaction
                case "COMMIT": accumulators.transactionEffect = .commitTransaction
                case "ROLLBACK": accumulators.transactionEffect = .rollbackTransaction
                default: break
                }

            case .savepoint:
                guard let effect = event.parameter1, let name = event.parameter2 else {
                    break
                }
                switch effect {
                case "BEGIN": accumulators.transactionEffect = .beginSavepoint(name)
                case "RELEASE": accumulators.transactionEffect = .releaseSavepoint(name)
                case "ROLLBACK": accumulators.transactionEffect = .rollbackSavepoint(name)
                default: break
                }

            default:
                break
            }
        }
    }
}
