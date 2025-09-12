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
enum TransactionEffect: Equatable {
    case beginTransaction
    case commitTransaction
    case rollbackTransaction
    case beginSavepoint(String)
    case releaseSavepoint(String)
    case rollbackSavepoint(String)
}
