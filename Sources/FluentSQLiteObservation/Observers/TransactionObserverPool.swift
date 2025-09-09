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

final actor TransactionObserverPool: Sendable {
    /// Registered transaction observers
    private var observers: [any TransactionObserver] = []

    func setObservers(_ newObservers: [any TransactionObserver]) async throws {
        observers = newObservers
        if observers.isEmpty {
            removeHooks()
        } else {
            try await installHooks()
        }
    }
}
