// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BotEngine",
    products: [
        .executable(name: "BotEngine", targets: ["BotEngine"]),
        .library(name: "BotEngineKit", targets: ["BotEngineKit"]),
        .library(name: "GoogleAPI", targets: ["GoogleAPI"]),
        .library(name: "GoogleOAuth", targets: ["GoogleOAuth"]),
        .library(name: "TestKit", targets: ["TestKit"]),
        .library(name: "WoloxKit", targets: ["WoloxKit"])
    ],
    dependencies: [
        // Dependencies
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "3.1.0"),
        .package(url: "https://github.com/vapor/http.git", from: "3.0.0"),
        .package(url: "https://github.com/SlackKit/SKCore", .upToNextMinor(from: "4.1.0")),
        .package(url: "https://github.com/SlackKit/SKClient", .upToNextMinor(from: "4.1.0")),
        .package(url: "https://github.com/SlackKit/SKRTMAPI", .upToNextMinor(from: "4.1.0")),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.8.0"),
        .package(url: "https://github.com/attaswift/BigInt", from: "3.0.0"),
        .package(url: "https://github.com/timburks/SwiftyBase64", from: "1.2.0"),

        // Test dependencies
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
              "GoogleOAuth",
              "SKCore",
              "SKClient",
              "SKRTMAPI",
              "HTTP"
            ]
        ),
        .target(
          name: "GoogleAPI",
          dependencies: [
            "ReactiveSwift"
          ]
        ),
        .target(
          name: "GoogleOAuth",
          dependencies: [
            "CryptoSwift",
            "BigInt",
            "SwiftyBase64"
          ]
        ),
        .target(
          name: "TestKit",
          dependencies: [
            "GoogleAPI"
          ]
        ),
        .target(
            name: "WoloxKit",
            dependencies: [
              "GoogleAPI",
              "ReactiveSwift"
            ]
        ),

        // Test targets
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
