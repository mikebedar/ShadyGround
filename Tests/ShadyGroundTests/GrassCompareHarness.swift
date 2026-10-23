// Visual comparison harness. macOS only; writes PNGs to the session scratchpad.
// Not a correctness test: it never fails, it produces images for inspection.
import Testing
import SwiftUI
import Metal
@testable import ShadyGround

#if os(macOS)
enum GrassCompare {
    static let scratch = "/private/tmp/claude-501/-Users-bedar-Developer-ShadyGround/e7fdca46-9327-4811-b227-695ecf4ac9b0/scratchpad"

    @MainActor
    static func render<V: View>(_ view: V, size: CGSize, scale: CGFloat = 2) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        return renderer.cgImage
    }

    static func load(_ name: String) -> CGImage? {
        let url = URL(fileURLWithPath: "\(scratch)/ref/\(name)")
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    static func save(_ image: CGImage, _ name: String) {
        let url = URL(fileURLWithPath: "\(scratch)/out/\(name).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        print("COMPARE \(url.path)")
    }

    /// Reference on the left, render on the right, both scaled to the same height.
    static func sideBySide(reference: CGImage, render: CGImage, height: Int = 700) -> CGImage? {
        let rw = Int(Double(reference.width) * Double(height) / Double(reference.height))
        let ow = Int(Double(render.width) * Double(height) / Double(render.height))
        let gap = 8
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: rw + gap + ow, height: height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 0.1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: rw + gap + ow, height: height))
        ctx.interpolationQuality = .high
        ctx.draw(reference, in: CGRect(x: 0, y: 0, width: rw, height: height))
        ctx.draw(render, in: CGRect(x: rw + gap, y: 0, width: ow, height: height))
        return ctx.makeImage()
    }

    @MainActor
    static func compare<V: View>(_ name: String, reference: String, size: CGSize, @ViewBuilder _ view: () -> V) {
        guard let ref = load(reference), let out = render(view(), size: size) else { print("COMPARE FAIL \(name)"); return }
        save(out, name)
        if let pair = sideBySide(reference: ref, render: out) { save(pair, "\(name)_vs_ref") }
        // 1:1 crop of the bottom-left quarter, where foreground detail lives.
        let crop = CGRect(x: 0, y: out.height / 2, width: out.width / 2, height: out.height / 2)
        if let c = out.cropping(to: crop) { save(c, "\(name)_near") }
    }
}

extension GrassCompare {
    /// Renders the control view to an image for the instanced layer.
    @MainActor
    static func controlImage<V: View>(_ view: V, ground: GrassGround, size: CGSize, scale: CGFloat) -> CGImage? {
        let r = ImageRenderer(content: view.environment(\.grassGround, ground).frame(width: size.width, height: size.height))
        r.scale = scale
        return r.cgImage
    }

    /// Fragment-shader far field with instanced near-field blades composited on top.
    @MainActor
    static func hybrid<V: View>(_ name: String, reference: String, size: CGSize, scale: CGFloat = 2,
                                style: GrassStyle, camera: GrassCamera, ground: GrassGround,
                                atmosphere: GrassAtmosphere = .none, bladeRange: Double, bladeCount: Int = 400_000,
                                @ViewBuilder control: () -> V) throws {
        let controlView = control()
        var far = style
        far.shellCount = 0
        guard let base = render(GrassView(style: far, camera: camera, ground: ground, atmosphere: atmosphere) { controlView },
                                size: size, scale: scale) else { print("HYBRID FAIL base \(name)"); return }

        let renderer = try GrassInstancedRenderer(colorPixelFormat: .rgba8Unorm)
        renderer.setControlImage(controlImage(controlView, ground: ground, size: size, scale: scale))
        let scene = GrassInstancedScene(style: style, camera: camera, ground: ground, atmosphere: atmosphere,
                                        mapSize: size, bladeCount: bladeCount, time: 0.7,
                                        options: .nearField(range: bladeRange))
        let w = Int(size.width * scale), h = Int(size.height * scale)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: w, height: h, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        guard let tex = renderer.device.makeTexture(descriptor: desc),
              let cb = renderer.commandQueue.makeCommandBuffer() else { print("HYBRID FAIL gpu \(name)"); return }
        renderer.render(scene, into: tex, commandBuffer: cb)
        cb.commit()
        cb.waitUntilCompleted()
        // Warm second frame for timing.
        guard let cb2 = renderer.commandQueue.makeCommandBuffer() else { return }
        renderer.render(scene, into: tex, commandBuffer: cb2)
        cb2.commit()
        cb2.waitUntilCompleted()
        let ms = (cb2.gpuEndTime - cb2.gpuStartTime) * 1000
        guard let blades = GrassInstancedRenderer.makeImage(from: tex) else { print("HYBRID FAIL readback \(name)"); return }
        print(String(format: "HYBRID %@: blades %.2f ms GPU warm, %d drawn of %d budget", name, ms, renderer.stats.drawnBlades, bladeCount))

        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        ctx.draw(base, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(blades, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let out = ctx.makeImage() else { return }
        save(out, "\(name)_hybrid")
        var row: [CGImage] = []
        if let ref = load(reference) { row.append(ref) }
        if let frag = load("../out/\(name).png") { row.append(frag) }
        row.append(out)
        if let strip = sideBySideRow(row) { save(strip, "\(name)_hybrid_vs_ref") }
        let crop = CGRect(x: 0, y: h / 2, width: w / 2, height: h / 2)
        if let c = out.cropping(to: crop) { save(c, "\(name)_hybrid_near") }
    }

    static func sideBySideRow(_ images: [CGImage], height: Int = 700) -> CGImage? {
        let gap = 8
        let widths = images.map { Int(Double($0.width) * Double(height) / Double($0.height)) }
        let total = widths.reduce(0, +) + gap * max(images.count - 1, 0)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: total, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 0.1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: total, height: height))
        ctx.interpolationQuality = .high
        var x = 0
        for (img, wdt) in zip(images, widths) {
            ctx.draw(img, in: CGRect(x: x, y: 0, width: wdt, height: height))
            x += wdt + gap
        }
        return ctx.makeImage()
    }
}

extension GrassCompare {
    /// Mean absolute difference per channel (0...255) between two same-sized images, alpha included.
    static func meanDifference(_ a: CGImage, _ b: CGImage) -> Double {
        guard a.width == b.width, a.height == b.height else { return 255 }
        let w = a.width, h = a.height
        func bytes(_ img: CGImage) -> [UInt8] {
            var out = [UInt8](repeating: 0, count: w * h * 4)
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            let ctx = CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.setBlendMode(.copy)
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return out
        }
        let pa = bytes(a), pb = bytes(b)
        var sum = 0
        for i in 0..<pa.count { sum += abs(Int(pa[i]) - Int(pb[i])) }
        return Double(sum) / Double(pa.count)
    }

    @MainActor
    static func metal<V: View>(_ name: String, reference: String, size: CGSize, scale: CGFloat = 2,
                               style: GrassStyle, camera: GrassCamera, ground: GrassGround,
                               atmosphere: GrassAtmosphere = .none, bladeRange: Double?, bladeCount: Int = 400_000,
                               time: Double = 0.7,
                               @ViewBuilder control: () -> V) throws -> CGImage? {
        let image = controlImage(control(), ground: ground, size: size, scale: scale)
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let target = try MetalOffscreenTarget(renderer: try GrassMetalRenderer(device: device))
        let scene = GrassMetalScene(style: style, camera: camera, ground: ground, atmosphere: atmosphere,
                                    bladeRange: bladeRange, bladeCount: bladeCount, control: GrassControlImage(image))
        _ = try target.render(scene, size: size, scale: scale, time: time)
        let (out, ms) = try target.image(scene, size: size, scale: scale, time: time)
        guard let out else { print("METAL FAIL \(name)"); return nil }
        let st = target.renderer.bladeStats
        print(String(format: "METAL %@: %.2f ms GPU warm (ground + %d blades drawn of %d instances, %d rings, %.0f cells/octave)", name, ms, st.drawnBlades, st.instances, st.rings, st.cellsPerOctave))
        save(out, "\(name)_metal")
        var row: [CGImage] = []
        if let ref = load(reference) ?? load("../refweb/\(reference)") { row.append(ref) }
        if let hybrid = load("../out/\(name)_hybrid.png") { row.append(hybrid) }
        row.append(out)
        if let strip = sideBySideRow(row) { save(strip, "\(name)_metal_vs_ref") }
        return out
    }
}

@MainActor
@Test func grassDistantScenes() throws {
    // Upper deck, third-base side, looking across to right-centre (Yankee Stadium photo).
    _ = try GrassCompare.metal("upperdeck", reference: "yankee_stands.jpg", size: CGSize(width: 640, height: 427),
                               style: .stadium,
                               camera: .lookAt(eye: [-170, -40, 115], target: [40, 190, 0], fieldOfView: .degrees(58)),
                               ground: .feet(pointsPerFoot: 1.2, origin: UnitPoint(x: 0.5, y: 0.92)),
                               atmosphere: GrassAtmosphere(fogColor: Color(.sRGB, red: 0.85, green: 0.87, blue: 0.85), fogDistance: 9000),
                               bladeRange: nil) {
        BallparkControl(stripeAngle: .degrees(-90), stripeWidth: 18, lean: 0.85) {
            GrassCrosshatch(angle: .degrees(-62), secondAngle: .degrees(-118), stripeWidth: 18, lean: 0.6)
        }
    }

    // Drone straight down over striped turf in evening light, about 1.5 cm per pixel.
    var evening = GrassStyle.stadium
    evening.exposure = 0.62
    evening.saturation = 0.9
    _ = try GrassCompare.metal("aerial", reference: "topdown_pitch.jpg", size: CGSize(width: 640, height: 480),
                               style: evening,
                               camera: .lookAt(eye: [0, 0, 120], target: [0, 0.01, 0], fieldOfView: .degrees(45)),
                               ground: .feet(pointsPerFoot: 5, origin: .center),
                               bladeRange: nil) {
        GrassStripes(angle: .zero, stripeWidth: 28, lean: 0.85)
    }
}

@MainActor
@Test func grassMetalParity() throws {
    // The Metal ground pass must reproduce the SwiftUI layer effect: same shader, same map.
    var style = GrassStyle.ballpark
    style.shellCount = 0
    let size = CGSize(width: 320, height: 240)
    let camera = GrassCamera.framing(eye: [0, -5, 5], heading: .degrees(45), horizonAt: 0.15, fieldOfView: .degrees(50))
    let ground = GrassGround.feet(pointsPerFoot: 3, origin: .center)
    let atmosphere = GrassAtmosphere(fogColor: Color(.sRGB, red: 0.72, green: 0.76, blue: 0.62), fogDistance: 500, desaturationDistance: 600)
    let swiftUI = try #require(GrassCompare.render(
        GrassView(style: style, camera: camera, ground: ground, atmosphere: atmosphere) { GrassCheckerboard(angle: .zero, cellSize: 45) },
        size: size, scale: 2))
    let metal = try #require(try GrassCompare.metal("parity", reference: "nationals.jpg", size: size,
                                                     style: style, camera: camera, ground: ground, atmosphere: atmosphere, bladeRange: nil, time: 0) {
        GrassCheckerboard(angle: .zero, cellSize: 45)
    })
    let diff = GrassCompare.meanDifference(swiftUI, metal)
    print(String(format: "PARITY mean abs diff %.2f / 255", diff))
    #expect(diff < 4, "Metal ground pass should match the SwiftUI layer effect")
}

@MainActor
@Test func grassMetalScenes() throws {
    var nationals = GrassStyle.ballpark
    nationals.saturation = 0.95
    nationals.exposure = 1.1
    _ = try GrassCompare.metal("nationals", reference: "nationals.jpg", size: CGSize(width: 640, height: 480),
                               style: nationals,
                               camera: .framing(eye: [0, -5, 5], heading: .degrees(45), horizonAt: 0.15, fieldOfView: .degrees(50)),
                               ground: .feet(pointsPerFoot: 3, origin: .center),
                               atmosphere: GrassAtmosphere(fogColor: Color(.sRGB, red: 0.72, green: 0.76, blue: 0.62), fogDistance: 500, desaturationDistance: 600),
                               bladeRange: 40) {
        GrassCheckerboard(angle: .zero, cellSize: 45)
    }

    var ball = GrassStyle.lawn
    ball.stripeContrast = 0.5
    ball.saturation = 1.35
    ball.vignette = 0.6
    ball.bladeHeight = 3
    ball.bladeWidth = 0.38
    ball.exposure = 1.3
    ball.grazeBrighten = 0.3
    ball.sheen = 0.25
    ball.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    ball.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    _ = try GrassCompare.metal("ball", reference: "ball.jpg", size: CGSize(width: 480, height: 480),
                               style: ball,
                               camera: .framing(eye: [0.4, -1.5, 1.8], horizonAt: -0.05, fieldOfView: .degrees(60)),
                               ground: .feet(pointsPerFoot: 16, origin: .center),
                               bladeRange: 30, bladeCount: 400_000) {
        GrassStripes(angle: .degrees(-90), stripeWidth: 8)
    }

    _ = try GrassCompare.metal("night", reference: "night.jpg", size: CGSize(width: 640, height: 427),
                               style: .nightGame,
                               camera: .framing(eye: [0, 4, 3.2], horizonAt: 0.42, fieldOfView: .degrees(62)),
                               ground: .feet(pointsPerFoot: 2, origin: UnitPoint(x: 0.5, y: 0.9)),
                               atmosphere: .haze(distance: 200, color: Color(.sRGB, red: 0.90, green: 0.92, blue: 0.84), glow: 40),
                               bladeRange: 45) {
        BallparkControl()
    }

    // Simulation uploaded straight to the control texture, no ImageRenderer round trip.
    let sim = GrassTurfSimulation(extent: CGRect(x: -160, y: 140, width: 320, height: 130), resolution: 320)
    let map = BallparkControl(stripeAngle: .degrees(-90), stripeWidth: 22, lean: 0.85)
    let trailGround = GrassGround.feet(pointsPerFoot: 1, origin: UnitPoint(x: 0.5, y: 0.95))
    let trailSize = CGSize(width: 640, height: 427)
    sim.baseLean = { map.stripeLean(at: $0, ground: trailGround, size: trailSize) }
    var last = CGPoint(x: -60, y: 160)
    for i in 0..<180 {
        let t = Double(i) / 180
        let p = CGPoint(x: -60 + 100 * t, y: 160 + 40 * t + 12 * sin(t * 6))
        sim.roll(at: p, radius: 0.75, velocity: CGVector(dx: p.x - last.x, dy: p.y - last.y))
        last = p
        sim.step(dt: 1.0 / 60.0)
    }
    var trailStyle = GrassStyle.ballpark
    trailStyle.stripeContrast = 0.45
    trailStyle.exposure = 1.1
    _ = try GrassCompare.metal("trail", reference: "night.jpg", size: trailSize,
                               style: trailStyle,
                               camera: .lookAt(eye: [-70, 148, 4.5], target: [-25, 178, 0], fieldOfView: .degrees(55)),
                               ground: trailGround,
                               atmosphere: .haze(distance: 200),
                               bladeRange: 30) {
        BallparkControl(stripeWidth: 22) {
            ZStack {
                GrassStripes(angle: .degrees(-90), stripeWidth: 22, lean: 0.85)
                GrassSimulationControl(sim, isRunning: false)
            }
        }
    }
}

@MainActor
@Test func grassHybridScenes() throws {
    var nationals = GrassStyle.ballpark
    nationals.saturation = 0.95
    nationals.exposure = 1.1
    try GrassCompare.hybrid("nationals", reference: "nationals.jpg", size: CGSize(width: 640, height: 480),
                            style: nationals,
                            camera: .framing(eye: [0, -5, 5], heading: .degrees(45), horizonAt: 0.15, fieldOfView: .degrees(50)),
                            ground: .feet(pointsPerFoot: 3, origin: .center),
                            atmosphere: GrassAtmosphere(fogColor: Color(.sRGB, red: 0.72, green: 0.76, blue: 0.62), fogDistance: 500, desaturationDistance: 600),
                            bladeRange: 40) {
        GrassCheckerboard(angle: .zero, cellSize: 45)
    }

    var ball = GrassStyle.lawn
    ball.stripeContrast = 0.5
    ball.saturation = 1.35
    ball.vignette = 0.6
    ball.bladeHeight = 3
    ball.bladeWidth = 0.38
    ball.exposure = 1.3
    ball.grazeBrighten = 0.3
    ball.sheen = 0.25
    ball.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    ball.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    try GrassCompare.hybrid("ball", reference: "ball.jpg", size: CGSize(width: 480, height: 480),
                            style: ball,
                            camera: .framing(eye: [0.4, -1.5, 1.8], horizonAt: -0.05, fieldOfView: .degrees(60)),
                            ground: .feet(pointsPerFoot: 16, origin: .center),
                            bladeRange: 14) {
        GrassStripes(angle: .degrees(-90), stripeWidth: 8)
    }

    try GrassCompare.hybrid("ball150k", reference: "ball.jpg", size: CGSize(width: 480, height: 480),
                            style: ball,
                            camera: .framing(eye: [0.4, -1.5, 1.8], horizonAt: -0.05, fieldOfView: .degrees(60)),
                            ground: .feet(pointsPerFoot: 16, origin: .center),
                            bladeRange: 14, bladeCount: 150_000) {
        GrassStripes(angle: .degrees(-90), stripeWidth: 8)
    }

    try GrassCompare.hybrid("night", reference: "night.jpg", size: CGSize(width: 640, height: 427),
                            style: .nightGame,
                            camera: .framing(eye: [0, 4, 3.2], horizonAt: 0.42, fieldOfView: .degrees(62)),
                            ground: .feet(pointsPerFoot: 2, origin: UnitPoint(x: 0.5, y: 0.9)),
                            atmosphere: .haze(distance: 200, color: Color(.sRGB, red: 0.90, green: 0.92, blue: 0.84), glow: 40),
                            bladeRange: 45) {
        BallparkControl()
    }
}

@MainActor
@Test func grassCompareScenes() throws {
    // Nationals Park: checkerboard, low oblique view across the outfield, overcast.
    var nationals = GrassStyle.ballpark
    nationals.saturation = 0.95
    nationals.exposure = 1.1
    GrassCompare.compare("nationals", reference: "nationals.jpg", size: CGSize(width: 640, height: 480)) {
        GrassView(
            style: nationals,
            camera: .framing(eye: [0, -5, 5], heading: .degrees(45), horizonAt: 0.15, fieldOfView: .degrees(50)),
            ground: .feet(pointsPerFoot: 3, origin: .center),
            atmosphere: GrassAtmosphere(fogColor: Color(.sRGB, red: 0.72, green: 0.76, blue: 0.62), fogDistance: 500, desaturationDistance: 600)
        ) {
            GrassCheckerboard(angle: .zero, cellSize: 45)
        }
    }

    // Stock ball shot: wide stripes, camera almost on the ground, saturated and vignetted.
    var ball = GrassStyle.lawn
    ball.stripeContrast = 0.5
    ball.saturation = 1.35
    ball.vignette = 0.6
    ball.bladeHeight = 3
    ball.bladeWidth = 0.38
    ball.exposure = 1.3
    ball.grazeBrighten = 0.3
    ball.sheen = 0.25
    ball.shellCount = 8
    ball.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    ball.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    GrassCompare.compare("ball", reference: "ball.jpg", size: CGSize(width: 480, height: 480)) {
        GrassView(
            style: ball,
            camera: .framing(eye: [0.4, -1.5, 1.8], horizonAt: -0.05, fieldOfView: .degrees(60)),
            ground: .feet(pointsPerFoot: 16, origin: .center)
        ) {
            GrassStripes(angle: .degrees(-90), stripeWidth: 8)
        }
    }

    // Night game: behind the plate, lime turf, cream haze.
    GrassCompare.compare("night", reference: "night.jpg", size: CGSize(width: 640, height: 427)) {
        GrassView(
            style: .nightGame,
            camera: .framing(eye: [0, 4, 3.2], horizonAt: 0.42, fieldOfView: .degrees(62)),
            ground: .feet(pointsPerFoot: 2, origin: UnitPoint(x: 0.5, y: 0.9)),
            atmosphere: .haze(distance: 200, color: Color(.sRGB, red: 0.90, green: 0.92, blue: 0.84), glow: 40)
        ) {
            BallparkControl()
        }
    }

    // Simulation: a ball rolled across the outfield leaves a combed, recovering trail.
    let sim = GrassTurfSimulation(extent: CGRect(x: -160, y: 140, width: 320, height: 130), resolution: 320)
    let map = BallparkControl(stripeAngle: .degrees(-90), stripeWidth: 22, lean: 0.85)
    let trailGround = GrassGround.feet(pointsPerFoot: 1, origin: UnitPoint(x: 0.5, y: 0.95))
    let trailSize = CGSize(width: 640, height: 427)
    sim.baseLean = { map.stripeLean(at: $0, ground: trailGround, size: trailSize) }
    var last = CGPoint(x: -60, y: 160)
    for i in 0..<180 {
        let t = Double(i) / 180
        let p = CGPoint(x: -60 + 100 * t, y: 160 + 40 * t + 12 * sin(t * 6))
        sim.roll(at: p, radius: 0.75, velocity: CGVector(dx: p.x - last.x, dy: p.y - last.y))
        last = p
        sim.step(dt: 1.0 / 60.0)
    }
    sim.press(at: CGPoint(x: -20, y: 175), radius: 1.2)
    sim.press(at: CGPoint(x: -18, y: 178), radius: 1.2)
    for _ in 0..<30 { sim.step(dt: 1.0 / 60.0) }
    // The raw control map, for checking the simulation layer lands where expected.
    if let cg = GrassCompare.render(
        BallparkControl(stripeWidth: 22) {
            ZStack {
                GrassStripes(angle: .degrees(-90), stripeWidth: 22, lean: 0.85)
                GrassSimulationControl(sim, isRunning: false)
            }
        }.environment(\.grassGround, .feet(pointsPerFoot: 1, origin: UnitPoint(x: 0.5, y: 0.95))),
        size: CGSize(width: 640, height: 427), scale: 1) {
        GrassCompare.save(cg, "trail_control")
    }
    var trailStyle = GrassStyle.ballpark
    trailStyle.stripeContrast = 0.45
    trailStyle.exposure = 1.1
    GrassCompare.compare("trail", reference: "night.jpg", size: CGSize(width: 640, height: 427)) {
        GrassView(
            style: trailStyle,
            camera: .lookAt(eye: [-70, 148, 4.5], target: [-25, 178, 0], fieldOfView: .degrees(55)),
            ground: .feet(pointsPerFoot: 1, origin: UnitPoint(x: 0.5, y: 0.95)),
            atmosphere: .haze(distance: 200)
        ) {
            BallparkControl(stripeWidth: 22) {
                ZStack {
                    GrassStripes(angle: .degrees(-90), stripeWidth: 22, lean: 0.85)
                    GrassSimulationControl(sim, isRunning: false)
                }
            }
        }
    }

    // Regression: the original top-down ballpark still works.
    GrassCompare.compare("topdown", reference: "night.jpg", size: CGSize(width: 500, height: 560)) {
        GrassView(style: .ballpark) { BallparkControl() }
    }
}
#endif


#if os(macOS)
@MainActor
@Test func grassMetalHeightDemo() throws {
    var ball = GrassStyle.lawn
    ball.stripeContrast = 0.5
    ball.saturation = 1.35
    ball.vignette = 0.6
    ball.bladeHeight = 3
    ball.bladeWidth = 0.38
    ball.exposure = 1.3
    ball.grazeBrighten = 0.3
    ball.sheen = 0.25
    ball.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    ball.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    _ = try GrassCompare.metal("height", reference: "ball.jpg", size: CGSize(width: 480, height: 480),
                               style: ball,
                               camera: .framing(eye: [0.4, -1.5, 1.8], horizonAt: -0.05, fieldOfView: .degrees(60)),
                               ground: .feet(pointsPerFoot: 16, origin: .center),
                               bladeRange: 30, bladeCount: 250_000) {
        ZStack {
            GrassStripes(angle: .degrees(-90), stripeWidth: 8, height: 0.3)
            // An unmown clump: full height, same lean.
            Circle()
                .fill(GrassControl.color(angle: .degrees(-90), lean: 0.3, height: 1.0))
                .frame(width: 70, height: 70)
                .offset(x: -70, y: -150)
            // A scalped strip across the stripes.
            Rectangle()
                .fill(GrassControl.color(lean: .zero, height: 0.05))
                .frame(width: 480, height: 24)
                .offset(y: -70)
        }
    }
}
#endif

#if os(macOS)
@MainActor
@Test func grassLawnArt() throws {
    var style = GrassStyle.stadium
    style.bladeHeight = 5
    style.stripeContrast = 0.45
    let camera = GrassCamera.lookAt(eye: [0, -34, 16], target: [0, 4, 0], fieldOfView: .degrees(50))
    let ground = GrassGround.feet(pointsPerFoot: 10, origin: .center)
    let size = CGSize(width: 640, height: 480)
    let away = CGVector(dx: 0, dy: 0.85)     // mown away from the camera: light
    let toward = CGVector(dx: 0, dy: -0.85)  // mown toward the camera: dark

    // A batter badge with lettering, built from an SF Symbol: bright = tall, mown away.
    let badge = ImageRenderer(content:
        ZStack {
            Color.black
            VStack(spacing: 12) {
                Image(systemName: "figure.baseball")
                    .resizable().scaledToFit()
                    .frame(width: 180, height: 180)
                Text("SHADY")
                    .font(.system(size: 64, weight: .black, design: .rounded))
            }
            .foregroundStyle(.white)
        }
        .frame(width: 640, height: 480)
    )
    badge.scale = 2
    let badgeImage = try #require(badge.cgImage)
    // Mown art is direction, not height: keep the height nearly flat.
    let art = try #require(GrassControl.heightMap(from: badgeImage, range: 0.3...0.42, lean: away, darkLean: toward))
    _ = try GrassCompare.metal("lawnart", reference: "nationals.jpg", size: size, style: style, camera: camera, ground: ground,
                               bladeRange: 40, bladeCount: 300_000) {
        Image(decorative: art, scale: 2).resizable()
    }

    // A photograph as relief and direction, filling a 40 ft wide patch of lawn.
    let photo = try #require(GrassCompare.load("ball.jpg"))
    let reliefMap = try #require(GrassControl.heightMap(from: photo, range: 0.2...0.9, lean: away, darkLean: toward, size: CGSize(width: 800, height: 800)))
    _ = try GrassCompare.metal("relief", reference: "ball.jpg", size: size, style: style, camera: camera, ground: ground,
                               bladeRange: 40, bladeCount: 300_000) {
        ZStack {
            GrassControl.color(lean: CGVector(dx: 0.5, dy: 0.5))
            Image(decorative: reliefMap, scale: 2).resizable()
                .frame(width: 400, height: 400)
                .offset(y: -60)
        }
    }
}
#endif

#if os(macOS)
extension GrassCompare {
    /// Writes frames as a looping GIF.
    static func saveGIF(_ frames: [CGImage], name: String, fps: Double) {
        let url = URL(fileURLWithPath: "\(scratch)/out/\(name).gif")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "com.compuserve.gif" as CFString, frames.count, nil) else { return }
        let fileProps: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]]
        CGImageDestinationSetProperties(dest, fileProps as CFDictionary)
        let frameProps: [CFString: Any] = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1.0 / fps]]
        for f in frames { CGImageDestinationAddImage(dest, f, frameProps as CFDictionary) }
        CGImageDestinationFinalize(dest)
        print("GIF \(url.path)")
    }

    /// Mean absolute difference between two same-sized images (0...255), over a rect.
    static func meanDifference(_ a: CGImage, _ b: CGImage, in rect: CGRect) -> Double {
        guard let ca = a.cropping(to: rect), let cb = b.cropping(to: rect) else { return 255 }
        return meanDifference(ca, cb)
    }
}

@MainActor
@Test func grassFlyover() throws {
    var ball = GrassStyle.lawn
    ball.stripeContrast = 0.5
    ball.saturation = 1.35
    ball.vignette = 0.6
    ball.bladeHeight = 3
    ball.bladeWidth = 0.38
    ball.exposure = 1.3
    ball.grazeBrighten = 0.3
    ball.sheen = 0.25
    ball.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    ball.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    ball.windStrength = ProcessInfo.processInfo.environment["GRASS_NO_WIND"] != nil ? 0 : 0.12
    let size = CGSize(width: 480, height: 480)
    let ground = GrassGround.feet(pointsPerFoot: 16, origin: .center)
    let control = GrassCompare.controlImage(GrassStripes(angle: .degrees(-90), stripeWidth: 8), ground: ground, size: size, scale: 2)
    guard let device = MTLCreateSystemDefaultDevice() else { return }
    let target = try MetalOffscreenTarget(renderer: try GrassMetalRenderer(device: device))

    let fps = 30.0, seconds = 2.0
    let frameCount = Int(fps * seconds)
    var frames: [CGImage] = []
    var diffs: [Double] = []
    var bandDiffs: [Double] = []
    var farDiffs: [Double] = []
    for i in 0..<frameCount {
        let t = Double(i) / fps
        // 2 ft/s forward, a little sway and bob, like a low drone.
        let eye = SIMD3<Double>(0.4 + 0.25 * sin(t * 1.3), -1.5 + 2.0 * t, 1.8 + 0.08 * sin(t * 2.1))
        let camera = GrassCamera.framing(eye: eye, heading: .degrees(3 * sin(t * 0.9)), horizonAt: -0.05, fieldOfView: .degrees(60))
        let noBlades = ProcessInfo.processInfo.environment["GRASS_NO_BLADES"] != nil
        var frameStyle = ball
        if noBlades { frameStyle.shellCount = 0 }     // the texture the blades fade into, not the shell path
        let scene = GrassMetalScene(style: frameStyle, camera: camera, ground: ground, bladeRange: noBlades ? nil : 30, bladeCount: 400_000,
                                    control: GrassControlImage(control))
        let (img, _) = try target.image(scene, size: size, scale: 1.5, time: t)
        guard let img else { continue }
        if i == 30 || i == 31 { GrassCompare.save(img, String(format: "fly_%02d", i)) }
        if let last = frames.last {
            diffs.append(GrassCompare.meanDifference(last, img, in: CGRect(x: 0, y: 360, width: 720, height: 360)))
            bandDiffs.append(GrassCompare.meanDifference(last, img, in: CGRect(x: 0, y: 60, width: 720, height: 160)))
            farDiffs.append(GrassCompare.meanDifference(last, img, in: CGRect(x: 0, y: 0, width: 720, height: 50)))
        }
        frames.append(img)
        if i % 10 == 0 { GrassCompare.save(img, String(format: "fly_%02d", i)) }
    }
    GrassCompare.saveGIF(frames, name: "flyover", fps: fps)
    if frames.count > 31 {
        let a = frames[30], b = frames[31]
        let w = a.width, h = a.height
        func bytes(_ img: CGImage) -> [UInt8] {
            var out = [UInt8](repeating: 0, count: w * h * 4)
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            let ctx = CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
            return out
        }
        let pa = bytes(a), pb = bytes(b)
        var d = [UInt8](repeating: 255, count: w * h * 4)
        for i in stride(from: 0, to: d.count, by: 4) {
            let v = min(255, 4 * (abs(Int(pa[i]) - Int(pb[i])) + abs(Int(pa[i+1]) - Int(pb[i+1])) + abs(Int(pa[i+2]) - Int(pb[i+2]))) / 3)
            d[i] = UInt8(v); d[i+1] = UInt8(v); d[i+2] = UInt8(v)
        }
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        if let provider = CGDataProvider(data: Data(d) as CFData),
           let diff = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs,
                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
            GrassCompare.save(diff, "flyover_diff_30_31")
        }
    }
    let mean = diffs.reduce(0, +) / Double(max(diffs.count, 1))
    let band = bandDiffs.reduce(0, +) / Double(max(bandDiffs.count, 1))
    let far = farDiffs.reduce(0, +) / Double(max(farDiffs.count, 1))
    // Real motion changes the band far less than the near field (less parallax), so a
    // band figure approaching the near figure means twinkling rather than motion.
    print(String(format: "FLYOVER %d frames, frame-to-frame diff near %.2f (max %.2f), handoff band %.2f, far %.2f", frames.count, mean, diffs.max() ?? 0, band, far))
}
#endif

#if os(macOS)
/// Temporal stability probe: a 3 mm camera step should change the image only slightly.
/// Large differences mean blades are popping or the lattice is rescaling.
@MainActor
@Test func grassFlyoverStability() throws {
    var ball = GrassStyle.lawn
    ball.bladeHeight = 3
    ball.bladeWidth = 0.5
    ball.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    ball.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    let size = CGSize(width: 480, height: 480)
    let ground = GrassGround.feet(pointsPerFoot: 16, origin: .center)
    let control = GrassCompare.controlImage(GrassStripes(angle: .degrees(-90), stripeWidth: 8), ground: ground, size: size, scale: 2)
    guard let device = MTLCreateSystemDefaultDevice() else { return }
    let target = try MetalOffscreenTarget(renderer: try GrassMetalRenderer(device: device))
    func frame(_ eye: SIMD3<Double>) throws -> CGImage? {
        let camera = GrassCamera.framing(eye: eye, horizonAt: -0.05, fieldOfView: .degrees(60))
        let scene = GrassMetalScene(style: ball, camera: camera, ground: ground, bladeRange: 30, bladeCount: 400_000,
                                    control: GrassControlImage(control))
        return try target.image(scene, size: size, scale: 1, time: 0).0
    }
    let a = try #require(try frame([0.4, -1.5, 1.8]))
    let b = try #require(try frame([0.4, -1.49, 1.8]))          // 3 mm forward
    let c = try #require(try frame([0.4, -1.5, 1.81]))          // 3 mm up (bob)
    let same = try #require(try frame([0.4, -1.5, 1.8]))
    let rows: [(String, CGRect)] = [("near", CGRect(x: 0, y: 360, width: 480, height: 120)),
                                    ("mid", CGRect(x: 0, y: 200, width: 480, height: 120)),
                                    ("far", CGRect(x: 0, y: 60, width: 480, height: 80))]
    for (name, r) in rows {
        print(String(format: "STABILITY %@: repeat %.2f  forward3mm %.2f  up3mm %.2f", name,
                     GrassCompare.meanDifference(a, same, in: r), GrassCompare.meanDifference(a, b, in: r), GrassCompare.meanDifference(a, c, in: r)))
    }
    let tiny = try #require(try frame([0.4, -1.499, 1.8]))     // 0.3 mm forward
    print(String(format: "STABILITY near 0.3mm %.2f (linear motion would be a tenth of the 3 mm figure)",
                 GrassCompare.meanDifference(a, tiny, in: rows[0].1)))
    // Visuals: zoomed crops of a and b, and the absolute difference image.
    let crop = CGRect(x: 160, y: 300, width: 160, height: 120)
    if let ca = a.cropping(to: crop), let cb = b.cropping(to: crop) {
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: 980, height: 360, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .none
        ctx.draw(ca, in: CGRect(x: 0, y: 0, width: 480, height: 360))
        ctx.draw(cb, in: CGRect(x: 500, y: 0, width: 480, height: 360))
        if let out = ctx.makeImage() { GrassCompare.save(out, "stability_pair") }
    }
    let w = a.width, h = a.height
    func bytes(_ img: CGImage) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: &out, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return out
    }
    let pa = bytes(a), pb = bytes(b)
    var d = [UInt8](repeating: 255, count: w * h * 4)
    for i in stride(from: 0, to: d.count, by: 4) {
        let v = min(255, 3 * (abs(Int(pa[i]) - Int(pb[i])) + abs(Int(pa[i+1]) - Int(pb[i+1])) + abs(Int(pa[i+2]) - Int(pb[i+2]))) / 3)
        d[i] = UInt8(v); d[i+1] = UInt8(v); d[i+2] = UInt8(v)
    }
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    if let provider = CGDataProvider(data: Data(d) as CFData),
       let diff = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs,
                          bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) {
        GrassCompare.save(diff, "stability_diff")
    }
}
#endif

#if os(macOS)
/// Motion-compensated temporal residual: frame A is warped onto frame B's camera
/// through the ground plane. A texture anchored to the ground leaves almost no
/// residual; swimming texture, popping blades and real parallax of standing blades do.
@MainActor
@Test func grassFlyoverWarp() throws {
    var ball = GrassStyle.lawn
    ball.stripeContrast = 0.5
    ball.saturation = 1.35
    ball.bladeHeight = 3
    ball.bladeWidth = 0.38
    ball.exposure = 1.3
    ball.grazeBrighten = 0.3
    ball.sheen = 0.25
    ball.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    ball.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    ball.windStrength = 0
    ball.vignette = 0
    switch ProcessInfo.processInfo.environment["GRASS_WARP_VARIANT"] {
    case "nocontrast": ball.contrast = 0; ball.variation = 0
    case "nostripe": ball.stripeContrast = 0
    case "nolight": ball.sheen = 0; ball.grazeBrighten = 0; ball.stripeContrast = 0
    case "flat": ball.contrast = 0; ball.variation = 0; ball.sheen = 0; ball.grazeBrighten = 0; ball.stripeContrast = 0
    default: break
    }
    let size = CGSize(width: 480, height: 480)
    let scale: CGFloat = 1.5
    let ground = GrassGround.feet(pointsPerFoot: 16, origin: .center)
    let control = GrassCompare.controlImage(GrassStripes(angle: .degrees(-90), stripeWidth: 8), ground: ground, size: size, scale: 2)
    guard let device = MTLCreateSystemDefaultDevice() else { return }
    let target = try MetalOffscreenTarget(renderer: try GrassMetalRenderer(device: device))

    func cam(_ t: Double) -> GrassCamera {
        let eye = SIMD3<Double>(0.4 + 0.25 * sin(t * 1.3), -1.5 + 2.0 * t, 1.8 + 0.08 * sin(t * 2.1))
        return .framing(eye: eye, heading: .degrees(3 * sin(t * 0.9)), horizonAt: -0.05, fieldOfView: .degrees(60))
    }
    let camA = cam(1.0), camB = cam(1.0 + 1.0 / 30.0)
    let W = Int(size.width * scale), H = Int(size.height * scale)

    func bytes(_ img: CGImage) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: W * H * 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: &out, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: W, height: H))
        return out
    }
    func luma(_ p: [UInt8], _ x: Int, _ y: Int) -> Double {
        let i = (y * W + x) * 4
        return 0.2126 * Double(p[i]) + 0.7152 * Double(p[i+1]) + 0.0722 * Double(p[i+2])
    }
    func sample(_ p: [UInt8], _ fx: Double, _ fy: Double) -> Double? {
        let x0 = Int(floor(fx)), y0 = Int(floor(fy))
        guard x0 >= 0, y0 >= 0, x0 + 1 < W, y0 + 1 < H else { return nil }
        let tx = fx - Double(x0), ty = fy - Double(y0)
        let a = luma(p, x0, y0), b = luma(p, x0 + 1, y0), c = luma(p, x0, y0 + 1), d = luma(p, x0 + 1, y0 + 1)
        return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    }

    // Self-check of the warp: identical cameras must give ~0, a 0.1 mm step nearly 0.
    for (label, cB) in [("same camera", camA), ("0.1 mm step", cam(1.0 + 1.0 / 60000.0))] {
        var style = ball
        style.shellCount = 0
        let scene = GrassMetalScene(style: style, camera: camA, ground: ground, bladeRange: nil, bladeCount: 0, control: GrassControlImage(control))
        let a = try #require(try target.image(scene, size: size, scale: scale, time: 0).0)
        let sceneB = GrassMetalScene(style: style, camera: cB, ground: ground, bladeRange: nil, bladeCount: 0, control: GrassControlImage(control))
        let b = try #require(try target.image(sceneB, size: size, scale: scale, time: 0).0)
        let pa = bytes(a), pb = bytes(b)
        var res = 0.0, n = 0.0
        for y in 60..<220 { for x in 0..<W {
            let pt = CGPoint(x: (Double(x) + 0.5) / Double(scale), y: (Double(y) + 0.5) / Double(scale))
            guard let g = cB.groundPoint(at: pt, in: size, ground: ground),
                  let pa2 = camA.viewPoint(of: g, in: size, ground: ground),
                  let warped = sample(pa, Double(pa2.x) * Double(scale) - 0.5, Double(pa2.y) * Double(scale) - 0.5) else { continue }
            res += abs(warped - luma(pb, x, y)); n += 1
        } }
        print(String(format: "WARPCHECK %@: band residual %.3f", label, res / max(n, 1)))
    }

    for (label, blades) in [("far field only", false), ("with blades", true)] {
        var style = ball
        if !blades { style.shellCount = 0 }
        func render(_ c: GrassCamera) throws -> CGImage? {
            let scene = GrassMetalScene(style: style, camera: c, ground: ground, bladeRange: blades ? 30 : nil, bladeCount: 400_000,
                                        control: GrassControlImage(control))
            return try target.image(scene, size: size, scale: scale, time: 0).0
        }
        let a = try #require(try render(camA)), b = try #require(try render(camB))
        let pa = bytes(a), pb = bytes(b)
        // Rows in the 720-px frame: far (0-50), handoff band (60-220), near (360-720).
        let bands: [(String, Int, Int)] = [("far", 0, 50), ("band", 60, 220), ("near", 360, 720)]
        var line = "WARP \(label):"
        for (name, y0, y1) in bands {
            var raw = 0.0, res = 0.0, n = 0.0
            // 4x4-block residual: resampling 2-px features blurs them, so the per-pixel
            // residual overstates swim; block means cancel that but keep real change.
            var warpedImg = [Double](repeating: 0, count: W * (y1 - y0))
            var valid = [Bool](repeating: false, count: W * (y1 - y0))
            for y in y0..<y1 { for x in 0..<W {
                let pt = CGPoint(x: (Double(x) + 0.5) / Double(scale), y: (Double(y) + 0.5) / Double(scale))
                guard let g = camB.groundPoint(at: pt, in: size, ground: ground),
                      let pa2 = camA.viewPoint(of: g, in: size, ground: ground),
                      let warped = sample(pa, Double(pa2.x) * Double(scale) - 0.5, Double(pa2.y) * Double(scale) - 0.5) else { continue }
                let lb = luma(pb, x, y)
                res += abs(warped - lb)
                raw += abs(luma(pa, x, y) - lb)
                n += 1
                warpedImg[(y - y0) * W + x] = warped
                valid[(y - y0) * W + x] = true
            } }
            var bres = 0.0, bn = 0.0
            var by = y0
            while by + 4 <= y1 { var bx = 0; while bx + 4 <= W {
                var sw = 0.0, sb = 0.0, ok = true
                for yy in by..<by+4 { for xx in bx..<bx+4 {
                    if !valid[(yy - y0) * W + xx] { ok = false }
                    sw += warpedImg[(yy - y0) * W + xx]; sb += luma(pb, xx, yy)
                } }
                if ok { bres += abs(sw - sb) / 16; bn += 1 }
                bx += 4 }; by += 4 }
            line += String(format: "  %@ raw %.2f -> warped %.2f (4px %.2f)", name, raw / max(n, 1), res / max(n, 1), bres / max(bn, 1))
        }
        print(line)
    }
}
#endif

#if os(macOS)
/// A baseball rolls across striped turf and stops. The turf simulation combs and
/// crushes the blades under it; the Metal renderer reads the simulation each frame.
@MainActor
@Test func grassBallRoll() throws {
    var style = GrassStyle.lawn
    style.stripeContrast = 0.5
    style.saturation = 1.3
    style.vignette = 0.5
    style.bladeHeight = 3
    style.bladeWidth = 0.38
    style.exposure = 1.3
    style.grazeBrighten = 0.3
    style.sheen = 0.25
    style.baseColor = Color(.sRGB, red: 0.06, green: 0.24, blue: 0.05)
    style.tipColor = Color(.sRGB, red: 0.66, green: 0.88, blue: 0.44)
    style.windStrength = 0.08

    let size = CGSize(width: 480, height: 360)
    let scale: CGFloat = 1.4
    let ground = GrassGround.feet(pointsPerFoot: 16, origin: .center)
    let camera = GrassCamera.lookAt(eye: [0, -0.4, 1.0], target: [0, 2.6, 0], fieldOfView: .degrees(58))
    let atmosphere = GrassAtmosphere(fogColor: Color(.sRGB, red: 0.93, green: 0.94, blue: 0.86), fogDistance: 400, desaturationDistance: 0, horizonGlow: 70)
    let stripes = GrassStripes(angle: .degrees(-90), stripeWidth: 8, lean: 0.85)
    let stripeRef = BallparkControl(stripeAngle: .degrees(-90), stripeWidth: 8, lean: 0.85)

    // Simulation over the visible ground only.
    let sim = GrassTurfSimulation(extent: CGRect(x: -8, y: -1, width: 16, height: 10), resolution: 288)
    sim.baseLean = { stripeRef.stripeLean(at: $0, ground: ground, size: size) }
    sim.stiffness = 50
    sim.damping = 10
    sim.recovery = 0.12

    guard let device = MTLCreateSystemDefaultDevice() else { return }
    let target = try MetalOffscreenTarget(renderer: try GrassMetalRenderer(device: device))

    // Ball: radius 1.45 in, rolling +x at 6 ft/s and slowing at 2 ft/s².
    let r = 1.45 / 12.0
    var bx = -3.4, vx = 4.2
    let by = 2.2
    var roll = 0.0
    let fps = 24.0, seconds = 3.4
    let frameCount = Int(fps * seconds)
    var frames: [CGImage] = []
    let W = Int(size.width * scale), H = Int(size.height * scale)

    for i in 0..<frameCount {
        let dt = 1.0 / fps
        let t = Double(i) * dt
        // Physics step.
        if vx > 0 {
            vx = max(vx - 1.5 * dt, 0)
            bx += vx * dt
            roll += vx * dt / r
            sim.roll(at: CGPoint(x: bx, y: by), radius: r * 0.8, velocity: CGVector(dx: vx, dy: 0))
        } else {
            sim.press(at: CGPoint(x: bx, y: by), radius: r * 0.75, strength: 0.6)
        }
        sim.step(dt: dt)

        // Control map: stripes with the simulation on top, as the Metal view does it.
        let control = GrassCompare.controlImage(
            ZStack { stripes; GrassSimulationControl(sim, isRunning: false) },
            ground: ground, size: size, scale: 2)
        let scene = GrassMetalScene(style: style, camera: camera, ground: ground, atmosphere: atmosphere, bladeRange: 30, bladeCount: 400_000,
                                    control: GrassControlImage(control))
        guard let turf = try target.image(scene, size: size, scale: scale, time: t) .0 else { continue }

        // Composite the ball with a contact shadow.
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
        ctx.draw(turf, in: CGRect(x: 0, y: 0, width: W, height: H))
        // CG origin is bottom-left; flip to work in top-left screen coordinates.
        ctx.translateBy(x: 0, y: CGFloat(H)); ctx.scaleBy(x: 1, y: -1)
        let sink = r * 0.35                       // ball settles into the canopy
        let gp = CGPoint(x: bx, y: by)
        if let centre = camera.viewPoint(of: gp, elevation: r - sink, in: size, ground: ground),
           let contact = camera.viewPoint(of: gp, elevation: 0, in: size, ground: ground) {
            let pxPerFt = camera.viewScale(at: gp, in: size, ground: ground)
            let rp = CGFloat(r * pxPerFt) * scale
            let c = CGPoint(x: centre.x * scale, y: centre.y * scale)
            let k = CGPoint(x: contact.x * scale, y: contact.y * scale)
            // Shadow.
            ctx.saveGState()
            ctx.setFillColor(CGColor(red: 0.05, green: 0.12, blue: 0.03, alpha: 0.45))
            ctx.fillEllipse(in: CGRect(x: k.x - rp * 1.3, y: k.y - rp * 0.45, width: rp * 2.6, height: rp * 0.9))
            ctx.restoreGState()
            // Sphere.
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: c.x - rp, y: c.y - rp, width: rp * 2, height: rp * 2))
            ctx.clip()
            let colors = [CGColor(red: 1, green: 1, blue: 0.97, alpha: 1), CGColor(red: 0.82, green: 0.82, blue: 0.78, alpha: 1), CGColor(red: 0.38, green: 0.4, blue: 0.36, alpha: 1)] as CFArray
            let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 0.55, 1])!
            ctx.drawRadialGradient(grad, startCenter: CGPoint(x: c.x - rp * 0.35, y: c.y - rp * 0.4), startRadius: 0,
                                   endCenter: c, endRadius: rp * 1.15, options: [.drawsAfterEndLocation])
            // Stitching: two seam arcs rotating with the roll.
            ctx.setStrokeColor(CGColor(red: 0.72, green: 0.12, blue: 0.1, alpha: 0.9))
            ctx.setLineWidth(max(rp * 0.07, 0.8))
            for s in [-1.0, 1.0] {
                var path = CGMutablePath()
                var first = true
                for j in 0...40 {
                    let a = Double(j) / 40 * .pi            // along the seam
                    // Seam on a unit sphere, rotated about the view-horizontal axis by the roll.
                    var p = SIMD3<Double>(sin(a) * 0.72 * s, cos(a), 0.32 * s)
                    let cr = cos(roll), sr = sin(roll)
                    p = SIMD3(p.x, p.y * cr - p.z * sr, p.y * sr + p.z * cr)
                    guard p.z > 0.05 else { first = true; continue }
                    let q = CGPoint(x: c.x + CGFloat(p.x) * rp, y: c.y - CGFloat(p.y) * rp)
                    if first { path = CGMutablePath(); path.move(to: q); first = false } else { path.addLine(to: q) }
                    if j == 40 || p.z <= 0.05 { ctx.addPath(path); ctx.strokePath() }
                }
                ctx.addPath(path); ctx.strokePath()
            }
            ctx.restoreGState()
        }
        guard let frame = ctx.makeImage() else { continue }
        frames.append(frame)
        if i % 20 == 0 || i == frameCount - 1 { GrassCompare.save(frame, String(format: "roll_%03d", i)) }
    }
    GrassCompare.saveGIF(frames, name: "ballroll", fps: fps)
    print("BALLROLL \(frames.count) frames, ball stopped at x = \(String(format: "%.2f", bx)) ft")
}
#endif
