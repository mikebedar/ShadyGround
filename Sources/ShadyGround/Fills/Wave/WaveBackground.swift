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
    public let backgroundColor: Color
    public let foregroundColor: Color

    public init(amplitude: CGFloat = 20, frequency: CGFloat = 0.1, foregroundStripeWidth: CGFloat = 25, backgroundStripeWidth: CGFloat = 25, phase: Double = 0, angle: Double = 0, backgroundColor: Color = Color.gray.opacity(0.0), foregroundColor: Color = Color.gray.opacity(0.2)) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.foregroundStripeWidth = foregroundStripeWidth
        self.backgroundStripeWidth = backgroundStripeWidth
        self.phase = phase
        self.angle = angle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    private var shader: Shader {
        ShadyGroundLibrary.default.wave(
            .float(amplitude),
            .float(frequency),
            .float(foregroundStripeWidth),
            .float(backgroundStripeWidth),
            .float(phase),
            .float(angle),
            .color(backgroundColor),
            .color(foregroundColor)
        )
    }

    public var body: some View {
        Rectangle()
            .fill(.black)
            .shadyLayerEffect(shader)
    }
}
