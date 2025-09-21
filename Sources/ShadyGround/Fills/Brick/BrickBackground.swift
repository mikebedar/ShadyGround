//
//  BrickBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

/// A brick pattern with customizable brick dimensions, mortar width, and rotation
public struct BrickBackground: View {
    public let brickWidth: CGFloat
    public let brickHeight: CGFloat
    public let mortarWidth: CGFloat
    public let angle: Double
    public let backgroundColor: Color
    public let foregroundColor: Color

    public init(brickWidth: CGFloat = 80, brickHeight: CGFloat = 40, mortarWidth: CGFloat = 4, angle: Double = 0, backgroundColor: Color = Color.gray.opacity(0.0), foregroundColor: Color = Color.gray.opacity(0.2)) {
        self.brickWidth = brickWidth
        self.brickHeight = brickHeight
        self.mortarWidth = mortarWidth
        self.angle = angle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    private var shader: Shader {
        ShadyGroundLibrary.default.brick(
            .float(brickWidth),
            .float(brickHeight),
            .float(mortarWidth),
            .float(angle),
            .color(backgroundColor),
            .color(foregroundColor)
        )
    }

    public var body: some View {
        Rectangle()
            .fill(.black)
            .layerEffect(shader, maxSampleOffset: .zero)
    }
}


