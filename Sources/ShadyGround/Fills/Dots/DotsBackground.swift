//
//  DotsBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct DotsBackground: View, PreviewableShaderEffect {
    public let dotSize: CGFloat
    public let spacing: CGFloat
    public let angle: Double
    public let backgroundColor: Color
    public let foregroundColor: Color

    public init(dotSize: CGFloat = 8, spacing: CGFloat = 20, angle: Double = 0, backgroundColor: Color = Color.gray.opacity(0.0), foregroundColor: Color = Color.gray.opacity(0.2)) {
        self.dotSize = dotSize
        self.spacing = spacing
        self.angle = angle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    private var shader: Shader {
        SPMShaderLibrary.default.dots(
            .float(dotSize),
            .float(spacing),
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
extension DotsBackground {
    public static func previewView() -> some View {
        DotsPreview()
    }
}

@MainActor
private struct DotsPreview: View {
    @State private var dotSize: CGFloat = 8
    @State private var spacing: CGFloat = 20
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    // Calculate minimum spacing to prevent overlap
    private var minSpacing: CGFloat {
        dotSize + 2 // Ensure at least 2 points between dots
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main preview
            DotsBackground(
                dotSize: dotSize,
                spacing: max(spacing, minSpacing),
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
                        title: "Dot Size",
                        value: $dotSize,
                        in: 2...30,
                        step: 1
                    )
                    
                    NumericParameterControl(
                        title: "Spacing",
                        value: $spacing,
                        in: minSpacing...100,
                        step: 2
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
