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
    public let colors: [Color]
    
    public init(
        stripesPerTurn: CGFloat = 8.0,
        baseTwist: CGFloat = 1.0,
        twistAmplitude: CGFloat = 2000.0,
        animationSpeed: Double = 0.25,
        centerOffsetPx: CGSize = .zero,
        colors: [Color] = [.red, .orange, .yellow, .green]
    ) {
        self.stripesPerTurn = stripesPerTurn
        self.baseTwist = baseTwist
        self.twistAmplitude = twistAmplitude
        self.animationSpeed = animationSpeed
        self.centerOffsetPx = centerOffsetPx
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
        
        let palette = colors.isEmpty ? [.black] : colors
        
        return Shader(
            function: .init(library: ShadyGroundLibrary.default, name: "spiralStripes"),
            arguments: [
                .float2(Float(size.width), Float(size.height)),
                .float(stripesPerTurn),
                .float(animatedTwist),
                .float2(Float(centerOffsetPx.width), Float(centerOffsetPx.height)),
                .float(0.0), // antialiasingLevel (disabled for animation performance)
                .colorArray(palette)
            ]
        )
    }
}

// MARK: - Preview
#if DEBUG
#Preview("Animated Spiral") {
    AnimatedSpiralBackground(
        stripesPerTurn: 1.0,
        baseTwist: 0.1,
        twistAmplitude: 0.1,
        animationSpeed: 0.0005,
        colors: [.red, .orange, .yellow, .green, .blue, .cyan, .purple]
    )
    .frame(width: 300, height: 300)
}
#endif
