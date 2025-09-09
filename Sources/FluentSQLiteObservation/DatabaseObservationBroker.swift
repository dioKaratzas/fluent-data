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

    private init() {
        fatalError("Use shared instance")
    }

    /// Returns existing broker for connection if available
    func broker(for connection: SQLiteConnection) -> DatabaseObservationBroker? {
        let connectionId = ObjectIdentifier(connection)

        if let existingBroker = brokers[connectionId] {
            return existingBroker
        }
        return nil
    }

    /// Creates new broker or returns existing one for the connection
    @discardableResult
    func createBroker(for connection: SQLiteConnection) async throws -> DatabaseObservationBroker {
        let connectionId = ObjectIdentifier(connection)

        if let existingBroker = broker(for: connection) {
            return existingBroker
        }

        let newBroker = try await DatabaseObservationBroker(connection: connection)
        brokers[connectionId] = newBroker
        return newBroker
    }

    /// Removes broker for the given connection
    func removeBroker(for connection: SQLiteConnection) {
        let connectionId = ObjectIdentifier(connection)
        brokers.removeValue(forKey: connectionId)
    }

    /// Removes brokers for closed connections to prevent memory leaks
    func cleanup() async {
        var updatedBrokers: [ObjectIdentifier: DatabaseObservationBroker] = [:]

        for (id, broker) in brokers {
            if await broker.connectionIsClosed {
                updatedBrokers[id] = broker
            }
        }

        brokers = updatedBrokers
    }
}

/// Manages database observation for a single SQLite connection
final actor DatabaseObservationBroker: Sendable {
    unowned private let connection: SQLiteConnection
    private let statementAuthorizer: StatementAuthorizer

    private var hookTokens: [SQLiteNIO.SQLiteHookToken] = []

    /// Creates broker and installs statement authorizer
    init(connection: SQLiteConnection) async throws {
        guard connection.isClosed == false else {
            throw FluentSQLiteObservationError.sqliteConnectionClosed
        }
        self.connection = connection
        statementAuthorizer = try await StatementAuthorizer(connection: connection)
    }

    /// Returns true if the associated connection is closed
    var connectionIsClosed: Bool {
        connection.isClosed
    }

    /// Placeholder for future hook installation
    func installHooksIfNeeded() {}

    /// Cancels all hook tokens and cleans up resources
    func removeHooks() {
        for token in hookTokens {
            token.cancel()
        }
        hookTokens.removeAll()
    }
}
