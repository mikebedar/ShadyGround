//
//  AnimatedSpiralBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//

import SwiftUI

/// An animated spiral pattern where the twist value changes over time
public struct AnimatedSpiralBackground: View {
    public let stripesPerTurn: CGFloat
    public let baseTwist: CGFloat
    public let twistAmplitude: CGFloat
    public let animationSpeed: Double
    public let centerOffsetPx: CGSize
    public let paletteCount: CGFloat
    public let colors: [Color]
    
    public init(
        stripesPerTurn: CGFloat = 8.0,
        baseTwist: CGFloat = 1.0,
        twistAmplitude: CGFloat = 2000.0,
        animationSpeed: Double = 0.25,
        centerOffsetPx: CGSize = .zero,
        paletteCount: CGFloat = 4.0,
        colors: [Color] = [.red, .orange, .yellow, .green]
    ) {
        self.stripesPerTurn = stripesPerTurn
        self.baseTwist = baseTwist
        self.twistAmplitude = twistAmplitude
        self.animationSpeed = animationSpeed
        self.centerOffsetPx = centerOffsetPx
        self.paletteCount = paletteCount
        self.colors = colors
    }
    
    public var body: some View {
        Rectangle()
            .fill(.black)
            .shadyLayerEffect(
                needsSize: true,
                timeSource: .animation
            ) { context in
                makeAnimatedShader(for: context.size, time: context.time)
            }
    }
    
    private func makeAnimatedShader(for size: CGSize, time: Double) -> Shader {
        // Calculate animated twist value using sine wave
        let animatedTwist = baseTwist + twistAmplitude * sin(time * animationSpeed)
        
        // Ensure we have at least 4 colors and pad with the last color if needed
        let paddedColors = Array(colors.prefix(16)) + Array(repeating: colors.last ?? .black, count: max(0, 16 - colors.count))
        
        return ShadyGroundLibrary.default.spiralStripes(
            .float2(Float(size.width), Float(size.height)),
            .float(stripesPerTurn),
            .float(animatedTwist),
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
}

// MARK: - Preview
#if DEBUG
#Preview("Animated Spiral") {
    AnimatedSpiralBackground(
        stripesPerTurn: 6.0,
        baseTwist: 1.0,
        twistAmplitude: 10.0,
        animationSpeed: 0.25,
        colors: [.purple, .blue, .cyan, .green, .yellow, .orange]
    )
    .frame(width: 300, height: 300)
}
#endif
