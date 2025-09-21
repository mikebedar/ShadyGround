//
//  ShaderEffect.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

/// A protocol that defines the interface for all shader effects in ShadyGround
@MainActor
public protocol ShaderEffect: View {
    /// The unique identifier for this effect type
    static var effectName: String { get }
    
    /// A brief description of what this effect does
    static var effectDescription: String { get }
    
    /// The category this effect belongs to (e.g., "Patterns", "Textures", "Gradients")
    static var effectCategory: String { get }
}

/// A protocol for shader effects that support parameter previews
@MainActor
public protocol PreviewableShaderEffect: ShaderEffect {
    associatedtype PreviewView: View
    /// Creates a preview view with interactive controls for all parameters
    static func previewView() -> PreviewView
}

/// Base configuration for shader effects
public struct ShaderEffectConfig {
    public let name: String
    public let description: String
    public let category: String
    
    public init(name: String, description: String, category: String) {
        self.name = name
        self.description = description
        self.category = category
    }
}

/// A registry for all available shader effects
@MainActor
public enum ShaderEffectRegistry {
    /// Returns all registered shader effect configurations
    public static var allEffects: [ShaderEffectConfig] {
        [
            CheckerboardBackground.effectConfig,
            StripeBackground.effectConfig,
            DotsBackground.effectConfig,
            WaveBackground.effectConfig,
            GridBackground.effectConfig,
            NoiseBackground.effectConfig,
            CirclesBackground.effectConfig,
            SquaresBackground.effectConfig,
            SpiralBackground.effectConfig,
            BrickBackground.effectConfig
        ]
    }
    
    /// Returns effects filtered by category
    public static func effects(in category: String) -> [ShaderEffectConfig] {
        allEffects.filter { $0.category == category }
    }
    
    /// Returns all available categories
    public static var categories: [String] {
        Array(Set(allEffects.map { $0.category })).sorted()
    }
}

// MARK: - Extensions for existing effects

extension CheckerboardBackground {
    public static var effectName: String { "Checkerboard" }
    public static var effectDescription: String { "A classic checkerboard pattern with customizable colors and cell size" }
    public static var effectCategory: String { "Patterns" }
    
    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension StripeBackground {
    public static var effectName: String { "Stripe" }
    public static var effectDescription: String { "Diagonal stripes with customizable width, angle, and colors" }
    public static var effectCategory: String { "Patterns" }
    
    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension DotsBackground {
    public static var effectName: String { "Dots" }
    public static var effectDescription: String { "Polka dot pattern with customizable dot size and spacing" }
    public static var effectCategory: String { "Patterns" }

    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension WaveBackground {
    public static var effectName: String { "Wave" }
    public static var effectDescription: String { "Smooth wave pattern with customizable amplitude, frequency, and phase" }
    public static var effectCategory: String { "Patterns" }

    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension GridBackground {
    public static var effectName: String { "Grid" }
    public static var effectDescription: String { "Regular grid pattern with customizable spacing and line width" }
    public static var effectCategory: String { "Patterns" }

    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension NoiseBackground {
    public static var effectName: String { "Noise" }
    public static var effectDescription: String { "High-quality fractal noise with multiple octaves and customizable parameters" }
    public static var effectCategory: String { "Patterns" }

    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension CirclesBackground {
    public static var effectName: String { "Concentric Circles" }
    public static var effectDescription: String { "Concentric circular patterns with customizable spacing and line width" }
    public static var effectCategory: String { "Patterns" }

    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension SquaresBackground {
    public static var effectName: String { "Concentric Squares" }
    public static var effectDescription: String { "Concentric square patterns with customizable spacing and line width" }
    public static var effectCategory: String { "Patterns" }

    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension SpiralBackground {
    public static var effectName: String { "Spiral" }
    public static var effectDescription: String { "Spiral patterns with customizable tightness and line width" }
    public static var effectCategory: String { "Patterns" }

    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

extension BrickBackground {
    public static var effectName: String { "Brick" }
    public static var effectDescription: String { "Brick wall pattern with customizable dimensions and mortar width" }
    public static var effectCategory: String { "Patterns" }

    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}

