// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DeepReader",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DeepReaderCore",
            targets: ["DeepReaderCore"]
        ),
    ],
    dependencies: [
        // GRDB - SQLite database wrapper
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0-beta.5"),
    ],
    targets: [
        .target(
            name: "DeepReaderCore",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/DeepReaderCore"
        ),
        .testTarget(
            name: "DeepReaderCoreTests",
            dependencies: ["DeepReaderCore"],
            path: "Tests/DeepReaderCoreTests"
        ),
    ]
)
