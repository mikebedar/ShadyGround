// Render smoke tests for the metal materials: every preset through MetalOffscreenTarget,
// plus a few checks that the finishes and the animation do what they say.
import Testing
import SwiftUI
import Metal
@testable import ShadyGround

/// RGBA8 pixels of a rendered frame.
private struct Pixels {
    let width: Int, height: Int
    let bytes: [UInt8]

    init?(_ image: CGImage?) {
        guard let image else { return nil }
        width = image.width
        height = image.height
        var buf = [UInt8](repeating: 0, count: width * height * 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        guard let ctx = CGContext(data: &buf, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = buf
    }

    func rgba(_ x: Int, _ y: Int) -> SIMD4<Double> {
        let i = (y * width + x) * 4
        return SIMD4(Double(bytes[i]), Double(bytes[i + 1]), Double(bytes[i + 2]), Double(bytes[i + 3])) / 255
    }

    func luma(_ x: Int, _ y: Int) -> Double {
        let p = rgba(x, y)
        return 0.2126 * p.x + 0.7152 * p.y + 0.0722 * p.z
    }

    var mean: SIMD4<Double> {
        var sum = SIMD4<Double>()
        for y in 0..<height { for x in 0..<width { sum += rgba(x, y) } }
        return sum / Double(width * height)
    }

    var lumaDeviation: Double {
        let values = (0..<height).flatMap { y in (0..<width).map { x in luma(x, y) } }
        let m = values.reduce(0, +) / Double(values.count)
        return (values.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(values.count)).squareRoot()
    }

    /// Mean absolute luminance step between neighbours along x (`dx`) or y.
    func meanStep(alongX: Bool) -> Double {
        var sum = 0.0, n = 0
        for y in 0..<(height - 1) {
            for x in 0..<(width - 1) {
                sum += abs(luma(x, y) - (alongX ? luma(x + 1, y) : luma(x, y + 1)))
                n += 1
            }
        }
        return sum / Double(n)
    }
}

@MainActor
@Suite(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "needs a Metal device"))
struct MetalMaterialTests {
    let target: MetalOffscreenTarget<MetalMaterialRenderer>
    static let size = CGSize(width: 96, height: 64)

    init() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())
        target = try MetalOffscreenTarget(renderer: MetalMaterialRenderer(device: device))
    }

    private func render(_ material: MetalMaterial, time: Double = 0, light: SIMD3<Float> = MetalMaterialScene.defaultLight) throws -> Pixels {
        let (image, _) = try target.image(MetalMaterialScene(material: material, lightDirection: light),
                                          size: Self.size, scale: 2, time: time)
        return try #require(Pixels(image))
    }

    @Test(arguments: MetalMaterial.presets)
    func presetRenders(_ material: MetalMaterial) throws {
        let px = try render(material)
        #expect(px.width == 192 && px.height == 128)
        let mean = px.mean
        #expect(mean.w > 0.99, "opaque")
        let luma = 0.2126 * mean.x + 0.7152 * mean.y + 0.0722 * mean.z
        #expect(luma > 0.05 && luma < 0.95, "\(material.name): mean luminance \(luma)")
        #expect(px.lumaDeviation > 0.01, "\(material.name): a lit surface, not a flat colour")
    }

    @Test func goldIsWarmAndSilverIsNeutral() throws {
        let gold = try render(.gold).mean
        let silver = try render(.silver).mean
        #expect(gold.x > gold.z + 0.15)
        #expect(abs(silver.x - silver.z) < 0.08)
    }

    @Test func patinaShowsVerdigris() throws {
        let copper = try render(.copperPatina)
        var green = 0
        for y in 0..<copper.height { for x in 0..<copper.width {
            let p = copper.rgba(x, y)
            if p.y > p.x { green += 1 }
        } }
        #expect(green > copper.width * copper.height / 20, "\(green) green pixels")
    }

    @Test func brushedStreaksRunAlongX() throws {
        let px = try render(.brushedAluminum)
        #expect(px.meanStep(alongX: false) > px.meanStep(alongX: true) * 1.5)
    }

    @Test func staticFramesAreDeterministic() throws {
        let a = try render(.polishedSteel)
        let b = try render(.polishedSteel)
        #expect(a.bytes == b.bytes)
    }

    @Test func timeMovesTheHighlight() throws {
        let still = try render(.polishedSteel, time: 0)
        let moved = try render(.polishedSteel, time: 2)
        #expect(still.bytes != moved.bytes)
    }

    @Test func lightDirectionMovesTheHighlight() throws {
        let left = try render(.gold, light: [-0.6, 0.2, 0.7])
        let right = try render(.gold, light: [0.6, 0.2, 0.7])
        func leftHalfBrighter(_ p: Pixels) -> Bool {
            var l = 0.0, r = 0.0
            for y in 0..<p.height { for x in 0..<p.width { if x < p.width / 2 { l += p.luma(x, y) } else { r += p.luma(x, y) } } }
            return l > r
        }
        #expect(leftHalfBrighter(left))
        #expect(!leftHalfBrighter(right))
    }

    @Test func zeroLightDirectionFallsBack() throws {
        let px = try render(.titanium, light: .zero)
        #expect(px.lumaDeviation > 0.01)
    }

    /// Writes every preset to the harness folder for a look (never fails on content).
    @Test func contactSheet() throws {
        let dir = HarnessPaths.directory("materials")
        for material in MetalMaterial.presets {
            let (image, _) = try target.image(MetalMaterialScene(material: material), size: CGSize(width: 240, height: 160), scale: 2)
            let image_ = try #require(image)
            let url = URL(fileURLWithPath: "\(dir)/\(material.name.replacingOccurrences(of: " ", with: "-")).png")
            let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(dest, image_, nil)
            #expect(CGImageDestinationFinalize(dest))
        }
    }
}
