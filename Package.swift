// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Feebi",
    products: [
        .executable(name: "Feebi", targets: ["Feebi"]),
        .library(name: "FeebiKit", targets: ["FeebiKit"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/google/auth-library-swift", from: "0.3.6"),
        .package(url: "https://github.com/ReactiveCocoa/ReactiveSwift", from: "3.1.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "7.1.1"),
        .package(url: "https://github.com/Quick/Quick.git", from: "1.3.0"),
    		.package(url: "https://github.com/SlackKit/SlackKit.git", .upToNextMinor(from: "4.1.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Feebi",
            dependencies: ["OAuth2", "FeebiKit", "SlackKit"]
        ),
        .target(
            name: "FeebiKit",
            dependencies: ["ReactiveSwift"]
        ),
        .testTarget(
            name: "FeebiKitTests",
            dependencies: ["FeebiKit"]
        )
    ]
)
