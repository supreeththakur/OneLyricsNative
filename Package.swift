// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OneLyricsNative",
    platforms: [
        .macOS(.v14) // Requires macOS 14 Sonoma or later for advanced SwiftUI features
    ],
    products: [
        .executable(
            name: "OneLyricsNative",
            targets: ["OneLyricsNative"]),
    ],
    targets: [
        .executableTarget(
            name: "OneLyricsNative",
            dependencies: [],
            path: "Sources/OneLyricsNative"
        ),
    ]
)
