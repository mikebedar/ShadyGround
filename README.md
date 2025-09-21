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
    .package(url: "https://github.com/your-org/ShadyGround.git", from: "1.0.0")
]
```

## Quick Start

```swift
import ShadyGround

struct ContentView: View {
    var body: some View {
        CheckerboardBackground()
            .frame(width: 200, height: 200)
    }
}
```

## Available Effects

### Checkerboard Pattern
```swift
CheckerboardBackground(
    cellSize: 16,
    light: .blue.opacity(0.3),
    dark: .purple.opacity(0.1)
)
```

### Diagonal Stripes
```swift
StripeBackground(
    stripeWidth: 20,
    angle: .pi / 4, // 45 degrees
    light: .green.opacity(0.2),
    dark: .orange.opacity(0.1)
)
```

## Advanced Usage

### Animated Effects
```swift
@State private var cellSize: CGFloat = 12

var body: some View {
    CheckerboardBackground(cellSize: cellSize)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever()) {
                cellSize = 24
            }
        }
}
```

### Masked Effects
```swift
StripeBackground()
    .mask(
        Circle()
            .frame(width: 100, height: 100)
    )
```

### Layered Effects
```swift
ZStack {
    CheckerboardBackground()
    StripeBackground()
        .blendMode(.multiply)
}
```

## Preview System

ShadyGround includes a comprehensive preview system for exploring effects:

```swift
#Preview("Checkerboard Effect") {
    ShaderEffectPreview<CheckerboardBackground>()
}
```

The preview system provides:
- Interactive parameter controls
- Real-time effect updates
- Parameter value displays
- Organized control layouts

## Creating Custom Effects

To create your own shader effects, conform to the `ShaderEffect` protocol:

```swift
public struct MyCustomEffect: View, PreviewableShaderEffect {
    public let parameter1: CGFloat
    public let parameter2: Color
    
    public init(parameter1: CGFloat = 10, parameter2: Color = .blue) {
        self.parameter1 = parameter1
        self.parameter2 = parameter2
    }
    
    public var body: some View {
        Rectangle()
            .fill(.black)
            .layerEffect(
                ShaderLibrary.default.myCustomShader(
                    .float(parameter1),
                    .color(parameter2)
                ),
                maxSampleOffset: .zero
            )
    }
    
    // MARK: - Preview Implementation
    public static func previewView() -> some View {
        MyCustomPreview()
    }
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
