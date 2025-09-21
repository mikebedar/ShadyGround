//
//  ShaderEffectPreview.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

/// A preview container that shows a shader effect with interactive parameter controls
@MainActor
public struct ShaderEffectPreview<Effect: PreviewableShaderEffect>: View {
    @State private var isShowingControls = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main preview area
            ZStack {
                Effect.previewView()
                    .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
                    .clipped()
                
                // Toggle button for controls
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isShowingControls.toggle()
                            }
                        }) {
                            Image(systemName: isShowingControls ? "slider.horizontal.3" : "slider.horizontal.3")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
            
            // Controls panel
            if isShowingControls {
                Effect.previewView()
                    .frame(height: 200)
                    .background(.regularMaterial)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

/// A parameter control for color values
@MainActor
public struct ColorParameterControl: View {
    let title: String
    @Binding var value: Color
    
    public init(title: String, value: Binding<Color>) {
        self.title = title
        self._value = value
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ColorPicker("", selection: $value)
                .labelsHidden()
        }
    }
}

/// A parameter control for numeric values with a slider
@MainActor
public struct NumericParameterControl<T: BinaryFloatingPoint>: View {
    let title: String
    @Binding var value: T
    let range: ClosedRange<T>
    let step: T
    
    public init(title: String, value: Binding<T>, in range: ClosedRange<T>, step: T = 1) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.1f", Double(value)))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            Slider(value: Binding(
                get: { Double(value) },
                set: { value = T($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound), step: Double(step))
        }
    }
}

/// A parameter control for angle values
@MainActor
public struct AngleParameterControl: View {
    let title: String
    @Binding var value: Double
    
    public init(title: String, value: Binding<Double>) {
        self.title = title
        self._value = value
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(value * 180 / .pi))°")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            Slider(value: $value, in: 0...(2 * .pi), step: .pi / 36) // 5 degree steps
        }
    }
}

/// A grid layout for parameter controls
@MainActor
public struct ParameterControlGrid<Content: View>: View {
    let content: Content
    
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    public var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            content
        }
        .padding()
    }
}

/// Color utilities for generating random and complementary colors
@MainActor
public struct ColorUtils {
    /// Generate a random color
    public static func randomColor() -> Color {
        let hue = Double.random(in: 0...1)
        let saturation = Double.random(in: 0.3...0.8)
        let brightness = Double.random(in: 0.4...0.9)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
    
    /// Generate a complementary color for the given color
    public static func complementaryColor(for color: Color) -> Color {
        // Create a simple complementary color by shifting hue
        let baseHue = Double.random(in: 0...1) // Use random hue for simplicity
        let complementaryHue = (baseHue + 0.5).truncatingRemainder(dividingBy: 1.0)
        let saturation = Double.random(in: 0.3...0.8)
        let brightness = Double.random(in: 0.4...0.9)
        
        return Color(hue: complementaryHue, saturation: saturation, brightness: brightness)
    }
    
    /// Generate a random color pair (base color and its complement)
    public static func randomColorPair() -> (Color, Color) {
        let baseColor = randomColor()
        let complementaryColor = complementaryColor(for: baseColor)
        return (baseColor, complementaryColor)
    }
}
