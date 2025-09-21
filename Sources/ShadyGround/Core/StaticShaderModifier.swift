//
//  StaticShaderModifier.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//

import SwiftUI

public extension View {
    /// Applies a **size-agnostic** Metal shader to the view.
    ///
    /// Use this for shaders that only depend on `position` (pixel space) and
    /// their own uniforms—i.e., they **do not** need the view's size.
    ///
    /// The shader is created on demand from the `makeShader` closure.
    ///
    /// - Parameters:
    ///   - makeShader: Closure that builds and returns the `Shader`.
    ///   - maxSampleOffset: Maximum neighbor sampling distance your shader might use.
    ///     Keep at `.zero` for purely procedural effects that don’t call `layer.sample`.
    ///   - isEnabled: Pass `false` to disable the effect without removing it.
    /// - Returns: A view with the shader applied.
    @inlinable
    func shadyLayerEffect(
        _ makeShader: @escaping () -> Shader,
        maxSampleOffset: CGSize = .zero,
        isEnabled: Bool = true
    ) -> some View {
        modifier(StaticShaderModifier(
            makeShader: makeShader,
            maxSampleOffset: maxSampleOffset,
            isEnabled: isEnabled
        ))
    }

    /// Convenience overload when you already have a `Shader` instance.
    @inlinable
    func shadyLayerEffect(
        _ shader: Shader,
        maxSampleOffset: CGSize = .zero,
        isEnabled: Bool = true
    ) -> some View {
        layerEffect(shader, maxSampleOffset: maxSampleOffset, isEnabled: isEnabled)
    }
}

// MARK: - Implementation

public struct StaticShaderModifier: ViewModifier {
    let makeShader: () -> Shader
    let maxSampleOffset: CGSize
    let isEnabled: Bool

    public init(
        makeShader: @escaping () -> Shader,
        maxSampleOffset: CGSize = .zero,
        isEnabled: Bool = true
    ) {
        self.makeShader = makeShader
        self.maxSampleOffset = maxSampleOffset
        self.isEnabled = isEnabled
    }

    public func body(content: Content) -> some View {
        content.layerEffect(
            makeShader(),
            maxSampleOffset: maxSampleOffset,
            isEnabled: isEnabled
        )
    }
}
