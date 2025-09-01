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
    ],
    dependencies: [
        .package(url: "https://github.com/dioKaratzas/fluent-sqlite-driver.git", branch: "feature/sqlite-cipher"),
    ],
    targets: [
        .target(
            name: "FluentData",
            dependencies: [
                .product(name: "FluentSQLiteDriver", package: "fluent-sqlite-driver"),
            ]
        ),
        .testTarget(
            name: "FluentDataTests",
            dependencies: ["FluentData"]
        ),
        .executableTarget(
            name: "FluentDataExamples",
            dependencies: ["FluentData"]
        ),
    ]
)
