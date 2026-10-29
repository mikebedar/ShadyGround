//
//  MetalMaterialPreview.swift
//  ShadyGround
//
//  The metal materials with light controls; the light follows the pointer while it is
//  over the surface (on iOS, drag). Replaces the MTKView branch's SurfaceDemo,
//  MetalSurfaceDemo and SimpleMetalTest.
//

import SwiftUI
import simd

@MainActor
public struct MetalMaterialPreview: View {
    @State private var material: MetalMaterial = .brushedAluminum
    @State private var azimuth: Double = 130          // degrees, 0 = right, 90 = up
    @State private var elevation: Double = 55         // degrees above the surface
    @State private var lightIntensity: Double = 1
    @State private var ambientLight: Double = 0.1
    @State private var isAnimating = false
    @State private var pointerLight: SIMD3<Float>?

    public init() {}

    private var lightDirection: SIMD3<Float> {
        if let pointerLight { return pointerLight }
        let az = azimuth * .pi / 180, el = elevation * .pi / 180
        return SIMD3(Float(cos(az) * cos(el)), Float(sin(az) * cos(el)), Float(sin(el)))
    }

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                MetalMaterialSurface(material, lightDirection: lightDirection, lightIntensity: Float(lightIntensity),
                                     ambientLight: Float(ambientLight), isAnimating: isAnimating)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
#if os(macOS)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let p): pointerLight = Self.light(at: p, in: geo.size, elevation: elevation)
                        case .ended: pointerLight = nil
                        }
                    }
#else
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { pointerLight = Self.light(at: $0.location, in: geo.size, elevation: elevation) }
                        .onEnded { _ in pointerLight = nil })
#endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            VStack(spacing: 16) {
                Picker("Material", selection: $material) {
                    ForEach(MetalMaterial.presets, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.menu)

                ParameterControlGrid {
                    NumericParameterControl(title: "Light Azimuth (°)", value: $azimuth, in: 0...360, step: 5)
                    NumericParameterControl(title: "Light Elevation (°)", value: $elevation, in: 10...90, step: 5)
                    NumericParameterControl(title: "Light Intensity", value: $lightIntensity, in: 0...3, step: 0.1)
                    NumericParameterControl(title: "Ambient Light", value: $ambientLight, in: 0...1, step: 0.05)
                }
                Toggle("Sway the light (isAnimating)", isOn: $isAnimating)

                // Every preset at once.
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                    ForEach(MetalMaterial.presets, id: \.self) { preset in
                        VStack(spacing: 4) {
                            MetalMaterialSurface(preset, lightDirection: lightDirection)
                                .frame(height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(preset.name).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
    }

    /// A light above the point under the pointer.
    private static func light(at p: CGPoint, in size: CGSize, elevation: Double) -> SIMD3<Float> {
        let x = Float(p.x / max(size.width, 1) * 2 - 1)
        let y = Float(1 - p.y / max(size.height, 1) * 2)
        let z = Float(tan(elevation * .pi / 180)) * 0.6
        return simd_normalize(SIMD3(x * 0.6, y * 0.6, max(z, 0.2)))
    }
}

#Preview("Metal Materials") {
    MetalMaterialPreview()
        .frame(width: 700, height: 700)
}
