// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LayoutKit",
    platforms: [ .macOS(.v13) ],
    products: [
        .library(name: "LayoutKit", targets: ["LayoutKit"]),
        .library(name: "LayoutKitAPI", targets: ["LayoutKitAPI"]) // OpenAPI‑generated client/server types
    ],
    dependencies: [
        // Apple Swift OpenAPI Generator (plugin)
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.8.0"),
        // OpenAPI runtime + URLSession transport
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.7.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0")
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
        .testTarget(name: "LayoutKitTests", dependencies: ["LayoutKit"]) 
    ]
)
