//
//  SpiralBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//

import SwiftUI

/// A spiral pattern with customizable stripes, twist, and colors
public struct SpiralBackground: View, ShaderEffect {
    public let stripesPerTurn: CGFloat
    public let twist: CGFloat
    public let centerOffsetPx: CGSize
    public let paletteCount: Int
    public let colors: [Color]
    
    public init(
        stripesPerTurn: CGFloat = 8.0,
        twist: CGFloat = 1.0,
        centerOffsetPx: CGSize = .zero,
        colors: [Color] = [.red, .orange, .yellow, .green]
    ) {
        self.stripesPerTurn = stripesPerTurn
        self.twist = twist
        self.centerOffsetPx = centerOffsetPx
        self.colors = colors
        self.paletteCount = min(colors.count, 8)

    }
    
    private func makeShader(for size: CGSize) -> Shader {
        // Ensure we have at least 1 color and pad with the last color if needed (max 8 colors)
        let paddedColors = Array(colors.prefix(8)) + Array(repeating: colors.last ?? .black, count: max(0, 8 - colors.count))
        
        return Shader(
            function: .init(library: ShadyGroundLibrary.default, name: "spiralStripes"),
            arguments: [
                .float2(Float(size.width), Float(size.height)),
                .float(stripesPerTurn),
                .float(twist),
                .float2(Float(centerOffsetPx.width), Float(centerOffsetPx.height)),
                .float(Float(paletteCount)),
                .color(paddedColors[0]),
                .color(paddedColors[1]),
                .color(paddedColors[2]),
                .color(paddedColors[3]),
                .color(paddedColors[4]),
                .color(paddedColors[5]),
                .color(paddedColors[6]),
                .color(paddedColors[7])
            ]
        )
    }
    
    public var body: some View {
        Rectangle()
            .fill(.black)
            .shadyLayerEffect { size in
                makeShader(for: size)
            }
    }
}

// MARK: - ShaderEffect Protocol Conformance
extension SpiralBackground {
    public static var effectName: String { "Spiral" }
    public static var effectDescription: String { "Logarithmic spiral pattern with customizable stripes and colors" }
    public static var effectCategory: String { "Patterns" }
}

