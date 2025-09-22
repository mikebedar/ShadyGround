//
//  AllPreviews.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

// Import all preview files to make them available
// This file ensures all preview classes are accessible to the demo

// Brick Preview
extension BrickBackground {
    public static func previewView() -> some View {
        BrickPreview()
    }
}

@MainActor
public struct BrickPreview: View {
    @State private var brickWidth: CGFloat = 80
    @State private var brickHeight: CGFloat = 40
    @State private var mortarWidth: CGFloat = 4
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    public var body: some View {
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

// Checkerboard Preview
extension CheckerboardBackground {
    public static func previewView() -> some View {
        CheckerboardPreview()
    }
}

@MainActor
public struct CheckerboardPreview: View {
    @State private var cellSize: CGFloat = 12
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    public var body: some View {
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

// Dots Preview
extension DotsBackground {
    public static func previewView() -> some View {
        DotsPreview()
    }
}

@MainActor
public struct DotsPreview: View {
    @State private var dotSize: CGFloat = 8
    @State private var spacing: CGFloat = 20
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    // Calculate minimum spacing to prevent overlap
    private var minSpacing: CGFloat {
        dotSize + 2 // Ensure at least 2 points between dots
    }
    
    public var body: some View {
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

// Grid Preview
extension GridBackground {
    public static func previewView() -> some View {
        GridPreview()
    }
}

@MainActor
public struct GridPreview: View {
    @State private var spacing: CGFloat = 20
    @State private var lineWidth: CGFloat = 1
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.2)
    
    public var body: some View {
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

// Noise Preview
extension NoiseBackground {
    public static func previewView() -> some View {
        NoisePreview()
    }
}

@MainActor
public struct NoisePreview: View {
    @State private var scale: CGFloat = 1.0
    @State private var intensity: CGFloat = 1.0
    @State private var octaves: CGFloat = 4
    @State private var persistence: CGFloat = 0.5
    @State private var seed: Double = 0
    @State private var angle: Double = 0
    @State private var backgroundColor: Color = .gray.opacity(0.0)
    @State private var foregroundColor: Color = .gray.opacity(0.8)
    
    public var body: some View {
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

// Stripe Preview
extension StripeBackground {
    public static func previewView() -> some View {
        StripePreview()
    }
}

@MainActor
public struct StripePreview: View {
    @State private var stripeWidth: CGFloat = 20
    @State private var angle: Double = 0
    @State private var colorCount: CGFloat = 2
    @State private var colors: [Color] = [.gray.opacity(0.0), .gray.opacity(0.2)]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main preview
            StripeBackground(
                stripeWidth: stripeWidth,
                angle: angle,
                colors: colors
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
                    
                    NumericParameterControl(
                        title: "Color Count",
                        value: $colorCount,
                        in: 2...8,
                        step: 1
                    )
                }
            }
        }
        .onAppear {
            randomizeColors()
        }
        .onChange(of: colorCount) { _, _ in
            randomizeColors()
        }
    }
    
    private func randomizeColors() {
        let colorOptions: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .mint, .indigo]
        let selectedColors = Array(colorOptions.shuffled().prefix(Int(colorCount)))
        colors = selectedColors
    }
}

// Wave Preview
extension WaveBackground {
    public static func previewView() -> some View {
        WavePreview()
    }
}

@MainActor
public struct WavePreview: View {
    @State private var amplitude: CGFloat = 20
    @State private var frequency: CGFloat = 0.1
    @State private var foregroundStripeWidth: CGFloat = 25
    @State private var backgroundStripeWidth: CGFloat = 25
    @State private var phase: Double = 0
    @State private var angle: Double = 0
    @State private var colorCount: CGFloat = 2
    @State private var colors: [Color] = [.gray.opacity(0.0), .gray.opacity(0.2)]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main preview
            WaveBackground(
                amplitude: amplitude,
                frequency: frequency,
                foregroundStripeWidth: foregroundStripeWidth,
                backgroundStripeWidth: backgroundStripeWidth,
                phase: phase,
                angle: angle,
                colors: colors
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
                    
                    NumericParameterControl(
                        title: "Color Count",
                        value: $colorCount,
                        in: 2...8,
                        step: 1
                    )
                }
            }
        }
        .onAppear {
            randomizeColors()
        }
        .onChange(of: colorCount) { _, _ in
            randomizeColors()
        }
    }
    
    private func randomizeColors() {
        let colorOptions: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .mint, .indigo]
        let selectedColors = Array(colorOptions.shuffled().prefix(Int(colorCount)))
        colors = selectedColors
    }
}


// Spiral Preview
extension SpiralBackground {
    public static func previewView() -> some View {
        SpiralPreview()
    }
}

@MainActor
public struct SpiralPreview: View {
    @State private var stripesPerTurn: CGFloat = 8.0
    @State private var twist: CGFloat = 1.0
    @State private var centerOffsetPx: CGSize = .zero
    @State private var colorCount: CGFloat = 4
    @State private var colors: [Color] = [.red, .orange, .yellow, .green]
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main preview
            SpiralBackground(
                stripesPerTurn: stripesPerTurn,
                twist: twist,
                centerOffsetPx: centerOffsetPx,
                colors: colors
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
                        title: "Stripes Per Turn",
                        value: $stripesPerTurn,
                        in: 1...20,
                        step: 1
                    )
                    
                    NumericParameterControl(
                        title: "Twist",
                        value: $twist,
                        in: 0...4,
                        step: 0.1
                    )
                    
                    NumericParameterControl(
                        title: "Center Offset X",
                        value: Binding(
                            get: { centerOffsetPx.width },
                            set: { centerOffsetPx.width = $0 }
                        ),
                        in: -100...100,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Center Offset Y",
                        value: Binding(
                            get: { centerOffsetPx.height },
                            set: { centerOffsetPx.height = $0 }
                        ),
                        in: -100...100,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Color Count",
                        value: $colorCount,
                        in: 1...8,
                        step: 1
                    )
                }
            }
        }
        .onAppear {
            randomizeColors()
        }
        .onChange(of: colorCount) { _, _ in
            randomizeColors()
        }
    }
    
    private func randomizeColors() {
        let colorOptions: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink, .cyan, .mint, .indigo]
        let selectedColors = Array(colorOptions.shuffled().prefix(Int(colorCount)))
        colors = selectedColors
    }
}
