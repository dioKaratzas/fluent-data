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
import Foundation

// MARK: - Database Keys

extension DatabaseID {
    static let users = DatabaseID(string: "users")
    static let products = DatabaseID(string: "products")
}
