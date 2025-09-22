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
            BrickBackground.effectConfig,
            SpiralBackground.effectConfig
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


