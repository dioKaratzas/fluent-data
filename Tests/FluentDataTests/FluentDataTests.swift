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

import Testing
import SQLiteKit
import FluentKit
@testable import FluentData
import FluentSQLiteDriver

// MARK: - Configuration Tests

@Suite("FluentData Configuration")
struct ConfigurationTests {
    @Test("FluentData initialization")
    func initialization() async throws {
        try await TestDatabaseFactory.withTestDatabase(.empty) { provider in
            #expect(provider.defaultDatabaseID == .test)
            #expect(provider.historyEnabled == false)
            #expect(provider.pageSizeLimit == .noLimit)
        }
    }

    @Test("Multiple database configuration")
    func multipleDatabaseConfiguration() async throws {
        try await TestDatabaseFactory.withTestDatabase(.multiple) { provider in
            #expect(provider.defaultDatabaseID == .primary)

            // Verify both databases exist
            let primaryDB = provider.db(.primary)
            let secondaryDB = provider.db(.secondary)

            // Both databases should be accessible
            #expect(primaryDB is SQLiteDatabase)
            #expect(secondaryDB is SQLiteDatabase)
        }
    }

    @Test("Multiple default databases should throw error")
    func multipleDefaultDatabasesError() async throws {
        let provider = FluentData()

        do {
            // Configure first default database
            try await provider.configureSQLite(configuration: .init(
                id: .primary,
                sqliteConfiguration: .init(storage: .memory),
                isDefault: true
            ))

            // Attempt to configure second default database should throw
            await #expect(throws: FluentDataError.self) {
                try await provider.configureSQLite(configuration: .init(
                    id: .secondary,
                    sqliteConfiguration: .init(storage: .memory),
                    isDefault: true
                ))
            }
        } catch {
            await provider.shutdown()
            throw error
        }

        await provider.shutdown()
    }
}

// MARK: - Database Operations Tests

@Suite("Database Operations")
struct DatabaseOperationsTests {
    @Test("Basic CRUD operations")
    func basicCRUDOperations() async throws {
        try await TestDatabaseFactory.withTestDatabase(.empty) { provider in
            // Add migration and run it
            provider.migrations.add(CreateTestUser())
            try await provider.autoMigrate()

            // Create user
            let user = TestUser(name: "Test User", email: "test@example.com")
            try await user.create(on: provider.db)

            // Verify user exists
            let fetchedUser = try await TestUser.find(user.id, on: provider.db)
            #expect(fetchedUser?.name == "Test User")
            #expect(fetchedUser?.email == "test@example.com")

            // Count users
            let userCount = try await TestUser.query(on: provider.db).count()
            #expect(userCount == 1)
        }
    }

    @Test("Database isolation")
    func databaseIsolation() async throws {
        try await TestDatabaseFactory.withTestDatabase(.multiple) { provider in
            // Setup migrations on both databases
            let userMigration = CreateTestUser()
            let productMigration = CreateTestProduct()

            try await userMigration.prepare(on: provider.db(.primary))
            try await productMigration.prepare(on: provider.db(.secondary))

            // Create user in primary database
            let user = TestUser(name: "Primary User", email: "primary@test.com")
            try await user.create(on: provider.db(.primary))

            // Create product in secondary database
            let product = TestProduct(name: "Secondary Product", price: 99.99)
            try await product.create(on: provider.db(.secondary))

            // Verify isolation - user only in primary
            let primaryUserCount = try await TestUser.query(on: provider.db(.primary)).count()
            #expect(primaryUserCount == 1)

            // Verify isolation - product only in secondary
            let secondaryProductCount = try await TestProduct.query(on: provider.db(.secondary)).count()
            #expect(secondaryProductCount == 1)
        }
    }
}

// MARK: - Feature Tests

@Suite("FluentData Features")
struct FeatureTests {
    @Test("Query history functionality")
    func queryHistoryFunctionality() async throws {
        try await TestDatabaseFactory.withTestDatabase(.empty) { provider in
            // Test history enabled flag
            provider.historyEnabled = false
            #expect(provider.historyEnabled == false)

            provider.historyEnabled = true
            #expect(provider.historyEnabled == true)

            // Test history cleared
            provider.clearHistory()
            #expect(provider.history.isEmpty)

            // Disable history
            provider.historyEnabled = false
            #expect(provider.historyEnabled == false)
        }
    }

    @Test("Page size limit functionality")
    func pageSizeLimitFunctionality() async throws {
        try await TestDatabaseFactory.withTestDatabase(.empty) { provider in
            // Test default no limit
            #expect(provider.pageSizeLimit == .noLimit)

            // Set specific limit
            provider.pageSizeLimit = FluentData.PageLimit(100)
            #expect(provider.pageSizeLimit.value == 100)

            // Set using integer literal
            provider.pageSizeLimit = 50
            #expect(provider.pageSizeLimit.value == 50)

            // Set back to no limit
            provider.pageSizeLimit = .noLimit
            #expect(provider.pageSizeLimit.value == nil)
        }
    }
}

// MARK: - Error Handling Tests

@Suite("Error Handling")
struct ErrorHandlingTests {
    @Test("FluentDataError descriptions")
    func fluentDataErrorDescriptions() {
        let errors: [FluentDataError] = [
            .databaseNotConfigured,
            .multipleDefaultDatabases(existing: "db1", new: "db2"),
            .notSQLiteDatabase,
            .invalidPassphrase,
            .encryptionOperationFailed("test error")
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }

        // Test specific error message
        let multipleDbError = FluentDataError.multipleDefaultDatabases(existing: "users", new: "products")
        #expect(multipleDbError.errorDescription?.contains("users") == true)
        #expect(multipleDbError.errorDescription?.contains("products") == true)
    }
}

#if SQLCipher

    // MARK: - Encryption Tests

    @Suite("SQLCipher Encryption")
    struct EncryptionTests {
        @Test("Encrypted database configuration")
        func encryptedDatabaseConfiguration() async throws {
            try await TestDatabaseFactory.withTestDatabase(.encrypted()) { provider in
                #expect(provider.defaultDatabaseID == .encrypted)

                // Should be able to perform operations on encrypted database
                provider.migrations.add(CreateTestUser())
                try await provider.autoMigrate()

                try await TestUtilities.seedUsers(on: provider.db, count: 1)

                let userCount = try await TestUser.query(on: provider.db).count()
                #expect(userCount == 1)
            }
        }
    }
#endif
