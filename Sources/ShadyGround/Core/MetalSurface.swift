//
//  MetalSurface.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/9/25.
//
//  Infrastructure for effects that need their own Metal render passes rather than a
//  SwiftUI layer effect: a renderer protocol, a SwiftUI view that hosts one in an
//  MTKView, an offscreen target for tests, a shared shader library, and a texture
//  uploader that reuses textures across frames.
//

import SwiftUI
import Metal
import MetalKit

// MARK: - Shader library

/// The package's compiled Metal library, cached per device.
public enum ShadyGroundMetalLibrary {
    private nonisolated(unsafe) static var cache: [ObjectIdentifier: MTLLibrary] = [:]
    private static let lock = NSLock()

    public static func library(for device: MTLDevice) throws -> MTLLibrary {
        lock.lock()
        defer { lock.unlock() }
        if let lib = cache[ObjectIdentifier(device)] { return lib }
        let lib = try device.makeDefaultLibrary(bundle: .module)
        cache[ObjectIdentifier(device)] = lib
        return lib
    }

    public static func function(_ name: String, device: MTLDevice) throws -> MTLFunction {
        guard let f = try library(for: device).makeFunction(name: name) else {
            throw MetalSurfaceError.missingFunction(name)
        }
        return f
    }
}

public enum MetalSurfaceError: Error {
    case noDevice
    case missingFunction(String)
    case textureCreation
}

// MARK: - Frame context

/// What a renderer knows about the frame it is drawing.
public struct MetalFrameContext: Sendable {
    /// Target size in pixels.
    public var drawableSize: CGSize
    /// Pixels per point.
    public var scale: CGFloat
    /// Seconds since the surface appeared.
    public var time: Double
    /// Seconds since the previous frame, 0 on the first.
    public var deltaTime: Double

    public init(drawableSize: CGSize, scale: CGFloat, time: Double = 0, deltaTime: Double = 0) {
        self.drawableSize = drawableSize
        self.scale = scale
        self.time = time
        self.deltaTime = deltaTime
    }

    /// Target size in points.
    public var pointSize: CGSize {
        CGSize(width: drawableSize.width / max(scale, 0.5), height: drawableSize.height / max(scale, 0.5))
    }
}

// MARK: - Renderer protocol

/// A renderer that draws one frame of an effect into a render pass.
///
/// Conformers hold their pipelines and GPU resources; the host (``MetalSurfaceView``
/// or ``MetalOffscreenTarget``) owns the drawable, MSAA and depth attachments and
/// calls ``encode(_:context:commandBuffer:pass:)`` once per frame.
@MainActor
public protocol MetalSurfaceRenderer: AnyObject {
    /// The value type describing what to draw; the host passes the latest one each frame.
    associatedtype Scene: Equatable

    init(device: MTLDevice) throws

    var device: MTLDevice { get }
    /// Colour format the pipelines were built for. The host configures its drawable to match.
    var colorPixelFormat: MTLPixelFormat { get }
    /// Depth format, or `.invalid` when the renderer does not use depth.
    var depthPixelFormat: MTLPixelFormat { get }
    /// MSAA sample count the pipelines were built for.
    var sampleCount: Int { get }

    /// Encodes one frame into `pass`. Attachments in `pass` already match the formats above.
    func encode(_ scene: Scene, context: MetalFrameContext, commandBuffer: MTLCommandBuffer, pass: MTLRenderPassDescriptor)
}

public extension MetalSurfaceRenderer {
    var depthPixelFormat: MTLPixelFormat { .invalid }
    var sampleCount: Int { 1 }
}

// MARK: - Texture upload

/// Uploads `CGImage`s into an `.rgba8Unorm` texture, reusing the texture when the
/// size has not changed and skipping uploads of the same image.
public final class MetalImageTexture {
    public let device: MTLDevice
    public private(set) var texture: MTLTexture?
    private var lastImage: CGImage?

    public init(device: MTLDevice) {
        self.device = device
    }

    /// Returns the texture for `image`, uploading only when needed. `nil` leaves the last texture.
    @discardableResult
    public func update(with image: CGImage?) -> MTLTexture? {
        guard let image else { return texture }
        if image === lastImage, texture != nil { return texture }
        lastImage = image
        let w = image.width, h = image.height
        if texture == nil || texture!.width != w || texture!.height != h {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
            desc.usage = [.shaderRead]
            desc.storageMode = .shared
            texture = device.makeTexture(descriptor: desc)
        }
        guard let texture else { return nil }
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        if let ctx = CGContext(data: &bytes, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.setBlendMode(.copy)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        texture.replace(region: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0, withBytes: bytes, bytesPerRow: w * 4)
        return texture
    }

    /// A 1x1 placeholder texture with the given encoded colour.
    public static func solid(_ rgba: SIMD4<UInt8>, device: MTLDevice) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        desc.usage = [.shaderRead]
        desc.storageMode = .shared
        guard let tex = device.makeTexture(descriptor: desc) else { return nil }
        var px = [rgba.x, rgba.y, rgba.z, rgba.w]
        tex.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &px, bytesPerRow: 4)
        return tex
    }
}

// MARK: - Offscreen target

/// Renders a ``MetalSurfaceRenderer`` into a texture, with MSAA and depth attachments
/// as the renderer requires. Used by tests and for snapshots.
@MainActor
public final class MetalOffscreenTarget<R: MetalSurfaceRenderer> {
    public let renderer: R
    public let queue: MTLCommandQueue
    private var color: MTLTexture?
    private var msaa: MTLTexture?
    private var depth: MTLTexture?

    public init(renderer: R) throws {
        self.renderer = renderer
        guard let queue = renderer.device.makeCommandQueue() else { throw MetalSurfaceError.noDevice }
        self.queue = queue
    }

    private func attachments(width: Int, height: Int) throws -> (MTLTexture, MTLTexture?, MTLTexture?) {
        let device = renderer.device
        if color == nil || color!.width != width || color!.height != height {
            let cd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderer.colorPixelFormat, width: width, height: height, mipmapped: false)
            cd.usage = [.renderTarget, .shaderRead]
            cd.storageMode = .shared
            color = device.makeTexture(descriptor: cd)
            msaa = nil
            depth = nil
            if renderer.sampleCount > 1 {
                let md = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderer.colorPixelFormat, width: width, height: height, mipmapped: false)
                md.textureType = .type2DMultisample
                md.sampleCount = renderer.sampleCount
                md.usage = [.renderTarget]
                md.storageMode = .private
                msaa = device.makeTexture(descriptor: md)
            }
            if renderer.depthPixelFormat != .invalid {
                let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderer.depthPixelFormat, width: width, height: height, mipmapped: false)
                if renderer.sampleCount > 1 {
                    dd.textureType = .type2DMultisample
                    dd.sampleCount = renderer.sampleCount
                }
                dd.usage = [.renderTarget]
                dd.storageMode = .private
                depth = device.makeTexture(descriptor: dd)
            }
        }
        guard let color else { throw MetalSurfaceError.textureCreation }
        return (color, msaa, depth)
    }

    /// Renders one frame and returns the colour texture plus GPU time in milliseconds.
    public func render(_ scene: R.Scene, size: CGSize, scale: CGFloat, time: Double = 0) throws -> (MTLTexture, Double) {
        let w = max(Int(size.width * scale), 1), h = max(Int(size.height * scale), 1)
        let (color, msaa, depth) = try attachments(width: w, height: h)
        let pass = MTLRenderPassDescriptor()
        if let msaa {
            pass.colorAttachments[0].texture = msaa
            pass.colorAttachments[0].resolveTexture = color
            pass.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            pass.colorAttachments[0].texture = color
            pass.colorAttachments[0].storeAction = .store
        }
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        if let depth {
            pass.depthAttachment.texture = depth
            pass.depthAttachment.loadAction = .clear
            pass.depthAttachment.clearDepth = 1
            pass.depthAttachment.storeAction = .dontCare
        }
        guard let cb = queue.makeCommandBuffer() else { throw MetalSurfaceError.noDevice }
        let context = MetalFrameContext(drawableSize: CGSize(width: w, height: h), scale: scale, time: time)
        renderer.encode(scene, context: context, commandBuffer: cb, pass: pass)
        cb.commit()
        cb.waitUntilCompleted()
        return (color, (cb.gpuEndTime - cb.gpuStartTime) * 1000)
    }

    /// Renders one frame and returns it as a premultiplied sRGB `CGImage`.
    public func image(_ scene: R.Scene, size: CGSize, scale: CGFloat, time: Double = 0) throws -> (CGImage?, Double) {
        let (tex, ms) = try render(scene, size: size, scale: scale, time: time)
        return (Self.makeImage(from: tex), ms)
    }

    /// Copies a shared `.rgba8Unorm` or `.bgra8Unorm` texture into a premultiplied sRGB CGImage.
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

// MARK: - SwiftUI host

/// Hosts a ``MetalSurfaceRenderer`` in an `MTKView` as a SwiftUI view.
///
/// Pass the renderer's scene value; the view redraws when it changes. With
/// `isAnimated` the view also redraws every frame and advances the context's time.
/// The surface is transparent where the renderer writes zero alpha.
public struct MetalSurfaceView<R: MetalSurfaceRenderer>: View {
    public var scene: R.Scene
    public var isAnimated: Bool
    public var preferredFramesPerSecond: Int

    public init(_ rendererType: R.Type = R.self, scene: R.Scene, isAnimated: Bool = false, preferredFramesPerSecond: Int = 60) {
        self.scene = scene
        self.isAnimated = isAnimated
        self.preferredFramesPerSecond = preferredFramesPerSecond
    }

    public var body: some View {
        MetalSurfacePlatformView<R>(config: self)
    }
}

@MainActor
final class MetalSurfaceCoordinator<R: MetalSurfaceRenderer>: NSObject, MTKViewDelegate {
    var renderer: R?
    var scene: R.Scene?
    var isAnimated = false
    private var start: Date?
    private var last: Date?

    func configure(_ view: MTKView) {
        guard let device = view.device ?? MTLCreateSystemDefaultDevice() else { return }
        view.device = device
        renderer = try? R(device: device)
        guard let renderer else { return }
        view.colorPixelFormat = renderer.colorPixelFormat
        view.depthStencilPixelFormat = renderer.depthPixelFormat
        view.sampleCount = renderer.sampleCount
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.framebufferOnly = false
        view.delegate = self
#if os(macOS)
        view.layer?.isOpaque = false
#else
        view.isOpaque = false
        view.backgroundColor = .clear
#endif
    }

    func update(_ view: MTKView, config: MetalSurfaceView<R>) {
        let changed = scene != config.scene
        scene = config.scene
        isAnimated = config.isAnimated
        view.preferredFramesPerSecond = config.preferredFramesPerSecond
        view.isPaused = !config.isAnimated
        view.enableSetNeedsDisplay = !config.isAnimated
        if changed && !config.isAnimated { view.setNeedsDisplay(view.bounds) }
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            guard let renderer, let scene,
                  let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable,
                  let queue = commandQueue(for: renderer.device),
                  let cb = queue.makeCommandBuffer() else { return }
            let now = Date()
            if start == nil { start = now }
            let time = isAnimated ? now.timeIntervalSince(start!) : 0
            let dt = last.map { now.timeIntervalSince($0) } ?? 0
            last = now
#if os(macOS)
            let scale = view.window?.backingScaleFactor ?? 2
#else
            let scale = view.contentScaleFactor
#endif
            let context = MetalFrameContext(drawableSize: view.drawableSize, scale: scale, time: time, deltaTime: dt)
            renderer.encode(scene, context: context, commandBuffer: cb, pass: pass)
            cb.present(drawable)
            cb.commit()
        }
    }

    private var queue: MTLCommandQueue?
    private func commandQueue(for device: MTLDevice) -> MTLCommandQueue? {
        if queue == nil { queue = device.makeCommandQueue() }
        return queue
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
struct MetalSurfacePlatformView<R: MetalSurfaceRenderer>: UIViewRepresentable {
    let config: MetalSurfaceView<R>

    func makeCoordinator() -> MetalSurfaceCoordinator<R> { MetalSurfaceCoordinator<R>() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        context.coordinator.configure(view)
        context.coordinator.update(view, config: config)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(view, config: config)
    }
}
#elseif os(macOS)
struct MetalSurfacePlatformView<R: MetalSurfaceRenderer>: NSViewRepresentable {
    let config: MetalSurfaceView<R>

    func makeCoordinator() -> MetalSurfaceCoordinator<R> { MetalSurfaceCoordinator<R>() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        context.coordinator.configure(view)
        context.coordinator.update(view, config: config)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.update(view, config: config)
    }
}
#endif
