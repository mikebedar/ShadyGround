// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ShadyGround",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ShadyGround",
            targets: ["ShadyGround"]
        ),
    ],
    targets: [
        .target(
            name: "ShadyGround",
        resources: [
            .process("Fills/Checkerboard/CheckerboardShader.metal"),
            .process("Fills/Stripe/StripeShader.metal"),
            .process("Fills/Dots/DotsShader.metal"),
            .process("Fills/Wave/WaveShader.metal"),
            .process("Fills/Grid/GridShader.metal"),
            .process("Fills/Noise/NoiseShader.metal"),
            .process("Fills/Spiral/SpiralStripes.metal"),
            .process("Fills/Metallic/MetallicShader.metal"),
            .process("Fills/Metallic/Resources/Matcaps.xcassets"),
        ]
        ),
        .testTarget(
            name: "ShadyGroundTests",
            dependencies: ["ShadyGround"]
        ),
    ]
)
