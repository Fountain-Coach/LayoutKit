// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LayoutKit",
    platforms: [ .macOS(.v13) ],
    products: [
        .library(name: "LayoutKit", targets: ["LayoutKit"]),
        .library(name: "LayoutKitAPI", targets: ["LayoutKitAPI"]), // OpenAPI‑generated client/server types
        .library(name: "LayoutKitNIO", targets: ["LayoutKitNIO"]), // Pure SwiftNIO server transport + default handlers
        .executable(name: "LayoutKitNIOServer", targets: ["LayoutKitNIOServer"]) // Local NIO server for manual testing
    ],
    dependencies: [
        // Apple Swift OpenAPI Generator (plugin)
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.5.0"),
        // OpenAPI runtime + URLSession transport
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
        // SwiftNIO (pure NIO server)
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.84.0")
    ],
    targets: [
        // Core engine and types
        .target(name: "LayoutKit"),
        // OpenAPI client/server generated code target
        .target(
            name: "LayoutKitAPI",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        // Pure NIO transport + default handlers delegating to LayoutEngine
        .target(
            name: "LayoutKitNIO",
            dependencies: [
                "LayoutKit",
                "LayoutKitAPI",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio")
            ]
        ),
        // SDLKit Canvas implementation (optional)
        .target(
            name: "LayoutKitSDLCanvas",
            dependencies: ["LayoutKit"],
            path: "Sources/LayoutKitSDLCanvas"
        ),
        // Small server executable for local testing
        .executableTarget(
            name: "LayoutKitNIOServer",
            dependencies: [
                "LayoutKitNIO",
                "LayoutKitAPI"
            ]
        ),
        .testTarget(name: "LayoutKitTests", dependencies: ["LayoutKit"]) 
        ,
        .testTarget(
            name: "LayoutKitAPITests",
            dependencies: ["LayoutKitAPI"],
            path: "Tests/LayoutKitAPITests"
        )
    ]
)
