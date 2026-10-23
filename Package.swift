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
        exclude: ["Fills/Grass/GrassCore.h"],
        resources: [
            .process("Fills/Checkerboard/CheckerboardShader.metal"),
            .process("Fills/Stripe/StripeShader.metal"),
            .process("Fills/Dots/DotsShader.metal"),
            .process("Fills/Wave/WaveShader.metal"),
            .process("Fills/Grid/GridShader.metal"),
            .process("Fills/Noise/NoiseShader.metal"),
            .process("Fills/Spiral/SpiralStripes.metal"),
            .process("Fills/Metallic/MetallicMatcap.metal"),
            .process("Fills/Metallic/Resources/Matcaps.xcassets"),
            .process("Fills/Grass/GrassShader.metal"),
            .process("Fills/Grass/Instanced/GrassInstanced.metal"),
        ]
        ),
        .testTarget(
            name: "ShadyGroundTests",
            dependencies: ["ShadyGround"]
        ),
    ]
)
