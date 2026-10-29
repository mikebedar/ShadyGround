//
//  MetalMaterial.swift
//  ShadyGround
//
//  Metal finishes as a MetalSurfaceRenderer: brushed aluminium, polished steel,
//  anodised aluminium, copper patina, titanium, gold and silver. Ported from the
//  2025-09 MTKView branch onto Core/MetalSurface.swift.
//

import SwiftUI
import Metal
import simd

// MARK: - Material

/// How a metal's surface was worked: what its height field looks like.
public enum MetalFinish: Int, Sendable, Hashable, CaseIterable {
    /// Nearly flat; a sharp highlight and a mirror-like gradient.
    case polished = 0
    /// Fine streaks along the horizontal axis, so the highlight stretches across them.
    case brushed = 1
    /// Bead-blasted grain: a soft, even sheen.
    case satin = 2
    /// Blotches of verdigris (a rough, non-metallic oxide) over pitted metal.
    case patina = 3
}

/// A metal: its colour, how rough and how metallic it is, and its finish.
public struct MetalMaterial: Sendable, Hashable {
    /// Display name.
    public var name: String
    /// Albedo (metals) or diffuse colour, sRGB-encoded, 0–1.
    public var baseColor: SIMD3<Float>
    /// 0 is a mirror, 1 is fully diffuse.
    public var roughness: Float
    /// 0 is a dielectric, 1 is a pure metal.
    public var metallic: Float
    /// Overall darkening, 0–1.
    public var ambientOcclusion: Float
    public var finish: MetalFinish
    /// Size of the finish's features in points: streak spacing for brushed, grain for satin.
    public var featureSize: Float

    public init(name: String = "Custom", baseColor: SIMD3<Float>, roughness: Float, metallic: Float,
                ambientOcclusion: Float = 1, finish: MetalFinish = .polished, featureSize: Float = 1) {
        self.name = name
        self.baseColor = baseColor
        self.roughness = roughness
        self.metallic = metallic
        self.ambientOcclusion = ambientOcclusion
        self.finish = finish
        self.featureSize = featureSize
    }
}

public extension MetalMaterial {
    static let brushedAluminum = MetalMaterial(name: "Brushed Aluminium", baseColor: [0.91, 0.92, 0.92],
                                               roughness: 0.35, metallic: 1, ambientOcclusion: 0.9, finish: .brushed)
    static let polishedSteel = MetalMaterial(name: "Polished Steel", baseColor: [0.77, 0.78, 0.78],
                                             roughness: 0.12, metallic: 1, finish: .polished)
    static let anodizedAluminum = MetalMaterial(name: "Anodised Aluminium", baseColor: [0.20, 0.40, 0.80],
                                                roughness: 0.4, metallic: 0.8, ambientOcclusion: 0.9, finish: .satin)
    static let copperPatina = MetalMaterial(name: "Copper Patina", baseColor: [0.95, 0.64, 0.54],
                                            roughness: 0.3, metallic: 1, ambientOcclusion: 0.85, finish: .patina)
    static let titanium = MetalMaterial(name: "Titanium", baseColor: [0.54, 0.50, 0.47],
                                        roughness: 0.5, metallic: 1, ambientOcclusion: 0.85, finish: .satin)
    static let gold = MetalMaterial(name: "Gold", baseColor: [1.0, 0.77, 0.34],
                                    roughness: 0.2, metallic: 1, finish: .polished)
    static let silver = MetalMaterial(name: "Silver", baseColor: [0.97, 0.96, 0.92],
                                      roughness: 0.15, metallic: 1, finish: .polished)

    /// Every built-in material, in display order.
    static let presets: [MetalMaterial] = [
        .brushedAluminum, .polishedSteel, .anodizedAluminum, .copperPatina, .titanium, .gold, .silver,
    ]
}

// MARK: - Scene

/// What ``MetalMaterialRenderer`` draws.
public struct MetalMaterialScene: Equatable, Sendable {
    public var material: MetalMaterial
    /// Direction toward the light: x right, y up, z toward the viewer. Normalised by the shader.
    public var lightDirection: SIMD3<Float>
    public var lightIntensity: Float
    /// Diffuse fill, 0–1.
    public var ambientLight: Float

    public init(material: MetalMaterial = .brushedAluminum, lightDirection: SIMD3<Float> = MetalMaterialScene.defaultLight,
                lightIntensity: Float = 1, ambientLight: Float = 0.1) {
        self.material = material
        self.lightDirection = lightDirection
        self.lightIntensity = lightIntensity
        self.ambientLight = ambientLight
    }

    /// Up and to the left of the viewer.
    public static let defaultLight: SIMD3<Float> = [-0.35, 0.45, 0.8]
}

// MARK: - Renderer

/// GPU struct mirrored in MetalMaterial.metal.
struct MetalMaterialUniforms {
    var baseColor: SIMD4<Float>
    var surface: SIMD4<Float>
    var light: SIMD4<Float>
    var frame: SIMD4<Float>
    var extra: SIMD4<Float>

    init(scene: MetalMaterialScene, context: MetalFrameContext) {
        let m = scene.material
        let size = context.pointSize
        baseColor = SIMD4(m.baseColor, m.ambientOcclusion)
        surface = SIMD4(m.roughness, m.metallic, Float(m.finish.rawValue), m.featureSize)
        let dir = simd_length(scene.lightDirection) > 0 ? scene.lightDirection : MetalMaterialScene.defaultLight
        light = SIMD4(dir, scene.lightIntensity)
        frame = SIMD4(Float(size.width), Float(size.height), Float(context.scale), Float(context.time))
        extra = SIMD4(scene.ambientLight, 0, 0, 0)
    }
}

/// Draws a ``MetalMaterial`` as one full-screen triangle. Host it with
/// ``MetalSurfaceView`` (or use ``MetalMaterialSurface``) or render it offscreen with
/// ``MetalOffscreenTarget``. Time above zero sways the light, so the highlight moves.
@MainActor
public final class MetalMaterialRenderer: MetalSurfaceRenderer {
    public typealias Scene = MetalMaterialScene

    public let device: MTLDevice
    public let colorPixelFormat: MTLPixelFormat = .bgra8Unorm
    private let pipeline: MTLRenderPipelineState

    public init(device: MTLDevice) throws {
        self.device = device
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Metal material"
        desc.vertexFunction = try ShadyGroundMetalLibrary.function("metalMaterialVertex", device: device)
        desc.fragmentFunction = try ShadyGroundMetalLibrary.function("metalMaterialFragment", device: device)
        desc.colorAttachments[0].pixelFormat = colorPixelFormat
        pipeline = try device.makeRenderPipelineState(descriptor: desc)
    }

    public func encode(_ scene: MetalMaterialScene, context: MetalFrameContext, commandBuffer: MTLCommandBuffer,
                       pass: MTLRenderPassDescriptor) {
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        encoder.label = "Metal material"
        encoder.setRenderPipelineState(pipeline)
        var uniforms = MetalMaterialUniforms(scene: scene, context: context)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<MetalMaterialUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}

// MARK: - View

/// A metal surface as a decorative fill.
///
/// ```swift
/// MetalMaterialSurface(.gold)
///     .frame(height: 200)
///     .clipShape(.rect(cornerRadius: 16))
/// ```
///
/// The surface is hidden from accessibility and takes no hit tests. It draws once and
/// redraws only when its inputs change; with `isAnimating` (and Reduce Motion off) the
/// light sways at 30 fps so the highlight moves. Drive `lightDirection` yourself to follow
/// a pointer or the device's tilt.
public struct MetalMaterialSurface: View {
    public var material: MetalMaterial
    public var lightDirection: SIMD3<Float>
    public var lightIntensity: Float
    public var ambientLight: Float
    public var isAnimating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ material: MetalMaterial = .brushedAluminum, lightDirection: SIMD3<Float> = MetalMaterialScene.defaultLight,
                lightIntensity: Float = 1, ambientLight: Float = 0.1, isAnimating: Bool = false) {
        self.material = material
        self.lightDirection = lightDirection
        self.lightIntensity = lightIntensity
        self.ambientLight = ambientLight
        self.isAnimating = isAnimating
    }

    public var body: some View {
        MetalSurfaceView(
            MetalMaterialRenderer.self,
            scene: MetalMaterialScene(material: material, lightDirection: lightDirection,
                                      lightIntensity: lightIntensity, ambientLight: ambientLight),
            isAnimated: isAnimating && !reduceMotion,
            preferredFramesPerSecond: 30
        )
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
