//
//  GrassMetalView.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/9/25.
//
//  Turf drawn entirely in Metal: the shared turf shader as a full-screen ground
//  pass, with instanced blade geometry over the near field in the same render pass.
//

import SwiftUI
import Metal
import simd

// MARK: - Scene

/// A control-map image compared by identity, so scenes stay `Equatable`.
public struct GrassControlImage: Equatable, @unchecked Sendable {
    public var image: CGImage?
    public init(_ image: CGImage?) { self.image = image }
    public static func == (a: GrassControlImage, b: GrassControlImage) -> Bool { a.image === b.image }
}

/// What ``GrassMetalRenderer`` draws.
public struct GrassMetalScene: Equatable {
    public var style: GrassStyle
    public var camera: GrassCamera
    public var ground: GrassGround
    public var atmosphere: GrassAtmosphere
    /// Distance in ground units over which blade geometry is drawn. `nil` draws no blades.
    public var bladeRange: Double?
    public var bladeCount: Int
    /// The control map, covering the view like ``GrassView``'s content. `nil` is uniform turf.
    public var control: GrassControlImage
    public var bladeOptions: GrassInstancedOptions?

    public init(style: GrassStyle = .lawn, camera: GrassCamera, ground: GrassGround, atmosphere: GrassAtmosphere = .none,
                bladeRange: Double? = nil, bladeCount: Int = 300_000, control: GrassControlImage = .init(nil),
                bladeOptions: GrassInstancedOptions? = nil) {
        self.style = style
        self.camera = camera
        self.ground = ground
        self.atmosphere = atmosphere
        self.bladeRange = bladeRange
        self.bladeCount = bladeCount
        self.control = control
        self.bladeOptions = bladeOptions
    }
}

// MARK: - Renderer

/// GPU structs mirrored in GrassInstanced.metal.
struct GrassColorsGPU {
    var base = SIMD4<Float>()
    var tip = SIMD4<Float>()
    var dry = SIMD4<Float>()
    var soil = SIMD4<Float>()
    var sheen = SIMD4<Float>()
    var fog = SIMD4<Float>()
}

struct GrassGroundParamsGPU {
    var pixelScale: Float = 1
    var mapW: Float = 1
    var mapH: Float = 1
    var uCount: Int32 = 0
}

/// Draws turf with the shared shader as a ground pass and instanced blades on top.
@MainActor
public final class GrassMetalRenderer: MetalSurfaceRenderer {
    public typealias Scene = GrassMetalScene

    public let device: MTLDevice
    public let colorPixelFormat: MTLPixelFormat = .rgba8Unorm
    public var depthPixelFormat: MTLPixelFormat { GrassInstancedRenderer.depthPixelFormat }
    public let sampleCount: Int = 4

    private let groundPipeline: MTLRenderPipelineState
    private let groundDepth: MTLDepthStencilState
    private let blades: GrassInstancedRenderer
    private let controlTexture: MetalImageTexture
    private let placeholder: MTLTexture?

    /// Blade statistics from the last frame.
    public var bladeStats: GrassInstancedRenderer.Stats { blades.stats }

    public init(device: MTLDevice) throws {
        self.device = device
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Grass ground (shared shader)"
        desc.vertexFunction = try ShadyGroundMetalLibrary.function("grassInstancedGroundVertex", device: device)
        desc.fragmentFunction = try ShadyGroundMetalLibrary.function("grassMetalGroundFragment", device: device)
        desc.colorAttachments[0].pixelFormat = colorPixelFormat
        desc.depthAttachmentPixelFormat = GrassInstancedRenderer.depthPixelFormat
        desc.rasterSampleCount = sampleCount
        groundPipeline = try device.makeRenderPipelineState(descriptor: desc)

        let dd = MTLDepthStencilDescriptor()
        dd.depthCompareFunction = .always
        dd.isDepthWriteEnabled = false
        groundDepth = device.makeDepthStencilState(descriptor: dd)!

        blades = try GrassInstancedRenderer(device: device, colorPixelFormat: colorPixelFormat, sampleCount: sampleCount)
        controlTexture = MetalImageTexture(device: device)
        placeholder = MetalImageTexture.solid(SIMD4(128, 128, UInt8(GrassControl.defaultHeight * 255), 255), device: device)
    }

    public func encode(_ scene: GrassMetalScene, context: MetalFrameContext, commandBuffer: MTLCommandBuffer, pass: MTLRenderPassDescriptor) {
        let size = context.pointSize
        let texture = controlTexture.update(with: scene.control.image) ?? placeholder
        guard let texture else { return }

        // Blade plan first: the ground pass needs this frame's blade density.
        var bladeScene: GrassInstancedScene?
        if let range = scene.bladeRange, scene.bladeCount > 0, !scene.camera.isTopDown {
            blades.setControlTexture(texture)
            var options = scene.bladeOptions ?? .nearField(range: range)
            options.drawGround = false
            if options.maxDistance == nil { options.maxDistance = range }
            if options.fadeDistance == nil { options.fadeDistance = range * 0.5 }
            let bs = GrassInstancedScene(style: scene.style, camera: scene.camera, ground: scene.ground,
                                         atmosphere: scene.atmosphere, mapSize: size, bladeCount: scene.bladeCount,
                                         time: context.time, options: options)
            _ = blades.plan(bs, drawableSize: context.drawableSize)
            bladeScene = bs
        }

        // Ground: the shared turf shader. Shells off when blades cover the near field.
        var style = scene.style
        if scene.bladeRange != nil { style.shellCount = 0 }
        var u = GrassUniform.pack(style: style, camera: scene.camera, ground: scene.ground, atmosphere: scene.atmosphere,
                                  size: size, time: context.time, pixelScale: Double(context.scale))
        if let range = scene.bladeRange, scene.bladeCount > 0, !scene.camera.isTopDown {
            let cm = scene.ground.unit.centimetres
            let bladeOptions = scene.bladeOptions ?? .nearField(range: range)
            var fadeStart = (bladeOptions.fadeDistance ?? range * 0.5) * cm
            var fadeEnd = range * cm
            // The blades also thin out by sparsity, usually sooner than by distance;
            // the interior darkening must follow whichever fade comes first.
            if let sparse = bladeOptions.sparsityFadeRange(bladeWidth: scene.style.bladeWidth,
                                                           cellsPerOctave: blades.stats.cellsPerOctave) {
                fadeStart = min(fadeStart, sparse.lowerBound)
                fadeEnd = min(fadeEnd, max(sparse.upperBound, fadeStart + 1))
            }
            u[GrassUniform.nearInterior] = Float(scene.style.canopyInterior)
            u[GrassUniform.nearFadeStart] = Float(fadeStart)
            u[GrassUniform.nearFadeEnd] = Float(fadeEnd)
            // Distance (cm) to which the blade lattice stays at canopy density.
            let latticeNatural = max(scene.style.bladeWidth * 1.2, 0.1)
            u[GrassUniform.nearDense] = Float(blades.stats.cellsPerOctave * latticeNatural)
        }
        var colors = GrassColorsGPU()
        colors.base = Self.premultiplied(style.baseColor)
        colors.tip = Self.premultiplied(style.tipColor)
        colors.dry = Self.premultiplied(style.dryColor)
        colors.soil = Self.premultiplied(style.soilColor)
        colors.sheen = Self.premultiplied(style.sheenColor)
        colors.fog = Self.premultiplied(scene.atmosphere.fogColor)
        var params = GrassGroundParamsGPU(pixelScale: Float(context.scale), mapW: Float(size.width), mapH: Float(size.height),
                                          uCount: Int32(u.count))

        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        enc.label = "Grass (Metal)"
        enc.setRenderPipelineState(groundPipeline)
        enc.setDepthStencilState(groundDepth)
        u.withUnsafeMutableBytes { buf in
            enc.setFragmentBytes(buf.baseAddress!, length: buf.count, index: 0)
        }
        enc.setFragmentBytes(&colors, length: MemoryLayout<GrassColorsGPU>.stride, index: 1)
        enc.setFragmentBytes(&params, length: MemoryLayout<GrassGroundParamsGPU>.stride, index: 2)
        enc.setFragmentTexture(texture, index: 0)
        enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

        // Blades over the near field.
        if let bladeScene {
            blades.encodeBlades(bladeScene, encoder: enc, drawableSize: context.drawableSize)
        }
        enc.endEncoding()
    }

    /// sRGB-encoded, premultiplied, as SwiftUI hands `.color()` arguments to a shader.
    static func premultiplied(_ color: Color) -> SIMD4<Float> {
        let r = color.resolve(in: EnvironmentValues())
        return SIMD4(r.red * r.opacity, r.green * r.opacity, r.blue * r.opacity, r.opacity)
    }
}

// MARK: - View

/// Where ``GrassMetalView`` gets its control map.
public enum GrassControlSource {
    /// A pre-authored image covering the view.
    case image(CGImage?)
    /// A live simulation, uploaded whenever it steps. The simulation's extent must cover
    /// the whole map; its image is stretched to the view.
    case simulation(GrassTurfSimulation)
    /// A SwiftUI view rendered to an image when the size or `refresh` changes.
    case view(AnyView, refresh: Int = 0)
}

/// Turf rendered in one Metal pass: the shared turf shader as the ground, and
/// instanced blade geometry over the first `bladeRange` ground units.
///
/// The map comes from a ``GrassControlSource``. Pixels above the horizon are
/// transparent, so a backdrop can sit behind the view.
public struct GrassMetalView: View {
    public var style: GrassStyle
    public var camera: GrassCamera
    public var ground: GrassGround
    public var atmosphere: GrassAtmosphere
    public var bladeRange: Double?
    public var bladeCount: Int
    public var control: GrassControlSource

    @State private var renderedControl: CGImage?
    @Environment(\.displayScale) private var displayScale

    public init(style: GrassStyle = .lawn, camera: GrassCamera, ground: GrassGround, atmosphere: GrassAtmosphere = .none,
                bladeRange: Double? = nil, bladeCount: Int = 300_000, control: GrassControlSource) {
        self.style = style
        self.camera = camera
        self.ground = ground
        self.atmosphere = atmosphere
        self.bladeRange = bladeRange
        self.bladeCount = bladeCount
        self.control = control
    }

    public var body: some View {
        GeometryReader { geo in
            switch control {
            case .image(let image):
                surface(image)
            case .simulation(let simulation):
                TimelineView(.animation) { context in
                    surface(simulation.image)
                        .onChange(of: context.date, initial: true) { _, date in simulation.advance(to: date) }
                }
            case .view(let view, let refresh):
                surface(renderedControl)
                    .task(id: ViewKey(size: geo.size, refresh: refresh)) {
                        renderedControl = render(view, size: geo.size)
                    }
            }
        }
    }

    private struct ViewKey: Equatable {
        var size: CGSize
        var refresh: Int
    }

    private func surface(_ image: CGImage?) -> some View {
        MetalSurfaceView(
            GrassMetalRenderer.self,
            scene: GrassMetalScene(style: style, camera: camera, ground: ground, atmosphere: atmosphere,
                                   bladeRange: bladeRange, bladeCount: bladeCount, control: GrassControlImage(image)),
            isAnimated: style.isAnimated
        )
    }

    @MainActor
    private func render(_ view: AnyView, size: CGSize) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let renderer = ImageRenderer(content: view.environment(\.grassGround, ground).frame(width: size.width, height: size.height))
        renderer.scale = displayScale
        return renderer.cgImage
    }
}
