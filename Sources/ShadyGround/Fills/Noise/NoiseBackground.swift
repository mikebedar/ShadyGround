//
//  NoiseBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct NoiseBackground: View {
    public let scale: CGFloat
    public let intensity: CGFloat
    public let octaves: CGFloat
    public let persistence: CGFloat
    public let seed: Double
    public let angle: Double
    public let backgroundColor: Color
    public let foregroundColor: Color

    public init(scale: CGFloat = 1.0, intensity: CGFloat = 1.0, octaves: CGFloat = 4, persistence: CGFloat = 0.5, seed: Double = 0, angle: Double = 0, backgroundColor: Color = Color.gray.opacity(0.0), foregroundColor: Color = Color.gray.opacity(0.8)) {
        self.scale = scale
        self.intensity = intensity
        self.octaves = octaves
        self.persistence = persistence
        self.seed = seed
        self.angle = angle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    private var shader: Shader {
        ShadyGroundLibrary.default.noise(
            .float(scale),
            .float(intensity),
            .float(octaves),
            .float(persistence),
            .float(seed),
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


