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
import Foundation

/// Manages database observation for a single SQLite connection
final actor DatabaseObservationBroker: Sendable {
    /// Associated SQLite connection
    unowned private let connection: SQLiteConnection

    /// Statement authorizer to enforce observation rules
    private let statementAuthorizer: StatementAuthorizer

    private let transactionObserverRegistry: TransactionObserverRegistry

    /// Registered query observers
    private var hookTokens: [SQLiteNIO.SQLiteHookToken] = []

    private var areHooksInstalled = false

    /// Creates broker and installs statement authorizer
    init(connection: SQLiteConnection, transactionObserverPool: TransactionObserverRegistry) async throws {
        guard connection.isClosed == false else {
            throw FluentSQLiteObservationError.sqliteConnectionClosed
        }
        self.connection = connection
        self.transactionObserverRegistry = transactionObserverPool
        statementAuthorizer = try await StatementAuthorizer(connection: connection)
    }

    deinit {
        // Actor deinit runs on system executor; make a best-effort synchronous cleanup.
        // Tokens are thread-safe to cancel; no 'await' here.
        for token in hookTokens {
            token.cancel()
        }
    }

    /// Returns true if the associated connection is closed
    var connectionIsClosed: Bool {
        connection.isClosed
    }

    /// Placeholder for future hook installation
    func installHooks() async throws {
        guard !areHooksInstalled else {
            return
        }
        guard connection.isClosed == false else {
            return
        }

        let updateToken = try await connection.addUpdateObserver(lifetime: .pinned) { event in
        }

        let commitToken = try await connection.addCommitObserver(lifetime: .pinned) { event in
        }

        let rollbackToken = try await connection.addRollbackObserver(lifetime: .pinned) { event in
        }

        hookTokens.append(contentsOf: [updateToken, commitToken, rollbackToken])

        areHooksInstalled = true
    }

    /// Cancels all hook tokens and cleans up resources
    func removeHooks() {
        guard areHooksInstalled else {
            return
        }
        for token in hookTokens {
            token.cancel()
        }
        hookTokens.removeAll()
        areHooksInstalled = false
    }

    /// Run a statement on *this* connection while tracking region/ops via authorizer
    func withRegionTracking<T: Sendable>(_ body: @Sendable () async throws -> T) async throws -> (
        result: T,
        region: DatabaseRegion,
        operations: [DatabaseEventOperation],
        transactionEffect: TransactionEffect?
    ) {
        try await statementAuthorizer.withRegionTracking(body)
    }
}
