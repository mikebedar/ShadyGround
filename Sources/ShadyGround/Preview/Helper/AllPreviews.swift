//
//  AllPreviews.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

// Import all preview files to make them available
// This file ensures all preview classes are accessible to the demo


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
                        title: "Cell Size (px)",
                        value: $cellSize,
                        in: 4...100,
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
                        title: "Dot Size (px)",
                        value: $dotSize,
                        in: 2...50,
                        step: 1
                    )
                    
                    NumericParameterControl(
                        title: "Spacing (px)",
                        value: $spacing,
                        in: minSpacing...150,
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
                        title: "Spacing (px)",
                        value: $spacing,
                        in: 10...200,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Line Width (px)",
                        value: $lineWidth,
                        in: 0.5...20,
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
                        title: "Scale (factor)",
                        value: $scale,
                        in: 0.01...2.0,
                        step: 0.01
                    )
                    
                    NumericParameterControl(
                        title: "Intensity (%)",
                        value: $intensity,
                        in: 0.0...1.0,
                        step: 0.01
                    )
                    
                    NumericParameterControl(
                        title: "Octaves (layers)",
                        value: $octaves,
                        in: 1...8,
                        step: 1
                    )
                    
                    NumericParameterControl(
                        title: "Persistence (factor)",
                        value: $persistence,
                        in: 0.1...1.0,
                        step: 0.1
                    )
                    
                    NumericParameterControl(
                        title: "Seed (random)",
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
                HStack(spacing: 12) {
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
                    
                    // Gradient button
                    Button(action: generateGradient) {
                        HStack {
                            Image(systemName: "arrow.left.and.right")
                            Text("Random Gradient")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.purple, in: Capsule())
                    }
                }
                
                ParameterControlGrid {
                    NumericParameterControl(
                        title: "Stripe Width (px)",
                        value: $stripeWidth,
                        in: 5...200,
                        step: 5
                    )
                    
                    AngleParameterControl(
                        title: "Angle",
                        value: $angle
                    )
                    
                    NumericParameterControl(
                        title: "Color Count",
                        value: $colorCount,
                        in: 2...128,
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
        let count = Int(colorCount)
        var generatedColors: [Color] = []
        
        // Pick 2-4 random anchor hues to cluster around
        let anchorCount = Int.random(in: 2...min(4, max(2, count)))
        var anchorHues: [Double] = []
        for _ in 0..<anchorCount {
            anchorHues.append(Double.random(in: 0...1))
        }
        
        // Generate colors clustered around anchor hues with organic variation
        for _ in 0..<count {
            // Pick a random anchor to cluster around
            let baseHue = anchorHues.randomElement() ?? 0.5
            
            // Add organic variation around the anchor
            let hueVariation = Double.random(in: -0.15...0.15)
            let hue = (baseHue + hueVariation).truncatingRemainder(dividingBy: 1.0)
            
            // More varied saturation and brightness for organic feel
            let saturation = Double.random(in: 0.3...1.0)
            let brightness = Double.random(in: 0.4...1.0)
            
            generatedColors.append(Color(hue: hue < 0 ? hue + 1 : hue, saturation: saturation, brightness: brightness))
        }
        
        // Shuffle for more randomness
        colors = generatedColors.shuffled()
    }
    
    private func generateGradient() {
        let count = Int(colorCount)
        guard count > 0 else { return }
        
        // Generate two random colors
        let startHue = Double.random(in: 0...1)
        let startSaturation = Double.random(in: 0.6...1.0)
        let startBrightness = Double.random(in: 0.6...1.0)
        
        let endHue = Double.random(in: 0...1)
        let endSaturation = Double.random(in: 0.6...1.0)
        let endBrightness = Double.random(in: 0.6...1.0)
        
        var generatedColors: [Color] = []
        
        // Interpolate between start and end colors
        for i in 0..<count {
            let t = count > 1 ? Double(i) / Double(count - 1) : 0.0
            
            // Interpolate each component
            let hue = startHue + (endHue - startHue) * t
            let saturation = startSaturation + (endSaturation - startSaturation) * t
            let brightness = startBrightness + (endBrightness - startBrightness) * t
            
            generatedColors.append(Color(hue: hue, saturation: saturation, brightness: brightness))
        }
        
        colors = generatedColors
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
    @State private var stripeWidth: CGFloat = 25
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
                stripeWidth: stripeWidth,
                backgroundStripeWidth: stripeWidth, // Use same width for both
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
                        title: "Amplitude (px)",
                        value: $amplitude,
                        in: 5...200,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Frequency (cycles/px)",
                        value: $frequency,
                        in: 0.01...1.0,
                        step: 0.01
                    )
                    
                    NumericParameterControl(
                        title: "Stripe Width (px)",
                        value: $stripeWidth,
                        in: 5...200,
                        step: 5
                    )
                    
                    AngleParameterControl(
                        title: "Phase (degrees)",
                        value: $phase
                    )
                    
                    AngleParameterControl(
                        title: "Angle",
                        value: $angle
                    )
                    
                    NumericParameterControl(
                        title: "Color Count",
                        value: $colorCount,
                        in: 2...128,
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
        let count = Int(colorCount)
        var generatedColors: [Color] = []
        
        // Pick 2-4 random anchor hues to cluster around
        let anchorCount = Int.random(in: 2...min(4, max(2, count)))
        var anchorHues: [Double] = []
        for _ in 0..<anchorCount {
            anchorHues.append(Double.random(in: 0...1))
        }
        
        // Generate colors clustered around anchor hues with organic variation
        for _ in 0..<count {
            // Pick a random anchor to cluster around
            let baseHue = anchorHues.randomElement() ?? 0.5
            
            // Add organic variation around the anchor
            let hueVariation = Double.random(in: -0.15...0.15)
            let hue = (baseHue + hueVariation).truncatingRemainder(dividingBy: 1.0)
            
            // More varied saturation and brightness for organic feel
            let saturation = Double.random(in: 0.3...1.0)
            let brightness = Double.random(in: 0.4...1.0)
            
            generatedColors.append(Color(hue: hue < 0 ? hue + 1 : hue, saturation: saturation, brightness: brightness))
        }
        
        // Shuffle for more randomness
        colors = generatedColors.shuffled()
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
                        title: "Stripes Per Turn (count)",
                        value: $stripesPerTurn,
                        in: 1...30,
                        step: 1
                    )
                    
                    NumericParameterControl(
                        title: "Twist (strength)",
                        value: $twist,
                        in: 0...10,
                        step: 0.1
                    )
                    
                    NumericParameterControl(
                        title: "Center Offset X (px)",
                        value: Binding(
                            get: { centerOffsetPx.width },
                            set: { centerOffsetPx.width = $0 }
                        ),
                        in: -200...200,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Center Offset Y (px)",
                        value: Binding(
                            get: { centerOffsetPx.height },
                            set: { centerOffsetPx.height = $0 }
                        ),
                        in: -200...200,
                        step: 5
                    )
                    
                    NumericParameterControl(
                        title: "Color Count (colors)",
                        value: $colorCount,
                        in: 1...128,
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
        let count = Int(colorCount)
        var generatedColors: [Color] = []
        
        // Pick 2-4 random anchor hues to cluster around
        let anchorCount = Int.random(in: 2...min(4, max(2, count)))
        var anchorHues: [Double] = []
        for _ in 0..<anchorCount {
            anchorHues.append(Double.random(in: 0...1))
        }
        
        // Generate colors clustered around anchor hues with organic variation
        for _ in 0..<count {
            // Pick a random anchor to cluster around
            let baseHue = anchorHues.randomElement() ?? 0.5
            
            // Add organic variation around the anchor
            let hueVariation = Double.random(in: -0.15...0.15)
            let hue = (baseHue + hueVariation).truncatingRemainder(dividingBy: 1.0)
            
            // More varied saturation and brightness for organic feel
            let saturation = Double.random(in: 0.3...1.0)
            let brightness = Double.random(in: 0.4...1.0)
            
            generatedColors.append(Color(hue: hue < 0 ? hue + 1 : hue, saturation: saturation, brightness: brightness))
        }
        
        // Shuffle for more randomness
        colors = generatedColors.shuffled()
    }
}
