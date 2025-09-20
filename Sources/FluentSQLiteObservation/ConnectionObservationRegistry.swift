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

/// Registry to manage observation brokers per connection.
final actor ConnectionObservationRegistry: Sendable {
    static let shared = ConnectionObservationRegistry()

    private lazy var transactionObserverPool = TransactionObserverRegistry(
        onObservationShouldStart: { [weak self] in
            guard let self else {
                return
            }
            try await self.installBrokerHooks()
        },
        onObservationShouldStop: { [weak self] in
            guard let self else {
                return
            }
            await self.removeBrokerHooks()
        }
    )
    private var brokers: [ObjectIdentifier: DatabaseObservationBroker] = [:]

    private init() {}

    /// Returns existing broker for a connection if available.
    func broker(for connection: SQLiteConnection) -> DatabaseObservationBroker {
        brokers[ObjectIdentifier(connection)]!
    }

    /// Creates a broker or returns the existing one for the connection.
    @discardableResult
    func installBrokerIfNeeded(_ connection: SQLiteConnection) async throws -> DatabaseObservationBroker {
        let id = ObjectIdentifier(connection)

        if let existing = brokers[id] {
            // Idempotent; ensures hooks are present if observers already exist.
            if await transactionObserverPool.hasObservers {
                try await existing.installHooks()
            }
            return existing
        }

        // Optional opportunistic cleanup to avoid map bloat.
        await cleanup()

        let broker = try await DatabaseObservationBroker(
            connection: connection,
            transactionObserverPool: transactionObserverPool
        )
        brokers[id] = broker

        // If observers already exist, this broker should be live immediately.
        if await transactionObserverPool.hasObservers {
            try await broker.installHooks()
        }

        return broker
    }

    /// Removes brokers for closed connections and tears down their hooks.
    func cleanup() async {
        var toRemove: [ObjectIdentifier] = []
        for (id, broker) in brokers {
            if await broker.connectionIsClosed {
                await broker.removeHooks()
                toRemove.append(id)
            }
        }
        for id in toRemove {
            brokers[id] = nil
        }
    }

    /// Installs hooks on all live brokers.
    func installBrokerHooks() async throws {
        for broker in brokers.values {
            try await broker.installHooks()
        }
    }

    /// Removes hooks from all brokers.
    func removeBrokerHooks() async {
        for broker in brokers.values {
            await broker.removeHooks()
        }
    }

    func addObserver(_ observer: any TransactionObserver) async throws {
        try await transactionObserverPool.addObserver(observer)
    }

    func removeObserver(_ observer: any TransactionObserver) async {
        await transactionObserverPool.removeObserver(observer)
    }
}
