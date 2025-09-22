//
//  ShaderEffectConformances.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

// MARK: - ShaderEffect Protocol Conformances

extension CheckerboardBackground: ShaderEffect {
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

extension StripeBackground: ShaderEffect {
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

extension DotsBackground: ShaderEffect {
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

extension WaveBackground: ShaderEffect {
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

extension GridBackground: ShaderEffect {
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

extension NoiseBackground: ShaderEffect {
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

extension SpiralBackground {
    public static var effectConfig: ShaderEffectConfig {
        ShaderEffectConfig(
            name: effectName,
            description: effectDescription,
            category: effectCategory
        )
    }
}
