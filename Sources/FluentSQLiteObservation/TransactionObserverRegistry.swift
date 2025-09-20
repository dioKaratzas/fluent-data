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

import Foundation
import SQLiteNIO

/// Pool that tracks registered transaction observers and signals when
/// observation should start/stop based on the 0↔1 threshold.
final actor TransactionObserverRegistry: Sendable {
    // MARK: - Stored State

    /// Registered transaction observers (identity-based).
    private var transactionObservers: [any TransactionObserver] = []

    /// Triggered when the pool goes from 0 → 1 observers.
    private let onObservationShouldStart: (@Sendable () async throws -> Void)?

    /// Triggered when the pool goes from 1 → 0 observers.
    private let onObservationShouldStop: (@Sendable () async -> Void)?

    // MARK: - Init

    init(
        onObservationShouldStart: (@Sendable () async throws -> Void)? = nil,
        onObservationShouldStop: (@Sendable () async -> Void)? = nil
    ) {
        self.onObservationShouldStart = onObservationShouldStart
        self.onObservationShouldStop = onObservationShouldStop
    }

    // MARK: - Introspection

    /// Whether there is at least one observer registered.
    var hasObservers: Bool { !transactionObservers.isEmpty }

    /// The current number of observers.
    var count: Int { transactionObservers.count }

    // MARK: - Mutation

    /// Adds an observer. If this is the first one, signals that observation should start.
    func addObserver(_ observer: any TransactionObserver) async throws {
        let wasEmpty = transactionObservers.isEmpty
        transactionObservers.append(observer)

        if wasEmpty {
            // First observer registered → tell the registry to install hooks.
            try await onObservationShouldStart?()
        }
    }

    /// Removes a specific observer by identity. If the pool becomes empty,
    /// signals that observation should stop.
    func removeObserver(_ observer: any TransactionObserver) async {
        let hadAny = !transactionObservers.isEmpty
        transactionObservers.removeAll { $0 === observer }

        if hadAny, transactionObservers.isEmpty {
            // Last observer removed → tell the registry to remove hooks.
            await onObservationShouldStop?()
        }
    }

    /// Removes all observers at once and signals stop if we transitioned to empty.
    func removeAllObservers() async {
        guard !transactionObservers.isEmpty else {
            return
        }
        transactionObservers.removeAll()
        await onObservationShouldStop?()
    }

    /// Notify all interested observers of a database change
    func notifyChange(event: SQLiteUpdateEvent) async {
        for observer in transactionObservers {
            await observer.databaseDidChange(with: event)
        }
    }
}
