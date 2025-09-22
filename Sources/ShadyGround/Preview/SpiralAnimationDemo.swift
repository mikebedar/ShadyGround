//
//  SpiralAnimationDemo.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//

import SwiftUI

/// Demo showing different spiral animation patterns using ShaderTimeSource
public struct SpiralAnimationDemo: View {
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Basic animated twist
                VStack(alignment: .leading, spacing: 8) {
                    Text("Basic Twist Animation")
                        .font(.headline)
                    AnimatedSpiralBackground(
                        stripesPerTurn: 8.0,
                        baseTwist: 1.0,
                        twistAmplitude: 2.0,
                        animationSpeed: 1.0,
                        colors: [.red, .orange, .yellow, .green]
                    )
                    .frame(height: 200)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(lineWidth: 8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Fast rotation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fast Rotation")
                        .font(.headline)
                    AnimatedSpiralBackground(
                        stripesPerTurn: 12.0,
                        baseTwist: 0.5,
                        twistAmplitude: 4.0,
                        animationSpeed: 3.0,
                        colors: [.purple, .blue, .cyan, .green]
                    )
                    .frame(height: 200)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(lineWidth: 8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Slow, gentle animation
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gentle Pulse")
                        .font(.headline)
                    AnimatedSpiralBackground(
                        stripesPerTurn: 6.0,
                        baseTwist: 2.0,
                        twistAmplitude: 1.0,
                        animationSpeed: 0.5,
                        colors: [.pink, .purple, .indigo, .blue]
                    )
                    .frame(height: 200)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(lineWidth: 8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Complex pattern
                VStack(alignment: .leading, spacing: 8) {
                    Text("Complex Pattern")
                        .font(.headline)
                    AnimatedSpiralBackground(
                        stripesPerTurn: 10.0,
                        baseTwist: 1.5,
                        twistAmplitude: 3.5,
                        animationSpeed: 1.5,
                        centerOffsetPx: CGSize(width: 20, height: -10),
                        colors: [.orange, .red, .pink, .purple, .blue, .cyan]
                    )
                    .frame(height: 200)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(lineWidth: 8)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }
}

// MARK: - Alternative Implementation Examples

/// Example showing how to create custom animated spirals with different time sources
public struct CustomAnimatedSpiral: View {
    @State private var animationType: AnimationType = .smooth
    
    enum AnimationType: CaseIterable {
        case smooth, fast, slow, complex
        
        var description: String {
            switch self {
            case .smooth: return "Smooth Animation"
            case .fast: return "Fast Animation" 
            case .slow: return "Slow Animation"
            case .complex: return "Complex Pattern"
            }
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $animationType) {
                    ForEach(AnimationType.allCases, id: \.self) { type in
                        Text(type.description)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            Group {
                switch animationType {
                case .smooth:
                    AnimatedSpiralBackground(
                        stripesPerTurn: 1.0,
                        baseTwist: 1.0,
                        twistAmplitude: 2.0,
                        animationSpeed: 0.5,
                        colors: [.red, .orange, .cyan, .purple]
                    )
                    
                case .fast:
                    AnimatedSpiralBackground(
                        stripesPerTurn: 1.0,
                        baseTwist: 0.5,
                        twistAmplitude: 4.0,
                        animationSpeed: 3.0,
                        colors: [.purple, .blue, .cyan, .green]
                    )
                    
                case .slow:
                    AnimatedSpiralBackground(
                        stripesPerTurn: 1.0,
                        baseTwist: 2.0,
                        twistAmplitude: 1.0,
                        animationSpeed: 0.5,
                        colors: [.pink, .purple, .indigo, .blue]
                    )
                    
                case .complex:
                    AnimatedSpiralBackground(
                        stripesPerTurn: 1.0,
                        baseTwist: 1.5,
                        twistAmplitude: 3.5,
                        animationSpeed: 1.5,
                        centerOffsetPx: CGSize(width: 20, height: -10),
                        colors: [.orange, .red, .pink, .purple, .blue, .cyan]
                    )
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(lineWidth: 8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

// MARK: - Previews
#if DEBUG
#Preview("Spiral Animation Demo") {
    SpiralAnimationDemo()
        .frame(height: 800)
}

#Preview("Custom Animated Spiral") {
    CustomAnimatedSpiral()
        .frame(height: 600)
}
#endif
