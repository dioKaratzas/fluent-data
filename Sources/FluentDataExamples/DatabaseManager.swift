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
import FluentKit
import Foundation
import FluentData
import FluentSQLiteDriver

// MARK: - Database Manager

final class DatabaseManager {
    let provider: FluentData
    let usersDBURL: URL
    let productsDBURL: URL

    init() async throws {
        let tempDir = FileManager.default.temporaryDirectory
        self.usersDBURL = tempDir.appendingPathComponent("users.db")
        self.productsDBURL = tempDir.appendingPathComponent("products.db")
        self.provider = FluentData(logger: Logger(label: "example"))

        // Clean up any existing databases at startup
        cleanupDatabases()

        try await setupDatabase()
    }

    private func setupDatabase() async throws {
        // Setup Users Database (set as default)
        try await provider.configureSQLite(configuration: .init(id: .users, url: usersDBURL, isDefault: true))

        // Setup Products Database
        try await provider.configureSQLite(configuration: .init(id: .products, url: productsDBURL))
    }

    // MARK: - Migration Methods

    func setupUsersDatabase() async throws {
        // Get the users database (now the default)
        let usersDB = provider.db(.users)

        // Run user migration manually on the users database
        let migration = CreateUser()
        try await migration.prepare(on: usersDB)
    }

    func setupProductsDatabase() async throws {
        // Get the products database
        let productsDB = provider.db(.products)

        // Run product migration manually on the products database
        let migration = CreateProduct()
        try await migration.prepare(on: productsDB)
    }

    // MARK: - Default Database Operations

    /// Use the default database (users database in this example)
    func createUserOnDefaultDB(name: String, email: String) async throws -> User {
        let user = User(name: name, email: email)
        // This will use the default database (users)
        try await user.create(on: provider.db)
        return user
    }

    func getAllUsersFromDefaultDB() async throws -> [User] {
        // This will use the default database (users)
        try await User.query(on: provider.db).all()
    }

    /// Change the default database at runtime
    func switchDefaultToProducts() {
        provider.defaultDatabaseID = .products
    }

    /// Get current default database info
    var currentDefaultDatabase: String {
        if let defaultID = provider.defaultDatabaseID {
            return "Default database: \(defaultID.string)"
        } else {
            return "No default database set"
        }
    }

    // MARK: - User Operations (Database 1)

    func createUser(name: String, email: String) async throws -> User {
        let user = User(name: name, email: email)
        try await user.create(on: provider.db(.users))
        return user
    }

    func getAllUsers() async throws -> [User] {
        try await User.query(on: provider.db(.users)).all()
    }

    // MARK: - Product Operations (Database 2)

    func createProduct(name: String, price: Double) async throws -> Product {
        let product = Product(name: name, price: price)
        try await product.create(on: provider.db(.products))
        return product
    }

    func getAllProducts() async throws -> [Product] {
        try await Product.query(on: provider.db(.products)).all()
    }

    // MARK: - Cleanup

    func shutdown() async {
        await provider.shutdown()
    }

    func cleanupDatabases() {
        try? FileManager.default.removeItem(at: usersDBURL)
        try? FileManager.default.removeItem(at: productsDBURL)
    }

    // MARK: - Convenience Methods

    /// Setup all databases with migrations
    func setupAllDatabases() async throws {
        try await setupUsersDatabase()
        try await setupProductsDatabase()
    }

    /// Get database URLs for external access
    var databaseURLs: (users: URL, products: URL) {
        (users: usersDBURL, products: productsDBURL)
    }
}
