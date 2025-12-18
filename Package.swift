// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Trainer-bot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Run", targets: ["Run"]),
        .library(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver")
            ],
            path: "Sources/App",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "App"),
                .product(name: "Vapor", package: "vapor")
            ],
            path: "Run"
        )
    ]
)
