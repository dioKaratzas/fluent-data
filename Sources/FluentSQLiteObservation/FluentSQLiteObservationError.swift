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

/// Errors that can occur during SQLite database observation operations
public enum FluentSQLiteObservationError: Error, LocalizedError {
    /// The SQLite connection is closed
    case sqliteConnectionClosed
    case unsupportedDatabase

    public var errorDescription: String? {
        switch self {
        case .sqliteConnectionClosed:
            return "The SQLite connection is closed."
        case .unsupportedDatabase:
            return "Database observation is only supported with SQLite databases"
        }
    }
}
