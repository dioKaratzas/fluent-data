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

import Logging
import SQLiteKit
import FluentKit
import Foundation
@testable import FluentData

// MARK: - Test Database Types

enum TestDatabaseType {
    case empty
    case multiple
    #if SQLCipher
        case encrypted(password: String = "testpass123")
    #endif
}

// MARK: - Test Database Factory with Cleanup

struct TestDatabaseFactory {
    private static let logger = Logger(label: "test")

    /// Execute test code with automatic database cleanup
    static func withTestDatabase<T>(
        _ type: TestDatabaseType,
        operation: (FluentData) async throws -> T
    ) async throws -> T {
        let provider = try await createDatabase(type: type)

        do {
            let result = try await operation(provider)
            await cleanup(provider)
            return result
        } catch {
            await cleanup(provider)
            throw error
        }
    }

    // MARK: - Private Factory Methods

    private static func createDatabase(type: TestDatabaseType) async throws -> FluentData {
        switch type {
        case .empty:
            return try await createEmptyDatabase()
        case .multiple:
            return try await createMultipleDatabases()
        #if SQLCipher
            case let .encrypted(password):
                return try await createEncryptedDatabase(password: password)
        #endif
        }
    }

    private static func createEmptyDatabase() async throws -> FluentData {
        let provider = FluentData(logger: logger)

        try await provider.configureSQLite(configuration: .init(
            id: .test,
            sqliteConfiguration: .init(storage: .memory),
            isDefault: true
        ))

        return provider
    }

    private static func createMultipleDatabases() async throws -> FluentData {
        let provider = FluentData(logger: logger)

        // Database 1: Primary (default)
        try await provider.configureSQLite(configuration: .init(
            id: .primary,
            sqliteConfiguration: .init(storage: .memory),
            isDefault: true
        ))

        // Database 2: Secondary
        try await provider.configureSQLite(configuration: .init(
            id: .secondary,
            sqliteConfiguration: .init(storage: .memory)
        ))

        return provider
    }

    #if SQLCipher
        private static func createEncryptedDatabase(password: String) async throws -> FluentData {
            let provider = FluentData(logger: logger)

            try await provider.configureSQLite(configuration: .init(
                id: .encrypted,
                sqliteConfiguration: .init(storage: .memory),
                password: password,
                isDefault: true
            ))

            return provider
        }
    #endif

    private static func cleanup(_ provider: FluentData) async {
        await provider.shutdown()
    }
}

// MARK: - Test Database IDs

extension DatabaseID {
    static let test = DatabaseID(string: "test")
    static let primary = DatabaseID(string: "primary")
    static let secondary = DatabaseID(string: "secondary")
    static let encrypted = DatabaseID(string: "encrypted")
}

// MARK: - Test Models

final class TestUser: Model, @unchecked Sendable {
    static let schema = "test_users"

    @ID(key: .id) var id: UUID?
    @Field(key: "name") var name: String
    @Field(key: "email") var email: String

    init() {}

    init(name: String, email: String) {
        self.name = name
        self.email = email
    }
}

final class TestProduct: Model, @unchecked Sendable {
    static let schema = "test_products"

    @ID(key: .id) var id: UUID?
    @Field(key: "name") var name: String
    @Field(key: "price") var price: Double

    init() {}

    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }
}

// MARK: - Test Migrations

struct CreateTestUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TestUser.schema)
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(TestUser.schema).delete()
    }
}

struct CreateTestProduct: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(TestProduct.schema)
            .id()
            .field("name", .string, .required)
            .field("price", .double, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(TestProduct.schema).delete()
    }
}

// MARK: - Test Utilities

struct TestUtilities {
    /// Create sample users in database
    static func seedUsers(on database: any Database, count: Int = 3) async throws {
        let users = [
            TestUser(name: "John Doe", email: "john@test.com"),
            TestUser(name: "Jane Smith", email: "jane@test.com"),
            TestUser(name: "Bob Wilson", email: "bob@test.com")
        ]

        for i in 0 ..< min(count, users.count) {
            try await users[i].create(on: database)
        }
    }

    /// Create sample products in database
    static func seedProducts(on database: any Database, count: Int = 3) async throws {
        let products = [
            TestProduct(name: "iPhone", price: 999.99),
            TestProduct(name: "MacBook", price: 1999.99),
            TestProduct(name: "iPad", price: 799.99)
        ]

        for i in 0 ..< min(count, products.count) {
            try await products[i].create(on: database)
        }
    }
}
