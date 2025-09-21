//
//  WaveBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct WaveBackground: View, PreviewableShaderEffect {
    public let amplitude: CGFloat
    public let frequency: CGFloat
    public let foregroundStripeWidth: CGFloat
    public let backgroundStripeWidth: CGFloat
    public let phase: Double
    public let angle: Double
    public let backgroundColor: Color
    public let foregroundColor: Color

    public init(amplitude: CGFloat = 20, frequency: CGFloat = 0.1, foregroundStripeWidth: CGFloat = 25, backgroundStripeWidth: CGFloat = 25, phase: Double = 0, angle: Double = 0, backgroundColor: Color = Color.gray.opacity(0.0), foregroundColor: Color = Color.gray.opacity(0.2)) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.foregroundStripeWidth = foregroundStripeWidth
        self.backgroundStripeWidth = backgroundStripeWidth
        self.phase = phase
        self.angle = angle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    private var shader: Shader {
        SPMShaderLibrary.default.wave(
            .float(amplitude),
            .float(frequency),
            .float(foregroundStripeWidth),
            .float(backgroundStripeWidth),
            .float(phase),
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
extension WaveBackground {
    public static func previewView() -> some View {
        WavePreview()
    }
}

@MainActor
private struct WavePreview: View {
    @State private var amplitude: CGFloat = 20
    @State private var frequency: CGFloat = 0.1
    @State private var foregroundStripeWidth: CGFloat = 25
    @State private var backgroundStripeWidth: CGFloat = 25
    @State private var phase: Double = 0
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    var body: some View {
        VStack(spacing: 0) {
            // Main preview
            WaveBackground(
                amplitude: amplitude,
                frequency: frequency,
                foregroundStripeWidth: foregroundStripeWidth,
                backgroundStripeWidth: backgroundStripeWidth,
                phase: phase,
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
                        title: "Amplitude",
                        value: $amplitude,
                        in: 5...100,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Frequency",
                        value: $frequency,
                        in: 0.01...0.5,
                        step: 0.01
                    )
                    
                    NumericParameterControl(
                        title: "Foreground Stripe Width",
                        value: $foregroundStripeWidth,
                        in: 5...100,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Background Stripe Width",
                        value: $backgroundStripeWidth,
                        in: 5...100,
                        step: 5
                    )
                    
                    AngleParameterControl(
                        title: "Phase",
                        value: $phase
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
