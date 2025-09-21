//
//  SizeAwareShaderModifier.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//

import SwiftUI

public extension View {
    /// Applies a shader that adapts to the view's current size.
    ///
    /// Use this when your Metal shader needs the view’s size (e.g., “N cells across,”
    /// centered gradients, radial effects). The modifier measures the view using
    /// `onGeometryChange` and reconfigures the shader whenever the size changes.
    ///
    /// Example:
    /// ```swift
    /// SomeView()
    ///   .shadyLayerEffect { size in
    ///       ShaderLibrary.gridByCount(
    ///           .float2(Float(size.width), Float(size.height)),
    ///           .float(24),                // cellsAcross
    ///           .float(1.0),               // lineWidthPx
    ///           .color(.black), .color(.white)
    ///       )
    ///   }
    /// ```
    ///
    /// - Parameter makeShader: A closure that receives the current `CGSize` of the view
    ///   and returns a configured `Shader` for that size.
    /// - Returns: A view with a size-aware shader applied.
    @inlinable
    func shadyLayerEffect(_ makeShader: @escaping (_ size: CGSize) -> Shader) -> some View {
        modifier(SizeAwareShaderModifier(makeShader: makeShader))
    }
}

// MARK: - Implementation

public struct SizeAwareShaderModifier: ViewModifier {
    /// A closure that receives the current size of the view
    /// and produces a `Shader` configured for that size.
    let makeShader: (_ size: CGSize) -> Shader

    /// The current size of the view, updated whenever
    /// geometry changes are observed.
    @State private var size: CGSize = .zero

    /// Public initializer so it can be referenced from `@inlinable` call sites.
    public init(makeShader: @escaping (_ size: CGSize) -> Shader) {
        self.makeShader = makeShader
    }

    /// Builds the modified content view, attaching a geometry
    /// change listener and re-applying the shader whenever
    /// the size changes.
    public func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { geo in
                geo.frame(in: .local)
            } action: { rect in
                size = rect.size
            }
            .layerEffect(makeShader(size), maxSampleOffset: .zero)
    }
}
