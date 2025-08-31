//
//  Copyright © Dionysis Karatzas. All rights reserved.
//

import FluentKit
import Foundation

// MARK: - User Model

final class User: Model, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id) var id: UUID?

    @Field(key: "name") var name: String

    @Field(key: "email") var email: String

    init() {}

    init(name: String, email: String) {
        self.name = name
        self.email = email
    }
}

// MARK: - Product Model

final class Product: Model, @unchecked Sendable {
    static let schema = "products"

    @ID(key: .id) var id: UUID?

    @Field(key: "name") var name: String

    @Field(key: "price") var price: Double

    init() {}

    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }
}
