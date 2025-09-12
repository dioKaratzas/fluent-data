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

/// A type that tracks database changes and transactions.
///
/// `TransactionObserver` is the low-level protocol that supports database observation.
///
/// A transaction observer is notified of individual changes (inserts, updates and deletes),
/// before they are committed to disk, as well as transaction commits and rollbacks.
protocol TransactionObserver: AnyObject, Sendable {
    /// Returns whether the observer should be notified of events of the given operation.
    ///
    /// This method is called before each database change to determine if the observer
    /// should be notified of that specific change.
    ///
    /// - parameter operation: The operation of database event.
    /// - returns: Whether this observer wants to be notified of this event.
    func observes(operation: DatabaseEventOperation) async -> Bool

    /// Called when the database was modified in some unspecified way.
    ///
    /// This method allows a transaction observer to handle changes that are
    /// not automatically detected. See <doc:GRDB/TransactionObserver#Dealing-with-Undetected-Changes>
    /// and ``Database/notifyChanges(in:)`` for more information.
    ///
    /// The exact nature of changes is unknown, but they comply to the
    /// ``observes(eventsOfKind:)`` test.
    func databaseDidChange() async

    /// Called when a database change occurs.
    ///
    /// This method is called for each individual database change (insert, update, delete)
    /// that the observer has registered interest in via `observes(operation:)`.
    ///
    /// - parameter event: The database event.
    func databaseDidChange(with event: SQLiteUpdateEvent) async

    /// Called before a transaction is committed.
    ///
    /// This method can throw an error to prevent the transaction from being committed.
    /// If any observer throws an error, the transaction will be rolled back.
    ///
    /// - throws: An error to prevent the transaction from committing.
    func databaseWillCommit() async throws

    /// Called after a transaction has been committed.
    ///
    /// All changes notified via `databaseDidChange(with:)` are now persisted to disk.
    func databaseDidCommit() async

    /// Called after a transaction has been rolled back.
    ///
    /// All changes notified via `databaseDidChange(with:)` since the beginning of the
    /// transaction have been discarded.
    func databaseDidRollback() async
}
