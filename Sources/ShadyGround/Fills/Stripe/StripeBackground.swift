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
        Shader(
            function: .init(library: ShadyGroundLibrary.default, name: "stripe"),
            arguments: [
                .float(stripeWidth),
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
