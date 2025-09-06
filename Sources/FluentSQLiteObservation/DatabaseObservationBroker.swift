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

//
//  DatabaseObservationBroker.swift
//  fluent-data
//
//  Created by Dionisis Karatzas on 5/9/25.
//
import SQLiteNIO
import Foundation

/// Registry to manage observation brokers per connection
final class ConnectionObservationRegistry: Sendable {
    static let shared = ConnectionObservationRegistry()

    @discardableResult
    func createBrokerIfNeeded(for connection: SQLiteConnection) -> DatabaseObservationBroker {
        fatalError("Not implemented")
    }
}

final class DatabaseObservationBroker: Sendable {}
