//
//  GrassInstancedRenderer.swift
//  ShadyGround
//
//  Experimental real-geometry grass renderer: instanced, Bezier-bent blades drawn
//  with Metal, driven by the same control map, camera and ground mapping as
//  GrassView, so the two can be compared frame for frame.
//
//  Blade placement. A camera at grass height sees from a few centimetres to the
//  horizon, so a uniform grid cannot cover the view with any sane blade count.
//  Instead the visible ground is split into LOD rings by forward distance from the
//  eye: ring k spans [F0 * 2^k, F0 * 2^(k+1)) and is a lattice aligned with the
//  camera heading whose cell size grows with the ring (constant cells per octave).
//  The lattice is anchored in world space, so blades do not swim when the camera
//  translates. Within a ring the vertex shader thins blades by (F_k / f)^2 so the
//  density falls off continuously and matches the next ring at the boundary.
//  Blades widen with spacing to keep the canopy closed in the distance.
//
//  Everything per blade happens in the vertex shader from the instance id (no compute
//  pass): ring lookup, jitter, culling (band, density, frustum, coverage), control
//  sampling, bending, wind. Culled blades are degenerated.
//

import Metal
import SwiftUI
import simd
import CoreGraphics

// MARK: - Options

/// Tuning for ``GrassInstancedRenderer`` that has no equivalent in ``GrassStyle``.
public struct GrassInstancedOptions: Equatable, Sendable {
    /// Lean added by wind gusts at full strength (in lean units, like the control map).
    public var windStrength: Double
    /// Per-blade oscillation on top of the gusts, 0...1.
    public var windSway: Double
    /// Minimum blade width as a fraction of the local blade spacing. Keeps the canopy
    /// closed in the distance, where blades are sparse.
    public var widthGrowth: Double
    /// Minimum blade width in pixels. Thinner blades alias even with MSAA.
    public var minPixelWidth: Double
    /// How far blades are drawn, in ground units. Beyond this the ground pass shades
    /// the canopy as a flat colour. `nil` picks 120 m.
    public var maxDistance: Double?
    /// Multiplier for ``GrassStyle/bladeHeight``.
    public var heightMultiplier: Double
    /// Draws the full-screen ground pass under the blades. Turn off when another
    /// view, such as ``GrassView``, supplies the ground.
    public var drawGround: Bool
    /// Distance in ground units at which blades start fading out toward ``maxDistance``.
    /// `nil` draws them at full opacity to the end.
    public var fadeDistance: Double?
    /// Brightness multiplier on the blade layer relative to the far field. 1 matches it.
    public var gain: Double = 1
    /// Blades fade out once their spacing exceeds this many natural turf spacings
    /// (2.5 blade widths), where geometry can no longer stand in for the texture.
    /// 0 disables the sparsity fade.
    public var sparsityFade: Double = 0

    public init(windStrength: Double = 0.15, windSway: Double = 0.3, widthGrowth: Double = 0.45,
                minPixelWidth: Double = 0.75, maxDistance: Double? = nil, heightMultiplier: Double = 1,
                drawGround: Bool = true, fadeDistance: Double? = nil) {
        self.windStrength = windStrength
        self.windSway = windSway
        self.widthGrowth = widthGrowth
        self.minPixelWidth = minPixelWidth
        self.maxDistance = maxDistance
        self.heightMultiplier = heightMultiplier
        self.drawGround = drawGround
        self.fadeDistance = fadeDistance
    }

    /// Forward distances (cm) over which the sparsity fade removes blades, given the
    /// lattice density; `nil` when the fade is off.
    func sparsityFadeRange(bladeWidth: Double, cellsPerOctave: Double) -> ClosedRange<Double>? {
        guard sparsityFade > 0, cellsPerOctave > 0 else { return nil }
        let natural = max(bladeWidth * 2.5, 0.1)
        let start = 0.35 * sparsityFade * natural * cellsPerOctave
        let end = sparsityFade * natural * cellsPerOctave
        return start...end
    }

    /// Settings for the near-field layer of ``GrassHybridView``: no ground pass,
    /// blades to `range` ground units, fading over the last 40%.
    public static func nearField(range: Double) -> GrassInstancedOptions {
        // Wind follows the style here, so a still style stays still.
        var o = GrassInstancedOptions(windStrength: 0, widthGrowth: 0, maxDistance: range, drawGround: false, fadeDistance: range * 0.5)
        o.sparsityFade = 3.5
        return o
    }
}

/// Everything needed to draw one frame.
public struct GrassInstancedScene: Equatable, Sendable {
    public var style: GrassStyle
    public var camera: GrassCamera
    public var ground: GrassGround
    public var atmosphere: GrassAtmosphere
    /// Size of the control map in points. Like ``GrassView``, the control map covers
    /// the view, so this is normally the view's size.
    public var mapSize: CGSize
    /// Instance budget. Some instances are culled (outside the band, frustum or coverage).
    public var bladeCount: Int
    /// Seconds, drives the wind.
    public var time: Double
    public var options: GrassInstancedOptions

    public init(style: GrassStyle = .lawn, camera: GrassCamera, ground: GrassGround, atmosphere: GrassAtmosphere = .none,
                mapSize: CGSize, bladeCount: Int = 300_000, time: Double = 0, options: GrassInstancedOptions = .init()) {
        self.style = style
        self.camera = camera
        self.ground = ground
        self.atmosphere = atmosphere
        self.mapSize = mapSize
        self.bladeCount = bladeCount
        self.time = time
        self.options = options
    }
}

// MARK: - GPU structs (mirror of GrassInstanced.metal)

struct GIUniforms {
    var viewProj = simd_float4x4()
    var eye = SIMD4<Float>()
    var camRight = SIMD4<Float>()
    var camUp = SIMD4<Float>()
    var camFwd = SIMD4<Float>()
    var lattice = SIMD4<Float>()
    var map = SIMD4<Float>()
    var mapSize = SIMD4<Float>()
    var blade = SIMD4<Float>()
    var blade2 = SIMD4<Float>()
    var wind = SIMD4<Float>()
    var wind2 = SIMD4<Float>()
    var shade = SIMD4<Float>()
    var light = SIMD4<Float>()
    var atmos = SIMD4<Float>()
    var grade = SIMD4<Float>()
    var viewport = SIMD4<Float>()
    var clip = SIMD4<Float>()
    var baseColor = SIMD4<Float>()
    var tipColor = SIMD4<Float>()
    var dryColor = SIMD4<Float>()
    var soilColor = SIMD4<Float>()
    var sheenColor = SIMD4<Float>()
    var fogColor = SIMD4<Float>()
}

struct GIRing {
    var cells = SIMD4<Int32>()     // first lattice cell u, v; cell count u, v
    var band = SIMD4<Float>()      // enumerated forward lo, hi; nominal near boundary; cell size (cm)
    var start = SIMD4<UInt32>()    // x: first instance id; y: hash key (cell-size index)
    var fade = SIMD4<Float>()      // crossfade half-width at near, far boundary; nominal far boundary; unused
}

// MARK: - Ring planning

struct GrassRingPlan {
    var rings: [GIRing]
    var instanceCount: Int
    var cellsPerOctave: Double
    var nearDistance: Double
    var farDistance: Double

    static let maxRings = 32
    /// Forward-distance ratio between consecutive rings. Within a ring the density cull
    /// keeps (F_k / f)^2 of the cells, so a ratio of sqrt(2) wastes at most half of them.
    /// Cell size doubles per level, so each level-k cell holds a 2x2 block of level
    /// k-1 cells and the hierarchy of chosen blades nests exactly.
    static let growth = 2.0

    /// Plans LOD rings covering the visible ground within `budget` instances.
    /// All lengths in centimetres.
    /// Plans rings for a camera. Cell sizes are fixed in world units (`natural` times
    /// powers of √2) so blades never move or re-hash when the camera does; only ring
    /// boundaries move, and those are crossfaded. `cellsPerOctave` sets density; pass
    /// `nil` to fit the budget, or a sticky value to keep boundaries stable.
    static func make(eye: SIMD3<Double>, heading: Double, pitch: Double, tanY: Double, aspect: Double,
                     budget: Int, maxDistance: Double, bladeMax: Double, natural: Double,
                     cellsPerOctave: Double? = nil) -> GrassRingPlan {
        let tanX = tanY * aspect
        let h = max(eye.z, 0.1)
        let cp = cos(pitch), sp = sin(pitch)
        let fwdH = SIMD2(sin(heading), cos(heading))
        let rightH = SIMD2(cos(heading), -sin(heading))
        let margin = bladeMax * 2
        let base = max(natural, 0.05)

        // Forward distance (along the heading) of the bottom and top rows on the ground.
        var nearF = 0.0
        let zBottom = sp - cp * tanY
        if zBottom < -1e-6 { nearF = h / -zBottom * (cp + sp * tanY) }
        var farF = maxDistance
        let zTop = sp + cp * tanY
        if zTop < -1e-6 { farF = min(maxDistance, h / -zTop * (cp - sp * tanY) + margin) }
        let lo0 = max(nearF - margin, 0)
        let eyeU = eye.x * rightH.x + eye.y * rightH.y
        let eyeV = eye.x * fwdH.x + eye.y * fwdH.y

        func rings(for r: Double) -> ([GIRing], Int) {
            // Ring k spans forward distances [F_k, F_{k+1}), F_k = r * base * 2^k, and
            // enumerates level max(k, 0) of a world-axis-aligned lattice hierarchy whose
            // level-0 cell is `base`. Blades never change identity between rings: a
            // coarse ring draws exactly the blades the finer rings would keep at that
            // density, so there is nothing to cross-fade at ring boundaries.
            let f1 = r * base
            let kLo = Int(floor(log(max(lo0, 1e-3) / f1) / log(growth)))
            let kHi = Int(ceil(log(max(farF, f1) / f1) / log(growth)))
            var out: [GIRing] = []
            var total = 0
            var k = kLo
            while k <= kHi && out.count < maxRings {
                let Fk = f1 * pow(growth, Double(k))
                let Fk1 = f1 * pow(growth, Double(k + 1))
                if Fk1 <= lo0 || Fk >= farF { k += 1; continue }
                let cellIndex = max(k, 0)
                let cell = base * pow(growth, Double(cellIndex))
                let lo = max(Fk, lo0)
                let hi = min(Fk1, farF)
                // World-space bounding box of the band's view trapezoid.
                func lateral(_ F: Double) -> Double { tanX * max(F * cp - h * sp, h) * 1.03 + margin }
                var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
                for (F, lat) in [(lo, lateral(lo)), (hi, lateral(hi))] {
                    for side in [-1.0, 1.0] {
                        let px = eye.x + fwdH.x * F + rightH.x * lat * side
                        let py = eye.y + fwdH.y * F + rightH.y * lat * side
                        minX = min(minX, px); maxX = max(maxX, px); minY = min(minY, py); maxY = max(maxY, py)
                    }
                }
                let iu0 = Int(floor((minX - margin) / cell)), iv0 = Int(floor((minY - margin) / cell))
                let nu = Int(ceil((maxX + margin) / cell)) - iu0 + 1
                let nv = Int(ceil((maxY + margin) / cell)) - iv0 + 1
                var ring = GIRing()
                ring.cells = SIMD4(Int32(clamping: iu0), Int32(clamping: iv0), Int32(clamping: nu), Int32(clamping: nv))
                ring.band = SIMD4(Float(lo), Float(hi), Float(Fk), Float(cell))
                ring.start = SIMD4(UInt32(clamping: total), UInt32(clamping: cellIndex), 0, 0)
                ring.fade = SIMD4(0, 0, Float(Fk1), 0)
                out.append(ring)
                total += nu * nv
                k += 1
            }
            return (out, total)
        }

        var r = cellsPerOctave ?? 0
        if r <= 0 {
            // Largest cells-per-octave that fits the budget.
            var lo = 1.0, hi = 4096.0
            for _ in 0..<40 {
                let mid = (lo * hi).squareRoot()
                if rings(for: mid).1 <= budget { lo = mid } else { hi = mid }
            }
            r = lo
        }
        let (planned, total) = rings(for: r)
        return GrassRingPlan(rings: planned, instanceCount: total, cellsPerOctave: r, nearDistance: lo0, farDistance: farF)
    }
}

// MARK: - Renderer

/// Draws instanced grass blades into any Metal render target.
///
/// Use ``render(_:into:commandBuffer:)`` to draw offscreen into a texture (the renderer
/// owns the multisample and depth buffers), or ``encode(_:commandBuffer:pass:drawableSize:)``
/// with a pass descriptor from an `MTKView` whose `sampleCount` and
/// `depthStencilPixelFormat` match the renderer's.
@MainActor
public final class GrassInstancedRenderer {
    public let device: MTLDevice
    public let colorPixelFormat: MTLPixelFormat
    public let sampleCount: Int
    public static let depthPixelFormat: MTLPixelFormat = .depth32Float

    /// Statistics of the most recent frame. `drawnBlades` is read back from the GPU
    /// and is only valid once that frame's command buffer has completed.
    public struct Stats: Sendable {
        public var instances: Int = 0
        public var rings: Int = 0
        public var cellsPerOctave: Double = 0
        public var farDistanceCm: Double = 0
        public var drawnBlades: Int = 0
    }

    private let queue: MTLCommandQueue
    private let bladePipeline: MTLRenderPipelineState
    private let groundPipeline: MTLRenderPipelineState
    private let bladeDepth: MTLDepthStencilState
    private let groundDepth: MTLDepthStencilState
    private let statsBuffer: MTLBuffer
    private var controlTexture: MTLTexture
    private var controlImage: CGImage?
    /// Cells per octave from the last budget fit. Kept between frames so moving the
    /// camera never rescales the blade lattice; refitted only when the count drifts.
    private var stickyCellsPerOctave: Double?
    private var stickyBudget = 0
    private var msaaTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var plannedStats = Stats()

    public var stats: Stats {
        var s = plannedStats
        s.drawnBlades = Int(statsBuffer.contents().load(as: UInt32.self))
        return s
    }

    public var commandQueue: MTLCommandQueue { queue }

    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice(), colorPixelFormat: MTLPixelFormat = .bgra8Unorm, sampleCount: Int = 4) throws {
        guard let device else { throw RendererError.noDevice }
        self.device = device
        self.colorPixelFormat = colorPixelFormat
        self.sampleCount = sampleCount
        guard let queue = device.makeCommandQueue() else { throw RendererError.noDevice }
        self.queue = queue

        let library = try device.makeDefaultLibrary(bundle: .module)
        func function(_ name: String) throws -> MTLFunction {
            guard let f = library.makeFunction(name: name) else { throw RendererError.missingFunction(name) }
            return f
        }

        let blade = MTLRenderPipelineDescriptor()
        blade.label = "Grass blades"
        blade.vertexFunction = try function("grassInstancedBladeVertex")
        blade.fragmentFunction = try function("grassInstancedBladeFragment")
        blade.colorAttachments[0].pixelFormat = colorPixelFormat
        blade.depthAttachmentPixelFormat = Self.depthPixelFormat
        blade.rasterSampleCount = sampleCount
        // Alpha becomes MSAA sample coverage rather than a blend: a fading blade then
        // neither hides the opaque blades behind it through the depth test nor dims
        // the crossfade bands between lattice rings. Falls back to blending without MSAA.
        // Premultiplied alpha blend. (Alpha-to-coverage was tried: with 4 samples its
        // dither is coarse enough to add both banding and temporal noise.)
        let ca = blade.colorAttachments[0]!
        ca.isBlendingEnabled = true
        ca.sourceRGBBlendFactor = .one
        ca.sourceAlphaBlendFactor = .one
        ca.destinationRGBBlendFactor = .oneMinusSourceAlpha
        ca.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        bladePipeline = try device.makeRenderPipelineState(descriptor: blade)

        let ground = MTLRenderPipelineDescriptor()
        ground.label = "Grass ground"
        ground.vertexFunction = try function("grassInstancedGroundVertex")
        ground.fragmentFunction = try function("grassInstancedGroundFragment")
        ground.colorAttachments[0].pixelFormat = colorPixelFormat
        ground.depthAttachmentPixelFormat = Self.depthPixelFormat
        ground.rasterSampleCount = sampleCount
        groundPipeline = try device.makeRenderPipelineState(descriptor: ground)

        let bd = MTLDepthStencilDescriptor()
        bd.depthCompareFunction = .less
        bd.isDepthWriteEnabled = true
        bladeDepth = device.makeDepthStencilState(descriptor: bd)!
        let gd = MTLDepthStencilDescriptor()
        gd.depthCompareFunction = .always
        gd.isDepthWriteEnabled = false
        groundDepth = device.makeDepthStencilState(descriptor: gd)!

        statsBuffer = device.makeBuffer(length: 16, options: .storageModeShared)!
        controlTexture = try Self.makeTexture(device: device, image: nil)
    }

    public enum RendererError: Error {
        case noDevice
        case missingFunction(String)
        case textureCreation
    }

    // MARK: Control map

    /// Sets the control map. The image must be encoded like ``GrassControl``
    /// (RG lean, B height, A coverage) and cover the scene's `mapSize`. `nil` is
    /// uniform, upright, fully covered turf.
    public func setControlImage(_ image: CGImage?) {
        if image === controlImage, image != nil { return }
        controlImage = image
        if let tex = try? Self.makeTexture(device: device, image: image) { controlTexture = tex }
    }

    /// Uses an existing `.rgba8Unorm` control texture (premultiplied, sRGB-encoded bytes).
    public func setControlTexture(_ texture: MTLTexture) {
        controlImage = nil
        controlTexture = texture
    }

    private static func makeTexture(device: MTLDevice, image: CGImage?) throws -> MTLTexture {
        let w = max(image?.width ?? 1, 1), h = max(image?.height ?? 1, 1)
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        if let image {
            // Premultiplied, sRGB-encoded bytes: the same values SwiftUI hands a layer shader.
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            let ok = bytes.withUnsafeMutableBytes { buf -> Bool in
                guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                          space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
                ctx.setBlendMode(.copy)
                ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
                return true
            }
            if !ok { throw RendererError.textureCreation }
        } else {
            let upright = GrassControl.defaultHeight
            bytes = [128, 128, UInt8(upright * 255), 255]
        }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
        desc.usage = .shaderRead
        guard let tex = device.makeTexture(descriptor: desc) else { throw RendererError.textureCreation }
        bytes.withUnsafeBytes { buf in
            tex.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: buf.baseAddress!, bytesPerRow: w * 4)
        }
        return tex
    }

    // MARK: Drawing

    /// Draws into `texture` (single-sampled, `colorPixelFormat`), resolving from the
    /// renderer's own multisample buffer.
    public func render(_ scene: GrassInstancedScene, into texture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let w = texture.width, h = texture.height
        if depthTexture?.width != w || depthTexture?.height != h {
            #if os(iOS)
            let transient: MTLStorageMode = .memoryless
            #else
            let transient: MTLStorageMode = .private
            #endif
            let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.depthPixelFormat, width: w, height: h, mipmapped: false)
            dd.textureType = sampleCount > 1 ? .type2DMultisample : .type2D
            dd.sampleCount = sampleCount
            dd.usage = .renderTarget
            dd.storageMode = transient
            depthTexture = device.makeTexture(descriptor: dd)
            if sampleCount > 1 {
                let md = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: colorPixelFormat, width: w, height: h, mipmapped: false)
                md.textureType = .type2DMultisample
                md.sampleCount = sampleCount
                md.usage = .renderTarget
                md.storageMode = transient
                msaaTexture = device.makeTexture(descriptor: md)
            } else {
                msaaTexture = nil
            }
        }
        let pass = MTLRenderPassDescriptor()
        if let msaaTexture {
            pass.colorAttachments[0].texture = msaaTexture
            pass.colorAttachments[0].resolveTexture = texture
            pass.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            pass.colorAttachments[0].texture = texture
            pass.colorAttachments[0].storeAction = .store
        }
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.depthAttachment.texture = depthTexture
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        encode(scene, commandBuffer: commandBuffer, pass: pass, drawableSize: CGSize(width: w, height: h))
    }

    /// Encodes the ground and blade passes with a caller-supplied pass descriptor.
    public func encode(_ scene: GrassInstancedScene, commandBuffer: MTLCommandBuffer, pass: MTLRenderPassDescriptor, drawableSize: CGSize) {
        guard let enc = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        enc.label = "Instanced grass"
        if scene.options.drawGround {
            var (u, _) = Self.makeUniforms(scene, drawableSize: drawableSize)
            enc.setRenderPipelineState(groundPipeline)
            enc.setDepthStencilState(groundDepth)
            enc.setFragmentBytes(&u, length: MemoryLayout<GIUniforms>.stride, index: 0)
            enc.setFragmentTexture(controlTexture, index: 0)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        encodeBlades(scene, encoder: enc, drawableSize: drawableSize)
        enc.endEncoding()
    }

    /// Draws only the blades on an encoder whose pass matches this renderer's formats,
    /// so another renderer can draw the ground first. Use ``setControlTexture(_:)`` to
    /// share a control texture with it.
    /// Plans the frame: fits the budget once, then keeps the density while the camera
    /// moves, refitting only when the instance count drifts well outside the budget.
    /// Safe to call before ``encodeBlades(_:encoder:drawableSize:)`` in the same frame.
    func plan(_ scene: GrassInstancedScene, drawableSize: CGSize) -> (GIUniforms, GrassRingPlan) {
        var (uniforms, plan) = Self.makeUniforms(scene, drawableSize: drawableSize, cellsPerOctave: stickyBudget == scene.bladeCount ? stickyCellsPerOctave : nil)
        if stickyCellsPerOctave != nil, stickyBudget == scene.bladeCount,
           plan.instanceCount > Int(Double(scene.bladeCount) * 1.3) || plan.instanceCount < Int(Double(scene.bladeCount) * 0.45) {
            (uniforms, plan) = Self.makeUniforms(scene, drawableSize: drawableSize, cellsPerOctave: nil)
        }
        stickyCellsPerOctave = plan.cellsPerOctave
        stickyBudget = scene.bladeCount
        plannedStats = Stats(instances: plan.instanceCount, rings: plan.rings.count,
                             cellsPerOctave: plan.cellsPerOctave, farDistanceCm: plan.farDistance)
        return (uniforms, plan)
    }

    public func encodeBlades(_ scene: GrassInstancedScene, encoder enc: MTLRenderCommandEncoder, drawableSize: CGSize) {
        let (uniforms, plan) = self.plan(scene, drawableSize: drawableSize)
        plannedStats = Stats(instances: plan.instanceCount, rings: plan.rings.count,
                             cellsPerOctave: plan.cellsPerOctave, farDistanceCm: plan.farDistance)
        statsBuffer.contents().storeBytes(of: UInt32(0), as: UInt32.self)
        guard plan.instanceCount > 0, scene.bladeCount > 0, !scene.camera.isTopDown else { return }
        var u = uniforms
        var rings = plan.rings
        if rings.isEmpty { rings = [GIRing()] }
        enc.setRenderPipelineState(bladePipeline)
        enc.setDepthStencilState(bladeDepth)
        enc.setCullMode(.none)
        enc.setVertexBytes(&u, length: MemoryLayout<GIUniforms>.stride, index: 0)
        enc.setVertexBytes(&rings, length: MemoryLayout<GIRing>.stride * rings.count, index: 1)
        enc.setVertexBuffer(statsBuffer, offset: 0, index: 2)
        var gu = GrassUniform.pack(style: scene.style, camera: scene.camera, ground: scene.ground, atmosphere: scene.atmosphere,
                                   size: scene.mapSize, time: scene.time,
                                   pixelScale: Double(drawableSize.width) / max(Double(scene.mapSize.width), 1))
        gu.withUnsafeMutableBytes { buf in enc.setVertexBytes(buf.baseAddress!, length: buf.count, index: 3) }
        enc.setVertexTexture(controlTexture, index: 0)
        enc.setFragmentBytes(&u, length: MemoryLayout<GIUniforms>.stride, index: 0)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 15, instanceCount: plan.instanceCount)
    }

    // MARK: Uniforms

    static func makeUniforms(_ scene: GrassInstancedScene, drawableSize: CGSize, cellsPerOctave: Double? = nil) -> (GIUniforms, GrassRingPlan) {
        let style = scene.style, camera = scene.camera, ground = scene.ground, atmosphere = scene.atmosphere
        let opts = scene.options
        let cm = ground.unit.centimetres
        let w = max(Double(drawableSize.width), 1), h = max(Double(drawableSize.height), 1)
        let aspect = w / h

        // Camera basis, as in GrassUniform.pack. A top-down camera has no perspective
        // equivalent here; it is approximated by looking straight down from 30 m.
        var eye = camera.eye * cm
        var th = camera.heading.radians
        var ph = camera.pitch.radians
        var fov = camera.fieldOfView.radians
        if camera.isTopDown { eye = SIMD3(0, 0, 3000); th = 0; ph = -.pi / 2 + 1e-3; fov = .pi / 3 }
        let tanY = tan(fov / 2)
        let tanX = tanY * aspect
        let fwdFlat = SIMD3<Double>(sin(th), cos(th), 0)
        let right = SIMD3<Double>(cos(th), -sin(th), 0)
        let up0 = SIMD3<Double>(0, 0, 1)
        let f = cos(ph) * fwdFlat + sin(ph) * up0
        let up = -sin(ph) * fwdFlat + cos(ph) * up0

        let bladeHeight = style.bladeHeight * opts.heightMultiplier
        let bladeMax = bladeHeight * 1.6 * 1.35
        let maxDistance = (opts.maxDistance.map { $0 * cm }) ?? 12_000
        // Canopy spacing: one blade per cell, so cells must be close to blade width
        // for the near field to close up like real turf.
        let natural = max(style.bladeWidth * 1.2, 0.1)
        let plan = GrassRingPlan.make(eye: eye, heading: th, pitch: ph, tanY: tanY, aspect: aspect,
                                      budget: max(scene.bladeCount, 0), maxDistance: maxDistance, bladeMax: bladeMax,
                                      natural: natural, cellsPerOctave: cellsPerOctave)

        // View and projection (right-handed view space, Metal clip z in 0...1).
        let near = max(0.5, min(5, eye.z * 0.05))
        let far = max(plan.farDistance * 1.5 + eye.z * 2, near * 10)
        let view = simd_double4x4(rows: [
            SIMD4(right.x, right.y, right.z, -simd_dot(right, eye)),
            SIMD4(up.x, up.y, up.z, -simd_dot(up, eye)),
            SIMD4(-f.x, -f.y, -f.z, simd_dot(f, eye)),
            SIMD4(0, 0, 0, 1),
        ])
        let proj = simd_double4x4(rows: [
            SIMD4(1 / tanX, 0, 0, 0),
            SIMD4(0, 1 / tanY, 0, 0),
            SIMD4(0, 0, far / (near - far), near * far / (near - far)),
            SIMD4(0, 0, -1, 0),
        ])
        let vp = proj * view

        var u = GIUniforms()
        u.viewProj = simd_float4x4(
            SIMD4<Float>(vp.columns.0), SIMD4<Float>(vp.columns.1), SIMD4<Float>(vp.columns.2), SIMD4<Float>(vp.columns.3))
        u.eye = SIMD4(Float(eye.x), Float(eye.y), Float(eye.z), Float(scene.time))
        u.camRight = SIMD4(SIMD3<Float>(right), Float(tanX))
        u.camUp = SIMD4(SIMD3<Float>(up), Float(tanY))
        u.camFwd = SIMD4(SIMD3<Float>(f), 0)
        u.lattice = SIMD4(Float(cos(th)), Float(sin(th)), Float(plan.cellsPerOctave), Float(plan.farDistance))
        u.wind2.w = Float(opts.sparsityFade)
        u.grade.w = opts.fadeDistance.map { Float($0 * cm) } ?? -1

        let mapW = max(scene.mapSize.width, 1), mapH = max(scene.mapSize.height, 1)
        let o = ground.originPoint(in: CGSize(width: mapW, height: mapH))
        u.map = SIMD4(Float(o.x), Float(o.y), Float(ground.cmPerPoint), 0)
        u.mapSize = SIMD4(Float(mapW), Float(mapH), Float(1 / mapW), Float(1 / mapH))

        u.blade = SIMD4(Float(style.bladeWidth), Float(bladeHeight), Float(style.leanScale), Float(style.heightScale))
        u.blade2 = SIMD4(Float(opts.widthGrowth), Float(opts.minPixelWidth), Float(2 * tanY / h), Float(plan.rings.count))

        let wind = GrassStyle.direction(style.windAngle)
        let windStrength = max(style.windStrength, opts.windStrength)
        u.wind = SIMD4(Float(wind.x), Float(-wind.y), Float(windStrength), Float(style.windSpeed))
        u.wind2 = SIMD4(Float(style.windScale), Float(opts.windSway), Float(opts.gain), Float(opts.sparsityFade))

        u.shade = SIMD4(Float(style.stripeContrast), Float(style.sheen), Float(style.sheenPower), Float(style.grazeBrighten))
        let l = style.lightDirection
        u.light = SIMD4(l.x, -l.y, l.z, Float(style.variation))
        u.atmos = SIMD4(Float(atmosphere.fogDistance * cm), Float(atmosphere.desaturationDistance * cm),
                        Float(atmosphere.horizonGlow), Float(style.patchScale))
        let fadeStart = opts.fadeDistance.map { Float($0 * cm) } ?? -1
        u.grade = SIMD4(Float(style.exposure), Float(style.saturation), Float(style.vignette), fadeStart)
        u.viewport = SIMD4(Float(w), Float(h), Float(1 / w), Float(1 / h))
        u.clip = SIMD4(Float(1 / tanX), Float(1 / tanY), Float(natural), 0)

        u.baseColor = straight(style.baseColor)
        u.tipColor = straight(style.tipColor)
        u.dryColor = straight(style.dryColor)
        u.soilColor = straight(style.soilColor)
        u.sheenColor = straight(style.sheenColor)
        u.fogColor = straight(atmosphere.fogColor)
        return (u, plan)
    }

    /// sRGB-encoded, straight (un-premultiplied) components.
    static func straight(_ color: Color) -> SIMD4<Float> {
        let r = color.resolve(in: EnvironmentValues())
        return SIMD4(r.red, r.green, r.blue, r.opacity)
    }

    // MARK: Readback

    /// Copies a shared `.rgba8Unorm` texture into a premultiplied sRGB CGImage.
    public static func makeImage(from texture: MTLTexture) -> CGImage? {
        guard texture.pixelFormat == .rgba8Unorm || texture.pixelFormat == .bgra8Unorm else { return nil }
        let w = texture.width, h = texture.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        bytes.withUnsafeMutableBytes { buf in
            texture.getBytes(buf.baseAddress!, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        }
        if texture.pixelFormat == .bgra8Unorm {
            for i in stride(from: 0, to: bytes.count, by: 4) { bytes.swapAt(i, i + 2) }
        }
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
