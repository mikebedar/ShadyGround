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
    public let paletteCount: CGFloat
    public let colors: [Color]
    
    public init(
        stripesPerTurn: CGFloat = 8.0,
        twist: CGFloat = 1.0,
        centerOffsetPx: CGSize = .zero,
        paletteCount: CGFloat = 4.0,
        colors: [Color] = [.red, .orange, .yellow, .green]
    ) {
        self.stripesPerTurn = stripesPerTurn
        self.twist = twist
        self.centerOffsetPx = centerOffsetPx
        self.paletteCount = paletteCount
        self.colors = colors
    }
    
    private func makeShader(for size: CGSize) -> Shader {
        // Ensure we have at least 4 colors and pad with the last color if needed
        let paddedColors = Array(colors.prefix(16)) + Array(repeating: colors.last ?? .black, count: max(0, 16 - colors.count))
        
        return ShadyGroundLibrary.default.spiralStripes(
            .float2(Float(size.width), Float(size.height)),
            .float(stripesPerTurn),
            .float(twist),
            .float2(Float(centerOffsetPx.width), Float(centerOffsetPx.height)),
            .float(paletteCount),
            .color(paddedColors[0]),
            .color(paddedColors[1]),
            .color(paddedColors[2]),
            .color(paddedColors[3]),
            .color(paddedColors[4]),
            .color(paddedColors[5]),
            .color(paddedColors[6]),
            .color(paddedColors[7]),
            .color(paddedColors[8]),
            .color(paddedColors[9]),
            .color(paddedColors[10]),
            .color(paddedColors[11]),
            .color(paddedColors[12]),
            .color(paddedColors[13]),
            .color(paddedColors[14]),
            .color(paddedColors[15])
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

