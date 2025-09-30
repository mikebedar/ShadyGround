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
    public let stripeWidth: CGFloat
    public let backgroundStripeWidth: CGFloat
    public let phase: Double
    public let angle: Double
    public let colors: [Color]

    public init(amplitude: CGFloat = 20, frequency: CGFloat = 0.1, stripeWidth: CGFloat = 25, backgroundStripeWidth: CGFloat = 25, phase: Double = 0, angle: Double = 0, colors: [Color] = [.gray.opacity(0.0), .gray.opacity(0.2)]) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.stripeWidth = stripeWidth
        self.backgroundStripeWidth = backgroundStripeWidth
        self.phase = phase
        self.angle = angle
        self.colors = colors
    }

    private var shader: Shader {
        Shader(
            function: .init(library: ShadyGroundLibrary.default, name: "wave"),
            arguments: [
                .float(amplitude),
                .float(frequency),
                .float(stripeWidth),
                .float(backgroundStripeWidth),
                .float(phase),
                .float(angle),
                .colorArray(colors.isEmpty ? [.black] : colors)
            ]
        )
    }

    public var body: some View {
        Rectangle()
            .fill(.black)
            .shadyLayerEffect(shader)
    }
}
