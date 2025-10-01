//
//  MetallicBackground.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/30/25.
//

import SwiftUI
#if os(iOS)
import CoreMotion
#endif

/// A convenience view that applies metallic effect to text
/// For general use, prefer the `.metalEffect()` modifier on any view
public struct MetallicBackground: View {
    public let text: String
    public let matcapImage: String
    public let font: Font
    @Binding public var viewDirection: SIMD3<Float>
    public let mixAmount: CGFloat
    public let edgeStrength: CGFloat
    public let useMotion: Bool
    
    public init(
        text: String = "GOLD",
        matcapImage: String = "BumpyGold",
        font: Font = .system(size: 120, weight: .black),
        viewDirection: Binding<SIMD3<Float>> = .constant(SIMD3<Float>(0, 0, 1)),
        mixAmount: CGFloat = 0.9,
        edgeStrength: CGFloat = 8.0,
        useMotion: Bool = false
    ) {
        self.text = text
        self.matcapImage = matcapImage
        self.font = font
        self._viewDirection = viewDirection
        self.mixAmount = mixAmount
        self.edgeStrength = edgeStrength
        self.useMotion = useMotion
    }
    
    public var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(.white)
            .metalEffect(
                matcap: Image(matcapImage, bundle: .module),
                viewDirection: $viewDirection,
                mixAmount: mixAmount,
                edgeStrength: edgeStrength,
                useMotion: useMotion
            )
    }
}

// MARK: - ShaderEffect Protocol Conformance
extension MetallicBackground: ShaderEffect {
    public static var effectName: String { "Metallic" }
    public static var effectDescription: String { "Metallic text effect using matcap textures" }
    public static var effectCategory: String { "Effects" }
}
