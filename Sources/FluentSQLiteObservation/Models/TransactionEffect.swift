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

/// The effect of a SQL statement on database transactions.
public enum TransactionEffect: Sendable {
    /// A statement that does not impact transactions.
    case none

    /// A `BEGIN` or `BEGIN DEFERRED` or `BEGIN IMMEDIATE` or `BEGIN EXCLUSIVE` statement.
    case beginDeferred

    /// A `BEGIN IMMEDIATE` statement.
    case beginImmediate

    /// A `BEGIN EXCLUSIVE` statement.
    case beginExclusive

    /// A `COMMIT` statement.
    case commit

    /// A `ROLLBACK` statement.
    case rollback

    /// A `SAVEPOINT` statement.
    case savepoint(String)

    /// A `RELEASE SAVEPOINT` statement.
    case releaseSavepoint(String)

    /// A `ROLLBACK TO SAVEPOINT` statement.
    case rollbackToSavepoint(String)
}
