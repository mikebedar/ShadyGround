//
//  StripeBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

public struct StripeBackground: View, PreviewableShaderEffect {
    public let stripeWidth: CGFloat
    public let angle: Double
    public let backgroundColor: Color
    public let foregroundColor: Color

    public init(stripeWidth: CGFloat = 20, angle: Double = 0, backgroundColor: Color = Color.gray.opacity(0.0), foregroundColor: Color = Color.gray.opacity(0.2)) {
        self.stripeWidth = stripeWidth
        self.angle = angle
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    public var body: some View {
        Rectangle()
            .fill(.black)
            .layerEffect(
                SPMShaderLibrary.default.stripe(
                    .float(stripeWidth),
                    .float(angle),
                    .color(backgroundColor),
                    .color(foregroundColor)
                ),
                maxSampleOffset: .zero
            )
    }
}

// MARK: - Preview Implementation
extension StripeBackground {
    public static func previewView() -> some View {
        StripePreview()
    }
}

@MainActor
private struct StripePreview: View {
    @State private var stripeWidth: CGFloat = 20
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    var body: some View {
        VStack(spacing: 0) {
            // Main preview
            StripeBackground(
                stripeWidth: stripeWidth,
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
                        title: "Stripe Width",
                        value: $stripeWidth,
                        in: 5...100,
                        step: 5
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
