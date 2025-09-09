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
public protocol TransactionObserver: AnyObject, Sendable {
    /// A unique identifier for this observer instance.
    var id: ObjectIdentifier { get }

    /// Returns whether the observer should be notified of events of the given operation.
    ///
    /// This method is called before each database change to determine if the observer
    /// should be notified of that specific change.
    ///
    /// - parameter operation: The operation of database event.
    /// - returns: Whether this observer wants to be notified of this event.
    func observes(operation: DatabaseEventOperation) -> Bool

    /// Returns whether the observer should be notified of row deletions in the given table.
    ///
    /// This method helps the SQLite authorizer determine whether to prevent the
    /// truncate optimization for DELETE statements.
    ///
    /// - parameter tableName: The name of a database table.
    /// - returns: Whether this observer wants to be notified of deletions in this table.
    func observesDeletions(in tableName: String) -> Bool

    /// Called when a database change occurs.
    ///
    /// This method is called for each individual database change (insert, update, delete)
    /// that the observer has registered interest in via `observes(operation:)`.
    ///
    /// - parameter event: The database event.
    func databaseDidChange(with event: SQLiteUpdateEvent)

    /// Called before a transaction is committed.
    ///
    /// This method can throw an error to prevent the transaction from being committed.
    /// If any observer throws an error, the transaction will be rolled back.
    ///
    /// - throws: An error to prevent the transaction from committing.
    func databaseWillCommit() throws

    /// Called after a transaction has been committed.
    ///
    /// All changes notified via `databaseDidChange(with:)` are now persisted to disk.
    func databaseDidCommit()

    /// Called after a transaction has been rolled back.
    ///
    /// All changes notified via `databaseDidChange(with:)` since the beginning of the
    /// transaction have been discarded.
    func databaseDidRollback()
}
