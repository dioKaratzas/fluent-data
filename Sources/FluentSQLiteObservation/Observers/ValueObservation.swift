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

import FluentKit
import SQLiteNIO
import Foundation

public struct FluentValueObservation<Value: Sendable>: Sendable {
    private let fetch: @Sendable (any Database) async throws -> Value

    /// Creates a value observation that tracks the results of a database operation.
    ///
    /// - Parameter fetch: A closure that performs the database operation to observe.
    ///   This closure will be called initially and whenever relevant changes occur.
    public static func tracking(
        fetch: @escaping @Sendable (any Database) async throws -> Value
    ) -> FluentValueObservation<Value> {
        FluentValueObservation(fetch: fetch)
    }

    /// Starts the observation and returns a cancellable token.
    ///
    /// - Parameters:
    ///   - database: The database to observe
    ///   - onChange: Callback called with new values when changes occur
    /// - Returns: A cancellable token to stop the observation
    public func start(
        in database: any Database,
        onChange: @Sendable @escaping (Value) async throws -> Void
    ) async throws -> FluentObservationCancellable {
        // Discover the region by tracking what the fetch actually reads
        // 2) Perform initial fetch AFTER releasing the connection to avoid pool deadlocks
        //    If we need to discover the region, do that during the first fetch
        let initialValue: Value

        let (value, region) = try await self.fetchWithRegionDiscovery(database: database)
        initialValue = value

        // Update the observer with the discovered region
        let observer = FluentValueObserver(
            database: database,
            fetch: fetch,
            onChange: onChange,
            observedRegion: region
        )

        try await onChange(initialValue)

        try await ConnectionObservationRegistry.shared.addObserver(observer)

        return FluentObservationCancellable {
            await ConnectionObservationRegistry.shared.removeObserver(observer)
        }
    }

    /// Executes the fetch function while tracking what database regions it accesses
    private func fetchWithRegionDiscovery(database: any Database) async throws -> (Value, DatabaseRegion) {
        guard let sqliteDatabase = database as? SQLiteDatabase else {
            throw FluentSQLiteObservationError.unsupportedDatabase
        }

        return try await sqliteDatabase.withConnection { conn in
            let broker = await ConnectionObservationRegistry.shared.broker(for: conn)
            // Execute the fetch function with region tracking
            let result = try await broker.withRegionTracking {
                try await self.fetch(database)
            }

            return (result.result, result.region)
        }
    }
}

private final actor FluentValueObserver<Value: Sendable>: TransactionObserver, Sendable {
    private let database: any Database
    private let fetch: @Sendable (any Database) async throws -> Value
    private let onChange: @Sendable (Value) async throws -> Void
    private let observedRegion: DatabaseRegion

    // TODO: [OBSERVATION]: Add state for tracking pending changes and preventing redundant notifications

    init(
        database: any Database,
        fetch: @Sendable @escaping (any Database) async throws -> Value,
        onChange: @Sendable @escaping (Value) async throws -> Void,
        observedRegion: DatabaseRegion
    ) {
        self.database = database
        self.fetch = fetch
        self.onChange = onChange
        self.observedRegion = observedRegion
    }

    func observes(operation: DatabaseEventOperation) async -> Bool {
        observedRegion.isModified(by: operation)
    }

    func databaseDidChange() async {
        // TODO: [OBSERVATION]: Schedule re-fetch when changes detected
    }

    func databaseDidChange(with event: SQLiteNIO.SQLiteUpdateEvent) async {
        // TODO: [OBSERVATION]: Process specific event details for context
    }

    func databaseWillCommit() async throws {
        // TODO: [OBSERVATION]: Add optional pre-commit validation
    }

    // After a commit, re-fetch and notify if the region was modified
    func databaseDidCommit() async {
        let database = self.database

        do {
            let newValue = try await self.fetch(database)
            try await self.onChange(newValue)
        } catch {
            // Log error but don't crash - observation continues
            print("⚠️ ValueObservation re-fetch failed: \(error)")
        }
    }

    // On rollback, also re-fetch to ensure consistency
    func databaseDidRollback() async {
        let database = self.database

        do {
            let newValue = try await self.fetch(database)
            try await self.onChange(newValue)
        } catch {
            // Log error but don't crash - observation continues
            print("⚠️ ValueObservation rollback re-fetch failed: \(error)")
        }
    }
}

/// A cancellable token for database observations.
public final class FluentObservationCancellable: @unchecked Sendable {
    private let cancelAction: @Sendable () async -> Void
    private var isCancelled = false

    public init(_ cancelAction: @escaping @Sendable () async -> Void) {
        self.cancelAction = cancelAction
    }

    /// Cancels the observation.
    /// It's safe to call this multiple times.
    public func cancel() async {
        guard !isCancelled else {
            return
        }
        isCancelled = true
        await cancelAction()
    }

    deinit {
        let cancelAction = self.cancelAction
        Task {
            await cancelAction()
        }
    }
}

// MARK: - AsyncSequence and Combine Extensions

extension FluentValueObservation {
    // TODO: [OBSERVATION]: Add AsyncSequence support
    // public func values(in database: any Database) -> AsyncThrowingStream<Value, Error> {
    //     // Return AsyncThrowingStream that yields values when database changes
    // }
}

#if canImport(Combine)
    import Combine

    extension FluentValueObservation {
        // TODO: [OBSERVATION]: Add Combine Publisher support
        // public func publisher(in database: any Database) -> AnyPublisher<Value, Error> {
        //     // Return Combine Publisher that emits values when database changes
        //     // Users can then use .receive(on: .main) for threading control
        // }
    }
#endif
