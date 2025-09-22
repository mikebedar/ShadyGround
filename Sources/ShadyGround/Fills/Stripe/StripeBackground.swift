//
//  StripeBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct StripeBackground: View {
    public let stripeWidth: CGFloat
    public let angle: Double
    public let colors: [Color]

    public init(stripeWidth: CGFloat = 20, angle: Double = 0, colors: [Color] = [.gray.opacity(0.0), .gray.opacity(0.2)]) {
        self.stripeWidth = stripeWidth
        self.angle = angle
        self.colors = colors
    }

    private var shader: Shader {
        // Ensure we have at least 1 color and pad with the last color if needed (max 8 colors)
        let paddedColors = Array(colors.prefix(8)) + Array(repeating: colors.last ?? .black, count: max(0, 8 - colors.count))
        
        return Shader(
            function: .init(library: ShadyGroundLibrary.default, name: "stripe"),
            arguments: [
                .float(stripeWidth),
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
