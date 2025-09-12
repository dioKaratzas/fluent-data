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

/// The completion of a database transaction.
enum TransactionCompletion {
    case none
    case commit
    case rollback
    case cancelledCommit(any Error)

    var isCommit: Bool {
        if case .commit = self {
            return true
        }
        return false
    }

    var isRollback: Bool {
        switch self {
        case .rollback, .cancelledCommit:
            return true
        default:
            return false
        }
    }
}
