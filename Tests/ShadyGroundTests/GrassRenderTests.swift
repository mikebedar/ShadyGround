import Testing
import SwiftUI
@testable import ShadyGround

@Test func grassControlEncodesChannels() throws {
    let c = GrassControl.color(lean: CGVector(dx: 1, dy: -0.5), height: 0.25, coverage: 0.5)
    let resolved = c.resolve(in: EnvironmentValues())
    #expect(abs(resolved.red - 1.0) < 0.01)
    #expect(abs(resolved.green - 0.25) < 0.01)
    #expect(abs(resolved.blue - 0.25) < 0.01)
    #expect(abs(resolved.opacity - 0.5) < 0.01)
}

#if os(macOS)
@MainActor
private func centrePixel<V: View>(_ view: V) -> (r: Int, g: Int, b: Int, a: Int)? {
    let renderer = ImageRenderer(content: view.frame(width: 64, height: 64))
    renderer.scale = 1
    guard let cg = renderer.cgImage else { return nil }
    var bytes = [UInt8](repeating: 0, count: 4)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.draw(cg, in: CGRect(x: -32, y: -32, width: 64, height: 64))
    return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]), Int(bytes[3]))
}

@MainActor
@Test func grassRendersTurfAndSoil() throws {
    let turf = try #require(centrePixel(GrassView(style: .ballpark)))
    #expect(turf.g > turf.r && turf.g > turf.b, "full coverage should be green")
    #expect(turf.a == 255)

    let soil = try #require(centrePixel(GrassView(style: .ballpark, coverage: 0)))
    #expect(soil.r > soil.g && soil.g > soil.b, "zero coverage should show brown soil")
    #expect(soil.a == 255)

    var seeThrough = GrassStyle.ballpark
    seeThrough.soilColor = .clear
    let clear = try #require(centrePixel(GrassView(style: seeThrough, coverage: 0)))
    #expect(clear.a == 0, "transparent soil should let the background through")
}
#endif
