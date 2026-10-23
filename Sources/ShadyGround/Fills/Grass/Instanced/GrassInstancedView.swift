//
//  GrassInstancedView.swift
//  ShadyGround
//
//  SwiftUI wrapper (MTKView) around GrassInstancedRenderer. Experimental.
//

import SwiftUI
import MetalKit

/// Real-geometry grass: hundreds of thousands of instanced blades drawn with Metal.
///
/// Takes the same style, camera, ground and atmosphere as ``GrassView``. The control
/// map is a `CGImage` rather than a view (render one with `ImageRenderer`, setting
/// `\.grassGround` in the environment for maps such as ``BallparkControl``). Like
/// ``GrassView``, the map is stretched over the view's bounds.
///
/// ```swift
/// GrassInstancedView(style: .ballpark,
///                    camera: .framing(eye: [0, -18, 4.5], horizonAt: 0.4),
///                    ground: .feet(pointsPerFoot: 2),
///                    controlImage: map)
/// ```
///
/// Pass `time` to drive the wind yourself (the view redraws when it changes), or
/// leave it `nil` to animate continuously at the display rate.
public struct GrassInstancedView: View {
    public var style: GrassStyle
    public var camera: GrassCamera
    public var ground: GrassGround
    public var atmosphere: GrassAtmosphere
    public var controlImage: CGImage?
    public var bladeCount: Int
    public var time: Double?
    public var options: GrassInstancedOptions

    public init(style: GrassStyle = .lawn, camera: GrassCamera, ground: GrassGround, atmosphere: GrassAtmosphere = .none,
                controlImage: CGImage? = nil, bladeCount: Int = 300_000, time: Double? = nil,
                options: GrassInstancedOptions = .init()) {
        self.style = style
        self.camera = camera
        self.ground = ground
        self.atmosphere = atmosphere
        self.controlImage = controlImage
        self.bladeCount = bladeCount
        self.time = time
        self.options = options
    }

    public var body: some View {
        GrassInstancedMetalView(config: self)
    }
}

// MARK: - Platform view

@MainActor
final class GrassInstancedCoordinator: NSObject, MTKViewDelegate {
    var renderer: GrassInstancedRenderer?
    var config: GrassInstancedView?
    private let start = CACurrentMediaTime()

    func configure(_ view: MTKView) {
        let device = MTLCreateSystemDefaultDevice()
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = GrassInstancedRenderer.depthPixelFormat
        view.sampleCount = 4
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.delegate = self
        #if os(iOS)
        view.isOpaque = false
        view.backgroundColor = .clear
        #else
        view.layer?.isOpaque = false
        #endif
        renderer = try? GrassInstancedRenderer(device: device, colorPixelFormat: view.colorPixelFormat, sampleCount: view.sampleCount)
    }

    func update(_ view: MTKView, config: GrassInstancedView) {
        self.config = config
        renderer?.setControlImage(config.controlImage)
        if config.time != nil {
            view.isPaused = true
            view.enableSetNeedsDisplay = true
            #if os(iOS)
            view.setNeedsDisplay()
            #else
            view.needsDisplay = true
            #endif
        } else {
            view.enableSetNeedsDisplay = false
            view.isPaused = false
            view.preferredFramesPerSecond = 60
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let renderer, let config,
              let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = renderer.commandQueue.makeCommandBuffer() else { return }
        let scene = GrassInstancedScene(
            style: config.style, camera: config.camera, ground: config.ground, atmosphere: config.atmosphere,
            mapSize: view.bounds.size, bladeCount: config.bladeCount,
            time: config.time ?? (CACurrentMediaTime() - start), options: config.options)
        renderer.encode(scene, commandBuffer: commandBuffer, pass: pass, drawableSize: view.drawableSize)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

#if os(iOS)
struct GrassInstancedMetalView: UIViewRepresentable {
    var config: GrassInstancedView

    func makeCoordinator() -> GrassInstancedCoordinator { GrassInstancedCoordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        context.coordinator.configure(view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(view, config: config)
    }
}
#elseif os(macOS)
struct GrassInstancedMetalView: NSViewRepresentable {
    var config: GrassInstancedView

    func makeCoordinator() -> GrassInstancedCoordinator { GrassInstancedCoordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        context.coordinator.configure(view)
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.update(view, config: config)
    }
}
#endif
