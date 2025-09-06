// swift-tools-version: 6.2

import PackageDescription

enum Traits {
    static let SQLite = "SQLite"
    static let SQLCipher = "SQLCipher"
}

let package = Package(
    name: "fluent-data",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
    ],
    products: [
        .library(
            name: "FluentData",
            targets: ["FluentData"]
        ),
        .library(
            name: "FluentSQLiteObservation",
            targets: ["FluentSQLiteObservation"]
        ),
    ],
    traits: [
        .trait(name: Traits.SQLite, description: "Enable SQLite without encryption"),
        .trait(name: Traits.SQLCipher, description: "Enable SQLCipher encryption support for encrypted databases"),
        .default(enabledTraits: [Traits.SQLCipher])
    ],
    dependencies: [
        .package(url: "https://github.com/dioKaratzas/fluent-sqlite-driver.git", branch: "feature/sql-cipher",  traits: [
            .trait(name: Traits.SQLite, condition: .when(traits: [Traits.SQLite])),
            .trait(name: Traits.SQLCipher, condition: .when(traits: [Traits.SQLCipher]))
        ]),
    ],
    targets: [
        .target(
            name: "FluentData",
            dependencies: [
                "FluentSQLiteObservation",
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ],
            swiftSettings: [
                .define(Traits.SQLCipher, .when(traits: [Traits.SQLCipher]))
            ]
        ),
        .target(
            name: "FluentSQLiteObservation",
            dependencies: [
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ]
        ),
        .testTarget(
            name: "FluentDataTests",
            dependencies: ["FluentData"]
        ),
    ]
)
