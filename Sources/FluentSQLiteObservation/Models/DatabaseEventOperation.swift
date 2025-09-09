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

/// A type of database event operation.
///
/// See the `TransactionObserver.observes(operation:)` method for more information.
public enum DatabaseEventOperation: Sendable {
    /// The insertion of a row in a database table.
    case insert(tableName: String)

    /// The deletion of a row in a database table.
    case delete(tableName: String)

    /// The update of a set of columns in a database table.
    case update(tableName: String, columnNames: Set<String>)

    /// The name of the impacted database table.
    public var tableName: String {
        switch self {
        case let .insert(tableName: tableName): return tableName
        case let .delete(tableName: tableName): return tableName
        case let .update(tableName: tableName, columnNames: _): return tableName
        }
    }

    /// Returns whether this is a delete event.
    var isDelete: Bool {
        if case .delete = self {
            return true
        } else {
            return false
        }
    }

    var modifiedRegion: DatabaseRegion {
        switch self {
        case let .delete(tableName):
            return DatabaseRegion(table: tableName)
        case let .insert(tableName):
            return DatabaseRegion(table: tableName)
        case let .update(tableName, updatedColumnNames):
            return DatabaseRegion(table: tableName, columns: updatedColumnNames)
        }
    }
}
