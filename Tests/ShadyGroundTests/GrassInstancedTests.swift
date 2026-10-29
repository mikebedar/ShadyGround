// Instanced-blade grass experiment: offscreen renders of the reference cameras,
// side-by-side composites, and GPU timing. macOS only; writes PNGs under HarnessPaths.root.
import Testing
import SwiftUI
import Metal
@testable import ShadyGround

#if os(macOS)
enum GrassInstancedCompare {
    static var scratch: String { HarnessPaths.root }
    static var outDir: String { HarnessPaths.directory("instanced") }

    @MainActor
    static func renderControl<V: View>(_ view: V, ground: GrassGround, size: CGSize, scale: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: view
            .environment(\.grassGround, ground)
            .frame(width: size.width, height: size.height))
        renderer.scale = scale
        return renderer.cgImage
    }

    static func load(_ path: String) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    static func save(_ image: CGImage, _ name: String) {
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: "\(outDir)/\(name).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        print("INSTANCED \(url.path)")
    }

    /// Images left to right, all scaled to the same height (copy of the harness's sideBySide).
    static func sideBySide(_ images: [CGImage], height: Int = 700) -> CGImage? {
        let widths = images.map { Int(Double($0.width) * Double(height) / Double($0.height)) }
        let gap = 8
        let total = widths.reduce(0, +) + gap * (images.count - 1)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: total, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 0.1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: total, height: height))
        ctx.interpolationQuality = .high
        var x = 0
        for (img, w) in zip(images, widths) {
            ctx.draw(img, in: CGRect(x: x, y: 0, width: w, height: height))
            x += w + gap
        }
        return ctx.makeImage()
    }

    @MainActor
    static func renderScene(_ renderer: GrassInstancedRenderer, _ scene: GrassInstancedScene, pixels: (Int, Int)) -> (CGImage?, Double) {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: pixels.0, height: pixels.1, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        guard let tex = renderer.device.makeTexture(descriptor: desc),
              let cb = renderer.commandQueue.makeCommandBuffer() else { return (nil, 0) }
        renderer.render(scene, into: tex, commandBuffer: cb)
        cb.commit()
        cb.waitUntilCompleted()
        return (GrassInstancedRenderer.makeImage(from: tex), (cb.gpuEndTime - cb.gpuStartTime) * 1000)
    }

    /// Renders a scene at `size` points x `scale`, saves it, and composites
    /// reference | fragment-shader render (if present) | instanced render.
    @MainActor
    static func compare<V: View>(_ name: String, reference: String, size: CGSize, scale: CGFloat = 2,
                                 style: GrassStyle, camera: GrassCamera, ground: GrassGround,
                                 atmosphere: GrassAtmosphere = .none, bladeCount: Int = 400_000,
                                 options: GrassInstancedOptions = .init(),
                                 @ViewBuilder control: () -> V) throws {
        let renderer = try GrassInstancedRenderer(colorPixelFormat: .rgba8Unorm)
        renderer.setControlImage(renderControl(control(), ground: ground, size: size, scale: scale))
        let scene = GrassInstancedScene(style: style, camera: camera, ground: ground, atmosphere: atmosphere,
                                        mapSize: size, bladeCount: bladeCount, time: 0.7, options: options)
        let (image, ms) = renderScene(renderer, scene, pixels: (Int(size.width * scale), Int(size.height * scale)))
        guard let image else { print("INSTANCED FAIL \(name)"); return }
        let s = renderer.stats
        print(String(format: "INSTANCED %@: %.2f ms GPU, %d instances, %d drawn, %d rings, %.0f cells/octave, far %.0f cm",
                     name, ms, s.instances, s.drawnBlades, s.rings, s.cellsPerOctave, s.farDistanceCm))
        save(image, name)
        var row: [CGImage] = []
        if let ref = load("\(scratch)/ref/\(reference)") { row.append(ref) }
        if let frag = load("\(scratch)/out/\(name).png") { row.append(frag) }
        row.append(image)
        if let pair = sideBySide(row) { save(pair, "\(name)_vs_ref") }
        let crop = CGRect(x: 0, y: image.height / 2, width: image.width / 2, height: image.height / 2)
        if let c = image.cropping(to: crop) { save(c, "\(name)_near") }
    }
}

@Suite(.serialized) @MainActor
struct GrassInstancedTests {

@Test func scenes() throws {
    var nationals = GrassStyle.ballpark
    nationals.saturation = 0.95
    nationals.exposure = 1.1
    try GrassInstancedCompare.compare(
        "nationals", reference: "nationals.jpg", size: CGSize(width: 640, height: 480),
        style: nationals,
        camera: .framing(eye: [0, -5, 5], heading: .degrees(45), horizonAt: 0.15, fieldOfView: .degrees(50)),
        ground: .feet(pointsPerFoot: 3, origin: .center),
        atmosphere: GrassAtmosphere(fogColor: Color(.sRGB, red: 0.72, green: 0.76, blue: 0.62), fogDistance: 500, desaturationDistance: 600)
    ) {
        GrassCheckerboard(angle: .zero, cellSize: 45)
    }

    var ball = GrassStyle.lawn
    ball.stripeContrast = 0.5
    ball.saturation = 1.35
    ball.vignette = 0.6
    ball.bladeHeight = 3
    ball.bladeWidth = 0.5
    ball.exposure = 1.3
    ball.grazeBrighten = 0.3
    ball.sheen = 0.25
    ball.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    ball.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    try GrassInstancedCompare.compare(
        "ball", reference: "ball.jpg", size: CGSize(width: 480, height: 480),
        style: ball,
        camera: .framing(eye: [0.4, -1.5, 1.8], horizonAt: -0.05, fieldOfView: .degrees(60)),
        ground: .feet(pointsPerFoot: 16, origin: .center),
        options: GrassInstancedOptions(heightMultiplier: 1.8)
    ) {
        GrassStripes(angle: .degrees(-90), stripeWidth: 8)
    }

    try GrassInstancedCompare.compare(
        "night", reference: "night.jpg", size: CGSize(width: 640, height: 427),
        style: .nightGame,
        camera: .framing(eye: [0, 4, 3.2], horizonAt: 0.42, fieldOfView: .degrees(62)),
        ground: .feet(pointsPerFoot: 2, origin: UnitPoint(x: 0.5, y: 0.9)),
        atmosphere: .haze(distance: 200, color: Color(.sRGB, red: 0.90, green: 0.92, blue: 0.84), glow: 40)
    ) {
        BallparkControl()
    }
}

/// GPU frame time at iPhone 15 Pro resolution (1179 x 2556 px, 4x MSAA).
@Test func timing() throws {
    let renderer = try GrassInstancedRenderer(colorPixelFormat: .rgba8Unorm)
    let pointSize = CGSize(width: 393, height: 852)
    let nightGround = GrassGround.feet(pointsPerFoot: 2, origin: UnitPoint(x: 0.5, y: 0.9))
    let ballGround = GrassGround.feet(pointsPerFoot: 16, origin: .center)
    let nightMap = GrassInstancedCompare.renderControl(BallparkControl(), ground: nightGround, size: pointSize, scale: 3)
    let ballMap = GrassInstancedCompare.renderControl(GrassStripes(angle: .degrees(-90), stripeWidth: 8), ground: ballGround, size: pointSize, scale: 3)

    let cases: [(String, GrassCamera, GrassGround, CGImage?)] = [
        ("night", .framing(eye: [0, 4, 3.2], horizonAt: 0.42, fieldOfView: .degrees(62)), nightGround, nightMap),
        ("ball", .framing(eye: [0.4, -1.5, 1.8], horizonAt: -0.05, fieldOfView: .degrees(60)), ballGround, ballMap),
    ]
    let noMSAA = try GrassInstancedRenderer(colorPixelFormat: .rgba8Unorm, sampleCount: 1)
    for (name, camera, ground, map) in cases {
        renderer.setControlImage(map)
        noMSAA.setControlImage(map)
        for count in [0, 200_000, 400_000] {
            let scene = GrassInstancedScene(style: .nightGame, camera: camera, ground: ground,
                                            atmosphere: .haze(distance: 200), mapSize: pointSize, bladeCount: count, time: 1)
            var times: [Double] = []
            var last: CGImage?
            for i in 0..<12 {
                let (img, ms) = GrassInstancedCompare.renderScene(renderer, scene, pixels: (1179, 2556))
                if i >= 2 { times.append(ms) }
                last = img
            }
            times.sort()
            let s = renderer.stats
            print(String(format: "INSTANCED TIMING %@ %dk: median %.2f ms, min %.2f ms (%d drawn of %d instances)",
                         name, count / 1000, times[times.count / 2], times[0], s.drawnBlades, s.instances))
            if count == 400_000, let last { GrassInstancedCompare.save(last, "timing_\(name)_400k") }
            if count == 400_000 {
                var t1: [Double] = []
                for i in 0..<12 {
                    let (_, ms) = GrassInstancedCompare.renderScene(noMSAA, scene, pixels: (1179, 2556))
                    if i >= 2 { t1.append(ms) }
                }
                t1.sort()
                print(String(format: "INSTANCED TIMING %@ 400k no MSAA: median %.2f ms", name, t1[t1.count / 2]))
            }
        }
    }
}
}
#endif
