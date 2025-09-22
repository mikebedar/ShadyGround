// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ShadyGround",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ShadyGround",
            targets: ["ShadyGround"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ShadyGround",
        resources: [
            .process("Fills/Checkerboard/CheckerboardShader.metal"),
            .process("Fills/Stripe/StripeShader.metal"),
            .process("Fills/Dots/DotsShader.metal"),
            .process("Fills/Wave/WaveShader.metal"),
            .process("Fills/Grid/GridShader.metal"),
            .process("Fills/Noise/NoiseShader.metal"),
        ]
        ),
        .testTarget(
            name: "ShadyGroundTests",
            dependencies: ["ShadyGround"]
        ),
    ]
)
