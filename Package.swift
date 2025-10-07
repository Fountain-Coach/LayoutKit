// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LayoutKit",
    platforms: [ .macOS(.v13) ],
    products: [ .library(name: "LayoutKit", targets: ["LayoutKit"]) ],
    dependencies: [ ],
    targets: [
        .target(name: "LayoutKit"),
        .testTarget(name: "LayoutKitTests", dependencies: ["LayoutKit"]) 
    ]
)
