# ShadyGround

A Swift Package for Beautiful Metal Shader Effects in SwiftUI

ShadyGround provides a collection of high-performance Metal shader effects for SwiftUI, with a consistent API and built-in preview capabilities. Perfect for creating stunning backgrounds, patterns, and visual effects in your iOS and macOS apps.

## Features

- 🎨 **Beautiful Effects**: Pre-built shader effects for common patterns and backgrounds
- ⚡ **High Performance**: Metal shaders optimized for 60fps rendering
- 🔧 **Consistent API**: Unified interface for all effects with parameter controls
- 👀 **Live Previews**: Built-in SwiftUI previews with interactive parameter controls
- 📱 **Cross Platform**: Works on iOS 17+ and macOS 14+
- 🛠 **Extensible**: Easy to add custom shader effects

## Installation

### Swift Package Manager

Add ShadyGround to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/mikebedar/ShadyGround.git", from: "1.0.0")
]
```

## Quick Start

```swift
import ShadyGround

struct ContentView: View {
    var body: some View {
        // Simple checkerboard pattern
        CheckerboardBackground(
            cellSize: 16,
            backgroundColor: .blue.opacity(0.1),
            foregroundColor: .blue.opacity(0.3)
        )
        .frame(width: 200, height: 200)
        
        // Or try a dynamic spiral
        SpiralBackground(
            stripesPerTurn: 6,
            twist: 2.0,
            colors: [.purple, .pink, .orange, .yellow]
        )
        .frame(width: 200, height: 200)
    }
}
```

## Available Effects

ShadyGround includes 8 beautiful shader effects, each with customizable parameters:

### 🏁 Checkerboard Pattern
A classic alternating square pattern with rotation support.

```swift
CheckerboardBackground(
    cellSize: 16,           // Size of each square
    angle: .pi / 4,         // Rotation angle in radians
    backgroundColor: .blue.opacity(0.3),
    foregroundColor: .purple.opacity(0.1)
)
```

### 📏 Diagonal Stripes
Clean diagonal stripes with customizable width and angle.

```swift
StripeBackground(
    stripeWidth: 20,        // Width of each stripe
    angle: .pi / 4,         // Rotation angle in radians
    backgroundColor: .green.opacity(0.2),
    foregroundColor: .orange.opacity(0.1)
)
```

### 🔴 Polka Dots
Circular dots arranged in a grid pattern.

```swift
DotsBackground(
    dotSize: 8,             // Diameter of each dot
    spacing: 20,            // Distance between dot centers
    angle: 0,               // Rotation angle in radians
    backgroundColor: .white.opacity(0.1),
    foregroundColor: .red.opacity(0.3)
)
```

### 🌊 Wave Pattern
Smooth wave-like stripes with amplitude and frequency control.

```swift
WaveBackground(
    amplitude: 20,          // Height of wave peaks
    frequency: 0.1,         // How many waves across the pattern
    foregroundStripeWidth: 25,
    backgroundStripeWidth: 25,
    phase: 0,               // Wave offset
    angle: 0,               // Rotation angle in radians
    backgroundColor: .blue.opacity(0.1),
    foregroundColor: .cyan.opacity(0.3)
)
```

### 📐 Grid Pattern
Clean grid lines with customizable spacing and line width.

```swift
GridBackground(
    spacing: 20,            // Distance between grid lines
    lineWidth: 1,           // Thickness of grid lines
    angle: 0,               // Rotation angle in radians
    backgroundColor: .clear,
    foregroundColor: .gray.opacity(0.2)
)
```

### 📺 Noise Pattern
TV-static style noise with fractal properties and customizable intensity.

```swift
NoiseBackground(
    scale: 1.0,             // Overall noise scale
    intensity: 1.0,         // Noise visibility (0-1)
    octaves: 4,             // Number of noise layers
    persistence: 0.5,       // How much each octave contributes
    seed: 0,                // Random seed for variation
    angle: 0,               // Rotation angle in radians
    backgroundColor: .clear,
    foregroundColor: .gray.opacity(0.8)
)
```

### 🧱 Brick Pattern
Classic brick wall pattern with customizable dimensions and mortar.

```swift
BrickBackground(
    brickWidth: 80,         // Width of each brick
    brickHeight: 40,        // Height of each brick
    mortarWidth: 4,         // Width of mortar lines
    angle: 0,               // Rotation angle in radians
    backgroundColor: .brown.opacity(0.1),
    foregroundColor: .orange.opacity(0.3)
)
```

### 🌀 Spiral Pattern
Dynamic spiral stripes with customizable twist and color palette.

```swift
SpiralBackground(
    stripesPerTurn: 8.0,    // Number of color bands per rotation
    twist: 1.0,             // Logarithmic spiral twist factor
    centerOffsetPx: .zero,  // Offset from center in pixels
    paletteCount: 4.0,      // Number of colors to use
    colors: [.red, .orange, .yellow, .green]
)
```

## Advanced Usage

### Animated Effects
```swift
@State private var cellSize: CGFloat = 12
@State private var spiralTwist: CGFloat = 1.0

var body: some View {
    VStack {
        // Animated checkerboard
        CheckerboardBackground(
            cellSize: cellSize,
            backgroundColor: .clear,
            foregroundColor: .blue.opacity(0.3)
        )
        
        // Animated spiral
        SpiralBackground(
            stripesPerTurn: 8,
            twist: spiralTwist,
            colors: [.red, .orange, .yellow, .green]
        )
    }
    .onAppear {
        withAnimation(.easeInOut(duration: 2).repeatForever()) {
            cellSize = 24
            spiralTwist = 3.0
        }
    }
}
```

### Masked Effects
```swift
SpiralBackground(
    stripesPerTurn: 12,
    twist: 2.0,
    colors: [.purple, .blue, .cyan, .green]
)
.mask(
    Circle()
        .frame(width: 200, height: 200)
)
```

### Layered Effects
```swift
ZStack {
    // Base noise texture
    NoiseBackground(
        scale: 2.0,
        intensity: 0.3,
        backgroundColor: .clear,
        foregroundColor: .gray.opacity(0.2)
    )
    
    // Overlay with grid
    GridBackground(
        spacing: 30,
        lineWidth: 2,
        backgroundColor: .clear,
        foregroundColor: .blue.opacity(0.4)
    )
    .blendMode(.multiply)
}
```

### Size-Aware Effects
```swift
// Spiral automatically adapts to view size
SpiralBackground(
    stripesPerTurn: 6,
    twist: 1.5,
    centerOffsetPx: CGSize(width: 20, height: -10)
)
.frame(width: 300, height: 300)

// Other effects work at any size
NoiseBackground(
    scale: 0.5,
    intensity: 0.8,
    octaves: 6
)
.frame(width: 150, height: 150)
```

## Preview System

ShadyGround includes a comprehensive preview system for exploring all effects:

```swift
// Use the built-in demo app
import ShadyGround

#Preview("ShadyGround Demo") {
    ShadyGroundDemo()
}

// Or preview individual effects
#Preview("Checkerboard Effect") {
    CheckerboardPreview()
}

#Preview("Spiral Effect") {
    SpiralPreview()
}
```

The preview system provides:
- 🎛️ **Interactive Controls**: Real-time sliders, color pickers, and parameter adjustments
- 🔄 **Live Updates**: See changes instantly as you adjust parameters
- 📊 **Parameter Display**: Current values shown for all controls
- 🎨 **Visual Feedback**: Immediate preview of all 8 effects
- 📱 **Organized Layout**: Clean, intuitive control interface

### Running the Demo
The `ShadyGroundDemo` provides a complete interactive showcase of all effects with:
- Effect selection dropdown
- Category filtering
- Full parameter controls for each effect
- Real-time preview updates

## Creating Custom Effects

To create your own shader effects, conform to the `ShaderEffect` protocol:

```swift
import SwiftUI

public struct MyCustomEffect: View, ShaderEffect {
    public let parameter1: CGFloat
    public let parameter2: Color
    
    public init(parameter1: CGFloat = 10, parameter2: Color = .blue) {
        self.parameter1 = parameter1
        self.parameter2 = parameter2
    }
    
    public var body: some View {
        Rectangle()
            .fill(.black)
            .shadyLayerEffect(shader)
    }
    
    private var shader: Shader {
        ShadyGroundLibrary.default.myCustomShader(
            .float(parameter1),
            .color(parameter2)
        )
    }
}

// MARK: - ShaderEffect Protocol Conformance
extension MyCustomEffect {
    public static let effectName = "My Custom Effect"
    public static let effectDescription = "A custom shader effect"
    public static let effectCategory = "Custom"
    
    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory,
            parameters: [
                .float("Parameter 1", range: 0...100, defaultValue: 10),
                .color("Parameter 2", defaultValue: .blue)
            ]
        )
    }
}
```

### For Size-Aware Effects
If your effect needs to adapt to view size (like the Spiral), use `SizeAwareShaderModifier`:

```swift
public var body: some View {
    Rectangle()
        .fill(.black)
        .sizeAwareShaderEffect { size in
            makeShader(for: size)
        }
}

private func makeShader(for size: CGSize) -> Shader {
    ShadyGroundLibrary.default.mySizeAwareShader(
        .float2(Float(size.width), Float(size.height)),
        .float(parameter1)
    )
}
```

## Requirements

- iOS 17.0+ / macOS 14.0+
- Swift 6.2+
- Xcode 16.0+

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

If you encounter any issues or have questions, please open an issue on GitHub.
