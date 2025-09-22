//
//  ShadyGroundLibrary.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

/// Custom shader library that works with SPM packages
@MainActor
public enum ShadyGroundLibrary {
    
    /// The default shader library for this SPM package
    public static var `default`: ShaderLibrary {
        // For SPM packages, use the bundle-based approach
        return ShaderLibrary.bundle(.module)
    }
}

// MARK: - Spiral Shader Extension
extension ShaderLibrary {
    /// Creates a spiral stripes shader with customizable parameters
    public func spiralStripes(
        _ viewSize: Shader.Argument,
        _ stripesPerTurn: Shader.Argument,
        _ twist: Shader.Argument,
        _ centerOffsetPx: Shader.Argument,
        _ paletteCount: Shader.Argument,
        _ c0: Shader.Argument, _ c1: Shader.Argument, _ c2: Shader.Argument, _ c3: Shader.Argument,
        _ c4: Shader.Argument, _ c5: Shader.Argument, _ c6: Shader.Argument, _ c7: Shader.Argument,
        _ c8: Shader.Argument, _ c9: Shader.Argument, _ c10: Shader.Argument, _ c11: Shader.Argument,
        _ c12: Shader.Argument, _ c13: Shader.Argument, _ c14: Shader.Argument, _ c15: Shader.Argument
    ) -> Shader {
        return Shader(function: .init(library: self, name: "spiralStripes"), arguments: [
            viewSize, stripesPerTurn, twist, centerOffsetPx, paletteCount,
            c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15
        ])
    }
}
