//
//  NoiseBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct NoiseBackground: View, PreviewableShaderEffect {
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
        SPMShaderLibrary.default.noise(
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
            .layerEffect(shader, maxSampleOffset: .zero)
    }
}

// MARK: - Preview Implementation
extension NoiseBackground {
    public static func previewView() -> some View {
        NoisePreview()
    }
}

@MainActor
private struct NoisePreview: View {
    @State private var scale: CGFloat = 1.0
    @State private var intensity: CGFloat = 1.0
    @State private var octaves: CGFloat = 4
    @State private var persistence: CGFloat = 0.5
    @State private var seed: Double = 0
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.8)
    
    var body: some View {
        VStack(spacing: 0) {
            // Main preview
            NoiseBackground(
                scale: scale,
                intensity: intensity,
                octaves: octaves,
                persistence: persistence,
                seed: seed,
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
                        title: "Scale",
                        value: $scale,
                        in: 0.01...1.0,
                        step: 0.01
                    )
                    
                    NumericParameterControl(
                        title: "Intensity",
                        value: $intensity,
                        in: 0.0...1.0,
                        step: 0.01
                    )
                    
                    NumericParameterControl(
                        title: "Octaves",
                        value: $octaves,
                        in: 1...8,
                        step: 1
                    )
                    
                    NumericParameterControl(
                        title: "Persistence",
                        value: $persistence,
                        in: 0.1...1.0,
                        step: 0.1
                    )
                    
                    NumericParameterControl(
                        title: "Seed",
                        value: $seed,
                        in: 0...1000,
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
