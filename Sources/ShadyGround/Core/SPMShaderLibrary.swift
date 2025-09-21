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
