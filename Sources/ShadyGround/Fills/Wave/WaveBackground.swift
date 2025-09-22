//
//  WaveBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct WaveBackground: View {
    public let amplitude: CGFloat
    public let frequency: CGFloat
    public let foregroundStripeWidth: CGFloat
    public let backgroundStripeWidth: CGFloat
    public let phase: Double
    public let angle: Double
    public let colors: [Color]

    public init(amplitude: CGFloat = 20, frequency: CGFloat = 0.1, foregroundStripeWidth: CGFloat = 25, backgroundStripeWidth: CGFloat = 25, phase: Double = 0, angle: Double = 0, colors: [Color] = [.gray.opacity(0.0), .gray.opacity(0.2)]) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.foregroundStripeWidth = foregroundStripeWidth
        self.backgroundStripeWidth = backgroundStripeWidth
        self.phase = phase
        self.angle = angle
        self.colors = colors
    }

    private var shader: Shader {
        // Ensure we have at least 1 color and pad with the last color if needed (max 8 colors)
        let paddedColors = Array(colors.prefix(8)) + Array(repeating: colors.last ?? .black, count: max(0, 8 - colors.count))
        
        return Shader(
            function: .init(library: ShadyGroundLibrary.default, name: "wave"),
            arguments: [
                .float(amplitude),
                .float(frequency),
                .float(foregroundStripeWidth),
                .float(backgroundStripeWidth),
                .float(phase),
                .float(angle),
                .float(Float(min(colors.count, 8))),
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
            .shadyLayerEffect(shader)
    }
}
