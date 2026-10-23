import Testing
import SwiftUI
@testable import ShadyGround

@MainActor
@Test func simulationTrailRecoversAndEncodes() throws {
    let sim = GrassTurfSimulation(extent: CGRect(x: -10, y: -10, width: 20, height: 20), resolution: 40)
    sim.roll(at: CGPoint(x: 0, y: 0), radius: 1, velocity: CGVector(dx: 1, dy: 0))
    sim.step(dt: 1.0 / 60.0)
    let pushed = try #require(sim.image)
    #expect(pushed.width == 40 && pushed.height == 40)

    // Centre pixel should encode lean along +x (red above 0.5) right after the push.
    func centre(_ cg: CGImage) -> (r: Int, g: Int, b: Int) {
        var bytes = [UInt8](repeating: 0, count: 4)
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: &bytes, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .none
        ctx.draw(cg, in: CGRect(x: -19.5, y: -19.5, width: 40, height: 40))
        return (Int(bytes[0]), Int(bytes[1]), Int(bytes[2]))
    }
    let c0 = centre(pushed)
    #expect(c0.r > 140, "lean should point along +x")

    for _ in 0..<600 { sim.step(dt: 1.0 / 60.0) }
    let c1 = centre(try #require(sim.image))
    #expect(abs(c1.r - 128) < 12 && abs(c1.g - 128) < 12, "lean should recover toward upright")

    // Rough cost: 160x147 grid, 60 steps with an image each.
    let big = GrassTurfSimulation(extent: CGRect(x: -250, y: -40, width: 500, height: 460), resolution: 160)
    let start = Date()
    for _ in 0..<60 { big.step(dt: 1.0 / 60.0); _ = big.image }
    print(String(format: "SIMTIME %.2f ms per step+encode (debug build)", Date().timeIntervalSince(start) / 60 * 1000))
}
