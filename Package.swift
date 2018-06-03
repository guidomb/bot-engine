// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BotEngine",
    products: [
        .executable(name: "BotEngine", targets: ["BotEngine"]),
        .library(name: "BotEngineKit", targets: ["BotEngineKit"]),
        .library(name: "WoloxKit", targets: ["WoloxKit"]),
        .library(name: "GoogleAPI", targets: ["GoogleAPI"]),
        .library(name: "TestKit", targets: ["TestKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/google/auth-library-swift", from: "0.3.6"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "3.1.0"),
    		.package(url: "https://github.com/guidomb/SlackKit.git", .branch("linux")),
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.8.1")
    ],
    targets: [
        .target(
            name: "BotEngine",
            dependencies: [
              "BotEngineKit"
            ]
        ),
        .target(
            name: "BotEngineKit",
            dependencies: [
              "GoogleAPI",
              "ReactiveSwift",
              "OAuth2",
              "SlackKit"
            ]
        ),
        .target(
            name: "WoloxKit",
            dependencies: [
              "GoogleAPI",
              "ReactiveSwift"
            ]
        ),
        .target(
            name: "GoogleAPI",
            dependencies: [
              "ReactiveSwift"
            ]
        ),
        .target(
            name: "TestKit",
            dependencies: [
              "GoogleAPI"
            ]
        ),

        .testTarget(
            name: "BotEngineKitTests",
            dependencies: [
              "BotEngineKit",
              "TestKit",
              "SwiftCheck"
            ]
        ),
        .testTarget(
            name: "WoloxKitTests",
            dependencies: [
              "WoloxKit",
              "TestKit"
            ]
        ),
        .testTarget(
            name: "GoogleAPITests",
            dependencies: [
              "GoogleAPI",
              "TestKit"
            ]
        )
    ]
)
