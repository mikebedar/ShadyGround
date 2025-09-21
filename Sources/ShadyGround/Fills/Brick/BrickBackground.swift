//
//  BrickBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

/// A brick pattern with customizable brick dimensions, mortar width, and rotation
public struct BrickBackground: View, PreviewableShaderEffect {
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
        SPMShaderLibrary.default.brick(
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

extension BrickBackground {
    public static func previewView() -> some View {
        BrickPreview()
    }
}

@MainActor
private struct BrickPreview: View {
    @State private var brickWidth: CGFloat = 80
    @State private var brickHeight: CGFloat = 40
    @State private var mortarWidth: CGFloat = 4
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    var body: some View {
        VStack(spacing: 0) {
            // Main preview
            BrickBackground(
                brickWidth: brickWidth,
                brickHeight: brickHeight,
                mortarWidth: mortarWidth,
                angle: angle,
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            
            // Parameter controls
            VStack(spacing: 16) {
                // Randomize button
                Button(action: randomizeColors) {
                    HStack {
                        Image(systemName: "shuffle")
                        Text("Randomize Colors")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.blue, in: Capsule())
                }
                
                ParameterControlGrid {
                    NumericParameterControl(
                        title: "Brick Width (px)",
                        value: $brickWidth,
                        in: 20...200,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Brick Height (px)",
                        value: $brickHeight,
                        in: 10...100,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Mortar Width (px)",
                        value: $mortarWidth,
                        in: 1...20,
                        step: 1
                    )
                    
                    AngleParameterControl(
                        title: "Angle",
                        value: $angle
                    )
                    
                    ColorParameterControl(
                        title: "Background Color",
                        value: $backgroundColor
                    )
                    
                    ColorParameterControl(
                        title: "Foreground Color",
                        value: $foregroundColor
                    )
                }
            }
        }
        .onAppear {
            randomizeColors()
        }
    }
    
    private func randomizeColors() {
        let (baseColor, complementaryColor) = ColorUtils.randomColorPair()
        backgroundColor = baseColor
        foregroundColor = complementaryColor
    }
}
