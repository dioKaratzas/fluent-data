//
//  Copyright © Dionysis Karatzas. All rights reserved.
//

import Foundation
import FluentData

// MARK: - Main CLI

@main
struct CLI {
    static func main() async throws {
        print("🚀 FluentClient - 2 Databases Example")
        print("=====================================\n")

        let db = try await DatabaseManager()

        do {
            // Setup all databases with migrations
            print("🔧 Setting up databases...")
            try await db.setupAllDatabases()
            print("✅ Databases configured and migrated\n")

            // Show default database info
            print("📊 Database Configuration")
            print("------------------------")
            print(db.currentDefaultDatabase)
            print()

            // Database 1: Users (Default Database)
            print("📝 Database 1: Users (Default Database)")
            print("--------------------------------------")

            let user1 = try await db.createUser(name: "John Doe", email: "john@example.com")
            let user2 = try await db.createUser(name: "Jane Smith", email: "jane@example.com")

            print("✅ Created users: \(user1.name), \(user2.name)")

            let users = try await db.getAllUsers()
            print("✅ Total users: \(users.count)")
            for user in users {
                print("   - \(user.name) (\(user.email))")
            }

            // Demonstrate default database usage
            print("\n🔄 Using Default Database Operations:")
            let user3 = try await db.createUserOnDefaultDB(name: "Bob Wilson", email: "bob@example.com")
            print("✅ Created user on default DB: \(user3.name)")

            let defaultUsers = try await db.getAllUsersFromDefaultDB()
            print("✅ Users from default DB: \(defaultUsers.count)")

            print()

            // Database 2: Products
            print("🛍️  Database 2: Products")
            print("------------------------")

            let product1 = try await db.createProduct(name: "iPhone", price: 999.99)
            let product2 = try await db.createProduct(name: "MacBook", price: 1299.99)
            let product3 = try await db.createProduct(name: "iPad", price: 799.99)

            print("✅ Created products: \(product1.name), \(product2.name), \(product3.name)")

            let products = try await db.getAllProducts()
            print("✅ Total products: \(products.count)")
            for product in products {
                print("   - \(product.name): $\(product.price)")
            }

            // Demonstrate switching default database
            print("\n🔄 Switching Default Database:")
            print("Before: \(db.currentDefaultDatabase)")
            db.switchDefaultToProducts()
            print("After: \(db.currentDefaultDatabase)")

            // Now create a product using the default database (which is now products)
            let product4 = try await db.createProduct(name: "Apple Watch", price: 399.99)
            print("✅ Created product on new default DB: \(product4.name)")

            print("\n✅ Example completed successfully!")

        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }

        // Cleanup
        await db.shutdown()
        db.cleanupDatabases()
    }
}
