// swift-tools-version: 5.9

import PackageDescription

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
    dependencies: [
        .package(url: "https://github.com/dioKaratzas/fluent-sqlite-driver.git", branch: "feature/sql-cipher"),
    ],
    targets: [
        .target(
            name: "FluentData",
            dependencies: [
                "FluentSQLiteObservation",
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
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
