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
    public let colors: [Color]
    public let antialiasingLevel: CGFloat
    
    public init(
        stripesPerTurn: CGFloat = 8.0,
        twist: CGFloat = 1.0,
        centerOffsetPx: CGSize = .zero,
        colors: [Color] = [.red, .orange, .yellow, .green],
        antialiasingLevel: CGFloat = 0.0
    ) {
        self.stripesPerTurn = stripesPerTurn
        self.twist = twist
        self.centerOffsetPx = centerOffsetPx
        self.colors = colors
        self.antialiasingLevel = antialiasingLevel
    }
    
    private func makeShader(for size: CGSize) -> Shader {
        let palette = colors.isEmpty ? [.black] : colors
        
        // Break up the arguments into smaller chunks for better compiler performance
        let basicArgs: [Shader.Argument] = [
            .float2(Float(size.width), Float(size.height)),
            .float(stripesPerTurn),
            .float(twist),
            .float2(Float(centerOffsetPx.width), Float(centerOffsetPx.height)),
            .float(Float(antialiasingLevel))
        ]
        
        let colorArgs: [Shader.Argument] = [
            .colorArray(palette)
        ]
        
        let allArgs = basicArgs + colorArgs
        
        return Shader(
            function: .init(library: ShadyGroundLibrary.default, name: "spiralStripes"),
            arguments: allArgs
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

