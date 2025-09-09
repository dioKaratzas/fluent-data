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

/// Registry to manage observation brokers per connection
final actor ConnectionObservationRegistry: Sendable {
    static let shared = ConnectionObservationRegistry()

    private var brokers: [ObjectIdentifier: DatabaseObservationBroker] = [:]

    private init() {}

    /// Returns existing broker for a connection if available.
    func broker(for connection: SQLiteConnection) -> DatabaseObservationBroker? {
        brokers[ObjectIdentifier(connection)]
    }

    /// Creates a broker or returns the existing one for the connection.
    @discardableResult
    func createBroker(for connection: SQLiteConnection) async throws -> DatabaseObservationBroker {
        let id = ObjectIdentifier(connection)

        if let existing = brokers[id] {
            return existing
        }

        // Optional opportunistic cleanup to avoid map bloat.
        await cleanup()

        let broker = try await DatabaseObservationBroker(connection: connection)
        brokers[id] = broker
        return broker
    }

    /// Removes brokers for closed connections and tears down their hooks.
    func cleanup() async {
        // First, collect which are closed so we can remove hooks outside the filter pass.
        var toRemove: [ObjectIdentifier] = []
        for (id, broker) in brokers {
            if await broker.connectionIsClosed {
                toRemove.append(id)
            }
        }

        // Tear down hooks before dropping references.
        for id in toRemove {
            if let broker = brokers[id] {
                await broker.removeHooks()
            }
        }

        // Keep only open brokers.
        brokers = brokers.filter { key, _ in !toRemove.contains(key) }
    }

    func installBrokerHooks() async throws {
        for broker in brokers.values {
            try await broker.installHooks()
        }
    }
}

/// Manages database observation for a single SQLite connection
final actor DatabaseObservationBroker: Sendable {
    /// Associated SQLite connection
    unowned private let connection: SQLiteConnection

    /// Statement authorizer to enforce observation rules
    private let statementAuthorizer: StatementAuthorizer

    /// Registered query observers
    private var hookTokens: [SQLiteNIO.SQLiteHookToken] = []

    private var areHooksInstalled = false

    /// Creates broker and installs statement authorizer
    init(connection: SQLiteConnection) async throws {
        guard connection.isClosed == false else {
            throw FluentSQLiteObservationError.sqliteConnectionClosed
        }
        self.connection = connection
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

        let rollbackTOken = try await connection.addRollbackObserver(lifetime: .pinned) { event in
        }

        hookTokens.append(contentsOf: [updateToken, commitToken, rollbackTOken])
    }

    /// Cancels all hook tokens and cleans up resources
    func removeHooks() {
        guard !hookTokens.isEmpty else {
            return
        }
        for token in hookTokens {
            token.cancel()
        }
        hookTokens.removeAll()
        areHooksInstalled = false
    }
}
