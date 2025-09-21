//
//  GridBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct GridBackground: View, PreviewableShaderEffect {
    public let spacing: CGFloat
    public let lineWidth: CGFloat
    public let angle: Double
    public let backgroundColor: Color
    public let foregroundColor: Color

    public init(spacing: CGFloat = 20, lineWidth: CGFloat = 1, angle: Double = 0, backgroundColor: Color = Color.gray.opacity(0.0), foregroundColor: Color = Color.gray.opacity(0.2)) {
        self.spacing = spacing
        self.lineWidth = lineWidth
        self.angle = angle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    private var shader: Shader {
        SPMShaderLibrary.default.grid(
            .float(spacing),
            .float(lineWidth),
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

// MARK: - Preview Implementation
extension GridBackground {
    public static func previewView() -> some View {
        GridPreview()
    }
}

@MainActor
private struct GridPreview: View {
    @State private var spacing: CGFloat = 20
    @State private var lineWidth: CGFloat = 1
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    var body: some View {
        VStack(spacing: 0) {
            // Main preview
            GridBackground(
                spacing: spacing,
                lineWidth: lineWidth,
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
                        title: "Spacing",
                        value: $spacing,
                        in: 10...100,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Line Width",
                        value: $lineWidth,
                        in: 0.5...10,
                        step: 0.5
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
