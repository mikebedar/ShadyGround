//
//  GrassSimulation.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/9/25.
//
//  A spring-damper turf simulation that writes lean and height into a GrassView
//  control map, so anything that touches the lawn leaves a recovering mark.
//

import SwiftUI
import CoreGraphics
import simd

// MARK: - Simulation

/// A grid of blade clumps, each with a lean that springs back after being pushed.
///
/// Create one over a ground rectangle, push on it with ``press(at:radius:direction:strength:)``
/// or ``roll(at:radius:velocity:)``, and draw it into a ``GrassView`` with
/// ``GrassSimulationControl``. Each clump has two lean components: a springy one
/// that oscillates back within a second, and a *set* that recovers slowly, which
/// is what makes a trail stay visible after a ball has rolled through.
///
/// Positions are in ground units (the same units as the view's ``GrassGround``),
/// with x to the right and y up the map.
@MainActor
@Observable
public final class GrassTurfSimulation {

    /// Ground rectangle the grid covers.
    public let extent: CGRect
    public let columns: Int
    public let rows: Int

    /// Spring constant pulling lean back to the base pattern.
    public var stiffness: Float = 40
    /// Velocity damping. Below about `2 * sqrt(stiffness)` the grass bounces back.
    public var damping: Float = 9
    /// How fast trampled set recovers, in fractions per second.
    public var recovery: Float = 0.35
    /// Blade height written where nothing has crushed the turf.
    public var baseHeight: Double = GrassControl.defaultHeight {
        didSet { dirty = true }
    }

    /// The mow pattern underneath the simulation, as lean per ground point.
    public var baseLean: @MainActor (CGPoint) -> CGVector {
        didSet { rebuildBase() }
    }

    /// The control map image, encoded on demand after changes.
    public var image: CGImage? {
        if dirty { encode() }
        return cached
    }

    @ObservationIgnored private var cached: CGImage?
    @ObservationIgnored private var dirty = true
    @ObservationIgnored private var base: [SIMD2<Float>]
    @ObservationIgnored private var lean: [SIMD2<Float>]
    @ObservationIgnored private var velocity: [SIMD2<Float>]
    @ObservationIgnored private var set: [SIMD2<Float>]
    @ObservationIgnored private var crush: [Float]
    @ObservationIgnored private var pixels: [UInt8]
    @ObservationIgnored private var lastDate: Date?
    /// Bumped by every step so observers redraw.
    public private(set) var generation: Int = 0

    /// - Parameters:
    ///   - extent: Ground rectangle to simulate, in ground units.
    ///   - resolution: Cells across the extent; rows follow the aspect ratio.
    ///   - baseLean: Mow pattern under the simulation. Defaults to upright.
    public init(
        extent: CGRect,
        resolution: Int = 96,
        baseLean: @escaping @MainActor (CGPoint) -> CGVector = { _ in .zero }
    ) {
        self.extent = extent
        self.columns = max(resolution, 2)
        self.rows = max(Int((Double(resolution) * extent.height / max(extent.width, 1e-6)).rounded()), 2)
        self.baseLean = baseLean
        let count = columns * rows
        base = Array(repeating: .zero, count: count)
        lean = Array(repeating: .zero, count: count)
        velocity = Array(repeating: .zero, count: count)
        set = Array(repeating: .zero, count: count)
        crush = Array(repeating: 0, count: count)
        pixels = Array(repeating: 0, count: count * 4)
        rebuildBase()
    }

    // MARK: Interaction

    /// Pushes the turf down around a point, as a footstep or a resting object does.
    /// - Parameters:
    ///   - point: Ground position.
    ///   - radius: Radius of the contact, in ground units.
    ///   - direction: Lean imparted along a direction, for example the direction of travel.
    ///   - strength: 0...1, how hard the contact is.
    public func press(at point: CGPoint, radius: Double, direction: CGVector = .zero, strength: Double = 1) {
        apply(at: point, radius: radius, direction: direction, strength: strength, setGain: 0.8, springGain: 0.6)
    }

    /// Rolls an object across the turf. Call every step while it moves; the blades
    /// are combed along the velocity and parted outward.
    /// `radius` is the contact patch, not the object: a ball sunk a third of its
    /// radius into the canopy touches a patch of about three quarters of its radius.
    /// Nothing ahead of the contact is disturbed; the comb trails the object.
    public func roll(at point: CGPoint, radius: Double, velocity: CGVector) {
        let speed = (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot()
        let dir = speed > 1e-6 ? CGVector(dx: velocity.dx / speed, dy: velocity.dy / speed) : .zero
        // Centre the push slightly behind the object so the leading edge stays clean.
        let back = CGPoint(x: point.x - dir.dx * radius * 0.35, y: point.y - dir.dy * radius * 0.35)
        apply(at: back, radius: radius, direction: dir, strength: 1, setGain: 0.9, springGain: 0.5, sharp: true)
    }

    private func apply(at point: CGPoint, radius: Double, direction: CGVector, strength: Double, setGain: Double, springGain: Double, sharp: Bool = false) {
        guard radius > 0 else { return }
        let cw = extent.width / Double(columns)
        let ch = extent.height / Double(rows)
        // A contact smaller than a cell must still reach the cell it is in.
        let radius = max(radius, 0.8 * max(cw, ch))
        let c0 = max(Int((point.x - radius - extent.minX) / cw), 0)
        let c1 = min(Int((point.x + radius - extent.minX) / cw), columns - 1)
        let r0 = max(Int((extent.maxY - point.y - radius) / ch), 0)
        let r1 = min(Int((extent.maxY - point.y + radius) / ch), rows - 1)
        guard c0 <= c1, r0 <= r1 else { return }
        let s = Float(min(max(strength, 0), 1))
        let d = SIMD2<Float>(Float(direction.dx), Float(direction.dy))
        let sg = Float(setGain), lg = Float(springGain)
        let cols = columns

        set.withUnsafeMutableBufferPointer { set in
            lean.withUnsafeMutableBufferPointer { lean in
                crush.withUnsafeMutableBufferPointer { crush in
                    for r in r0...r1 {
                        let y = extent.maxY - (Double(r) + 0.5) * ch
                        for c in c0...c1 {
                            let x = extent.minX + (Double(c) + 0.5) * cw
                            let dx = Float(x - point.x), dy = Float(y - point.y)
                            let dist = (dx * dx + dy * dy).squareRoot()
                            let rad = Float(radius)
                            guard dist < rad else { continue }
                            // A sharp contact is flat inside and drops fast at the edge; a press
                            // (foot, resting object) spreads further.
                            let edge = 1 - dist / rad
                            let falloff = sharp ? min(edge * 2.5, 1) : edge.squareRoot()
                            let radial = dist > 1e-6 ? SIMD2<Float>(dx / dist, dy / dist) : .zero
                            let push = (radial * 0.7 + d) * falloff * s
                            let i = r * cols + c
                            set[i] = Self.clampLength(set[i] + push * sg, 1)
                            lean[i] = Self.clampLength(lean[i] + push * lg, 1)
                            crush[i] = max(crush[i], falloff * s)
                        }
                    }
                }
            }
        }
        dirty = true
        generation &+= 1
    }

    // MARK: Stepping

    /// Advances the simulation to a date, stepping by the elapsed time. Use from a
    /// `TimelineView`; the first call only records the date.
    public func advance(to date: Date) {
        defer { lastDate = date }
        guard let last = lastDate else { return }
        let dt = min(max(date.timeIntervalSince(last), 0), 0.1)
        if dt > 0 { step(dt: dt) }
    }

    /// Advances the simulation by `dt` seconds.
    public func step(dt: Double) {
        let k = stiffness, c = damping, h = Float(dt)
        let setDecay = exp(-recovery * h)
        let crushDecay = exp(-recovery * 0.6 * h)
        let n = lean.count
        lean.withUnsafeMutableBufferPointer { lean in
            velocity.withUnsafeMutableBufferPointer { velocity in
                set.withUnsafeMutableBufferPointer { set in
                    crush.withUnsafeMutableBufferPointer { crush in
                        for i in 0..<n {
                            let a = -k * lean[i] - c * velocity[i]
                            velocity[i] += a * h
                            lean[i] += velocity[i] * h
                            set[i] *= setDecay
                            crush[i] *= crushDecay
                        }
                    }
                }
            }
        }
        dirty = true
        generation &+= 1
    }

    private func rebuildBase() {
        let cw = extent.width / Double(columns)
        let ch = extent.height / Double(rows)
        for r in 0..<rows {
            let y = extent.maxY - (Double(r) + 0.5) * ch
            for c in 0..<columns {
                let x = extent.minX + (Double(c) + 0.5) * cw
                let v = baseLean(CGPoint(x: x, y: y))
                base[r * columns + c] = Self.clampLength(SIMD2<Float>(Float(v.dx), Float(v.dy)), 1)
            }
        }
        dirty = true
        generation &+= 1
    }

    private func encode() {
        let height = Float(baseHeight)
        let n = lean.count
        pixels.withUnsafeMutableBufferPointer { px in
            base.withUnsafeBufferPointer { base in
                lean.withUnsafeBufferPointer { lean in
                    set.withUnsafeBufferPointer { set in
                        crush.withUnsafeBufferPointer { crush in
                            for i in 0..<n {
                                var total = base[i] + lean[i] + set[i]
                                total = simd_clamp(total, SIMD2<Float>(repeating: -1), SIMD2<Float>(repeating: 1))
                                let h = height * (1 - 0.85 * crush[i])
                                let p = i * 4
                                px[p] = UInt8((0.5 + 0.5 * total.x) * 255 + 0.5)
                                // Map green encodes lean down the map; ground y points up the map.
                                px[p + 1] = UInt8((0.5 - 0.5 * total.y) * 255 + 0.5)
                                px[p + 2] = UInt8(min(max(h, 0), 1) * 255 + 0.5)
                                px[p + 3] = 255
                            }
                        }
                    }
                }
            }
        }
        let data = Data(pixels)
        guard let provider = CGDataProvider(data: data as CFData),
              let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        cached = CGImage(
            width: columns, height: rows, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: columns * 4,
            space: cs, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
        dirty = false
    }

    private static func clampLength(_ v: SIMD2<Float>, _ maxLength: Float) -> SIMD2<Float> {
        let l2 = v.x * v.x + v.y * v.y
        return l2 > maxLength * maxLength ? v * (maxLength / l2.squareRoot()) : v
    }
}

// MARK: - Control map view

/// Draws a ``GrassTurfSimulation`` into a ``GrassView`` control map and, by
/// default, keeps it stepping every frame.
///
/// Place it where the turf goes and overlay dirt with ``SwiftUICore/View/grassWear(_:)``
/// as usual. The simulation's extent is positioned through the view's ``GrassGround``;
/// outside a grass view it fills the whole frame.
public struct GrassSimulationControl: View {
    private let simulation: GrassTurfSimulation
    private let isRunning: Bool
    @Environment(\.grassGround) private var ground

    /// - Parameters:
    ///   - simulation: The simulation to draw.
    ///   - isRunning: When `true`, the view advances the simulation every frame.
    public init(_ simulation: GrassTurfSimulation, isRunning: Bool = true) {
        self.simulation = simulation
        self.isRunning = isRunning
    }

    public var body: some View {
        if isRunning {
            TimelineView(.animation) { context in
                map.onChange(of: context.date, initial: true) { _, date in
                    simulation.advance(to: date)
                }
            }
        } else {
            map
        }
    }

    private var map: some View {
        let _ = simulation.generation
        return Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            guard let cg = simulation.image else { return }
            let rect: CGRect
            if let ground {
                let topLeft = ground.point(x: simulation.extent.minX, y: simulation.extent.maxY, in: size)
                rect = CGRect(x: topLeft.x, y: topLeft.y,
                              width: ground.length(simulation.extent.width),
                              height: ground.length(simulation.extent.height))
            } else {
                rect = CGRect(origin: .zero, size: size)
            }
            let image = Image(decorative: cg, scale: 1).interpolation(.high)
            context.draw(image, in: rect)
        }
    }
}
