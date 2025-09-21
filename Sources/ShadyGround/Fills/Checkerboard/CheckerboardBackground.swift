//
//  CheckerboardBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct CheckerboardBackground: View, PreviewableShaderEffect {
    public let cellSize: CGFloat
    public let angle: Double
    public let backgroundColor: Color
    public let foregroundColor: Color

    public init(cellSize: CGFloat = 12, angle: Double = 0, backgroundColor: Color = Color.gray.opacity(0.0), foregroundColor: Color = Color.gray.opacity(0.2)) {
        self.cellSize = cellSize
        self.angle = angle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    private var shader: Shader {
        SPMShaderLibrary.default.checkerboard(
            .float(cellSize),
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
extension CheckerboardBackground {
    public static func previewView() -> some View {
        CheckerboardPreview()
    }
}

@MainActor
private struct CheckerboardPreview: View {
    @State private var cellSize: CGFloat = 12
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    var body: some View {
        VStack(spacing: 0) {
            // Main preview
            CheckerboardBackground(
                cellSize: cellSize,
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
                        title: "Cell Size",
                        value: $cellSize,
                        in: 4...50,
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
