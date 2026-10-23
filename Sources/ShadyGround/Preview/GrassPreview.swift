//
//  GrassPreview.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/8/25.
//

import SwiftUI

// MARK: - Ballpark control map

/// A control map for a baseball infield and outfield: striped outfield turf,
/// a dirt infield arc, grass inside the diamond, dirt base paths, mound and plate.
///
/// Draw it inside a ``GrassView`` to render it as turf. Home plate sits at
/// the bottom centre of the view.
public struct BallparkControl: View {
    public var stripeAngle: Angle
    public var stripeWidth: Double
    public var lean: Double
    private let turf: AnyView?
    @Environment(\.grassGround) private var ground

    public init(stripeAngle: Angle = .degrees(-90), stripeWidth: Double = 44, lean: Double = 0.85) {
        self.stripeAngle = stripeAngle
        self.stripeWidth = stripeWidth
        self.lean = lean
        self.turf = nil
    }

    /// A ballpark whose turf layer you supply, for example a ``GrassSimulationControl``.
    public init<Turf: View>(stripeAngle: Angle = .degrees(-90), stripeWidth: Double = 44, lean: Double = 0.85, @ViewBuilder turf: () -> Turf) {
        self.stripeAngle = stripeAngle
        self.stripeWidth = stripeWidth
        self.lean = lean
        self.turf = AnyView(turf())
    }

    /// Lean of the outfield stripes at a ground point, matching the bands ``GrassStripes``
    /// draws about the centre of a control view of `size` on `ground`.
    public func stripeLean(at point: CGPoint, ground: GrassGround, size: CGSize) -> CGVector {
        let a = stripeAngle.radians
        let centre = ground.groundPoint(at: CGPoint(x: size.width / 2, y: size.height / 2), in: size)
        // Map-space offset from the view centre (map y runs down).
        let dx = (point.x - centre.x) * ground.pointsPerUnit
        let dy = -(point.y - centre.y) * ground.pointsPerUnit
        let localY = -sin(a) * dx + cos(a) * dy
        let band = Int(floor(localY / max(stripeWidth, 1)))
        let sign: Double = band & 1 == 0 ? 1 : -1
        let dir = CGVector(dx: cos(a), dy: -sin(a))          // map angle -> ground direction
        return CGVector(dx: dir.dx * lean * sign, dy: dir.dy * lean * sign)
    }

    public var body: some View {
        ZStack {
            if let turf {
                turf
            } else {
                GrassStripes(angle: stripeAngle, stripeWidth: stripeWidth, lean: lean)
            }

            // Dirt: infield arc, plate circle, warning track. Drawn with destination-out
            // so the canvas removes coverage from the stripes beneath it.
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                let g = Geometry(size: size, ground: ground)
                var dirt = Path()
                dirt.move(to: g.plate)
                dirt.addLine(to: g.rightEnd)
                dirt.addLines(g.arc(center: g.mound, radius: 95, from: g.aRight, to: g.aLeft))
                dirt.addLine(to: g.plate)
                dirt.closeSubpath()
                context.fill(dirt, with: .color(.black))

                var track = Path()
                track.addLines(g.arc(center: g.plate, radius: 345, from: .pi / 4, to: 3 * .pi / 4))
                track.addLines(g.arc(center: g.plate, radius: 330, from: 3 * .pi / 4, to: .pi / 4))
                track.closeSubpath()
                context.fill(track, with: .color(.black))
            }
            .blendMode(.destinationOut)

            // Grass inside the diamond, mown across the outfield stripes.
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                let g = Geometry(size: size, ground: ground)
                context.fill(g.diamond, with: .color(
                    GrassControl.color(angle: stripeAngle + .degrees(90), lean: lean * 0.9)
                ))
            }

            // Base paths, mound and bases cut back out of the diamond.
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                let g = Geometry(size: size, ground: ground)
                context.stroke(g.diamond, with: .color(.black), lineWidth: 6 * g.scale)
                var details = Path()
                details.addEllipse(in: g.circle(at: g.plate, radius: 13))
                details.addEllipse(in: g.circle(at: g.mound, radius: 9))
                for base in [g.first, g.second, g.third] {
                    details.addEllipse(in: g.circle(at: base, radius: 7))
                }
                context.fill(details, with: .color(.black))
            }
            .blendMode(.destinationOut)
        }
    }

    /// Field geometry in feet, home plate at the bottom centre, y up the field.
    private struct Geometry {
        let scale: Double
        let home: CGPoint
        let plate: CGPoint
        let mound: CGPoint
        let first: CGPoint
        let second: CGPoint
        let third: CGPoint
        let rightEnd: CGPoint
        let leftEnd: CGPoint
        let aRight: Double
        let aLeft: Double

        init(size: CGSize, ground: GrassGround?) {
            if let ground, ground.unit == .feet {
                scale = ground.pointsPerUnit
                home = ground.originPoint(in: size)
            } else {
                scale = min(Double(size.width) / 300, (Double(size.height) - 40) / 360)
                home = CGPoint(x: size.width / 2, y: size.height - 24)
            }
            func pt(_ x: Double, _ y: Double, _ home: CGPoint, _ scale: Double) -> CGPoint {
                CGPoint(x: home.x + x * scale, y: home.y - y * scale)
            }
            let r2 = 2.0.squareRoot()
            plate = pt(0, 0, home, scale)
            mound = pt(0, 60.5, home, scale)
            first = pt(90 / r2, 90 / r2, home, scale)
            second = pt(0, 90 * r2, home, scale)
            third = pt(-90 / r2, 90 / r2, home, scale)
            // The 95 ft infield arc meets the foul lines 127.6 ft from the plate.
            let reach = 127.6
            rightEnd = pt(reach / r2, reach / r2, home, scale)
            leftEnd = pt(-reach / r2, reach / r2, home, scale)
            aRight = atan2(Double(mound.y - rightEnd.y), Double(rightEnd.x - mound.x))
            aLeft = atan2(Double(mound.y - leftEnd.y), Double(leftEnd.x - mound.x))
        }

        var diamond: Path {
            var p = Path()
            p.move(to: plate)
            p.addLine(to: first)
            p.addLine(to: second)
            p.addLine(to: third)
            p.closeSubpath()
            return p
        }

        func circle(at c: CGPoint, radius: Double) -> CGRect {
            CGRect(x: c.x - radius * scale, y: c.y - radius * scale, width: radius * 2 * scale, height: radius * 2 * scale)
        }

        func arc(center: CGPoint, radius: Double, from a0: Double, to a1: Double, steps: Int = 64) -> [CGPoint] {
            (0...steps).map { i in
                let a = a0 + (a1 - a0) * Double(i) / Double(steps)
                return CGPoint(x: center.x + cos(a) * radius * scale, y: center.y - sin(a) * radius * scale)
            }
        }
    }
}

// MARK: - Preview

extension GrassView {
    public static func previewView() -> some View {
        GrassPreview()
    }
}

@MainActor
public struct GrassPreview: View {
    private enum Pattern: String, CaseIterable, Identifiable {
        case ballpark = "Ballpark"
        case stripes = "Stripes"
        case checkerboard = "Checkerboard"
        case crosshatch = "Crosshatch"
        case rings = "Rings"
        case worn = "Worn Path"
        case rollingBall = "Rolling Ball"
        var id: String { rawValue }
    }

    private enum Preset: String, CaseIterable, Identifiable {
        case ballpark = "Ballpark"
        case lawn = "Lawn"
        case nightGame = "Night Game"
        case golfGreen = "Golf Green"
        case meadow = "Meadow"
        case dry = "Dry"
        case artificial = "Artificial"
        var id: String { rawValue }

        var style: GrassStyle {
            switch self {
            case .ballpark: .ballpark
            case .lawn: .lawn
            case .nightGame: .nightGame
            case .golfGreen: .golfGreen
            case .meadow: .meadow
            case .dry: .dry
            case .artificial: .artificial
            }
        }
    }

    private enum View3D: String, CaseIterable, Identifiable {
        case topDown = "Top Down"
        case plate = "Behind Plate"
        case outfield = "Outfield"
        case ballCam = "Ball Cam"
        case flyover = "Flyover"
        var id: String { rawValue }

        /// Camera at a moment in time; only the flyover moves.
        func camera(at t: Double) -> GrassCamera {
            switch self {
            case .flyover:
                let eye = SIMD3<Double>(0.4 + 0.25 * sin(t * 1.3), -1.5 + 2.0 * t, 1.8 + 0.08 * sin(t * 2.1))
                return .framing(eye: eye, heading: .degrees(3 * sin(t * 0.9)), horizonAt: -0.05, fieldOfView: .degrees(60))
            default:
                return camera
            }
        }

        var camera: GrassCamera {
            switch self {
            case .topDown: .topDown
            case .plate: .framing(eye: [0, -18, 4.5], horizonAt: 0.4, fieldOfView: .degrees(60))
            case .outfield: .framing(eye: [40, 150, 5], heading: .degrees(200), horizonAt: 0.15, fieldOfView: .degrees(50))
            case .ballCam: .framing(eye: [10, 120, 1], heading: .degrees(190), horizonAt: -0.05, fieldOfView: .degrees(60))
            case .flyover: .framing(eye: [0.4, -1.5, 1.8], horizonAt: -0.05, fieldOfView: .degrees(60))
            }
        }
    }

    @State private var pattern: Pattern = .ballpark
    @State private var preset: Preset = .ballpark
    @State private var view3D: View3D = .plate
    private enum RendererKind: String, CaseIterable, Identifiable {
        case shader = "Shader"
        case hybrid = "Hybrid"
        case metal = "Metal"
        var id: String { rawValue }
    }
    @State private var rendererKind: RendererKind = .shader
    @State private var simulation = GrassTurfSimulation(extent: CGRect(x: -160, y: 140, width: 320, height: 130), resolution: 320)
    @State private var ballStart = Date()
    @State private var stripeAngle: Double = 3 * .pi / 2
    @State private var stripeWidth: CGFloat = 44
    @State private var lean: CGFloat = 0.85
    @State private var height: CGFloat = 0.3
    @State private var stripeContrast: CGFloat = 0.45
    @State private var bladeWidth: CGFloat = 0.35
    @State private var sheen: CGFloat = 0.35
    @State private var windStrength: CGFloat = 0
    @State private var variation: CGFloat = 0.12

    private var style: GrassStyle {
        var s = preset.style
        s.stripeContrast = stripeContrast
        s.bladeWidth = bladeWidth
        s.sheen = sheen
        s.windStrength = windStrength
        s.variation = variation
        return s
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
              TimelineView(.animation(paused: view3D != .flyover)) { timeline in
                let ground: GrassGround = view3D == .topDown && pattern != .rollingBall ? .screen
                    : pattern == .rollingBall ? .feet(pointsPerFoot: 1, origin: UnitPoint(x: 0.5, y: 0.95))
                    : view3D == .flyover ? .feet(pointsPerFoot: 16, origin: .center)
                    : .feet(pointsPerFoot: 2)
                let camera = view3D.camera(at: timeline.date.timeIntervalSince(ballStart))
                ZStack {
                    if rendererKind == .metal {
                        GrassMetalView(
                            style: style,
                            camera: camera,
                            ground: ground,
                            atmosphere: view3D == .topDown ? .none : .haze(distance: 160),
                            bladeRange: view3D == .topDown ? nil : 40,
                            control: .view(AnyView(control), refresh: pattern == .rollingBall ? simulation.generation / 2 : 0)
                        )
                    } else if rendererKind == .hybrid && view3D != .topDown {
                        GrassHybridView(
                            style: style,
                            camera: camera,
                            ground: ground,
                            atmosphere: .haze(distance: 160),
                            bladeRange: 40
                        ) {
                            control
                        }
                    } else {
                        GrassView(
                            style: style,
                            camera: camera,
                            ground: ground,
                            atmosphere: view3D == .topDown ? .none : .haze(distance: 160)
                        ) {
                            control
                        }
                    }
                    if pattern == .rollingBall {
                        RollingBallOverlay(simulation: simulation, start: ballStart, camera: camera, ground: ground, size: geo.size)
                    }
                }
                .onChange(of: view3D) { _, newValue in
                    if newValue == .flyover { ballStart = Date() }
                }
                .onChange(of: pattern, initial: true) { _, newValue in
                    guard newValue == .rollingBall else { return }
                    let map = BallparkControl(stripeAngle: Angle.radians(stripeAngle), stripeWidth: stripeWidth, lean: lean)
                    let size = geo.size
                    simulation.baseLean = { map.stripeLean(at: $0, ground: ground, size: size) }
                    ballStart = Date()
                }
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        guard pattern == .rollingBall,
                              let p = camera.groundPoint(at: value.location, in: geo.size, ground: ground) else { return }
                        simulation.press(at: p, radius: 2.5, strength: 0.8)
                    }
                )
              }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            VStack(spacing: 12) {
                HStack {
                    Picker("Pattern", selection: $pattern) {
                        ForEach(Pattern.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Style", selection: $preset) {
                        ForEach(Preset.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Camera", selection: $view3D) {
                        ForEach(View3D.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Renderer", selection: $rendererKind) {
                        ForEach(RendererKind.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: preset) { _, newValue in
                    let s = newValue.style
                    stripeContrast = s.stripeContrast
                    bladeWidth = s.bladeWidth
                    sheen = s.sheen
                    windStrength = s.windStrength
                    variation = s.variation
                }

                ParameterControlGrid {
                    AngleParameterControl(title: "Mow Angle", value: $stripeAngle)
                    NumericParameterControl(title: "Stripe Width (pt)", value: $stripeWidth, in: 8...160, step: 2)
                    NumericParameterControl(title: "Lean", value: $lean, in: 0...1, step: 0.05)
                    NumericParameterControl(title: "Height", value: $height, in: 0...1, step: 0.05)
                    NumericParameterControl(title: "Stripe Contrast", value: $stripeContrast, in: 0...1, step: 0.05)
                    NumericParameterControl(title: "Blade Width (cm)", value: $bladeWidth, in: 0.1...1.5, step: 0.05)
                    NumericParameterControl(title: "Sheen", value: $sheen, in: 0...1, step: 0.05)
                    NumericParameterControl(title: "Wind", value: $windStrength, in: 0...1, step: 0.05)
                    NumericParameterControl(title: "Dry Patches", value: $variation, in: 0...1, step: 0.05)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var control: some View {
        let angle = Angle.radians(stripeAngle)
        switch pattern {
        case .ballpark:
            BallparkControl(stripeAngle: angle, stripeWidth: stripeWidth, lean: lean)
        case .stripes:
            GrassStripes(angle: angle, stripeWidth: stripeWidth, lean: lean, height: height)
        case .checkerboard:
            GrassCheckerboard(angle: angle, cellSize: stripeWidth, lean: lean, height: height)
        case .crosshatch:
            BallparkControl(stripeAngle: angle, stripeWidth: stripeWidth, lean: lean) {
                GrassCrosshatch(angle: angle + .degrees(28), secondAngle: angle - .degrees(28), stripeWidth: stripeWidth, lean: lean * 0.7, height: height)
            }
        case .rings:
            GrassRings(center: .center, ringWidth: stripeWidth, lean: lean, height: height)
        case .rollingBall:
            BallparkControl(stripeAngle: angle, stripeWidth: stripeWidth, lean: lean) {
                ZStack {
                    GrassStripes(angle: angle, stripeWidth: stripeWidth, lean: lean)
                    GrassSimulationControl(simulation)
                }
            }
        case .worn:
            ZStack {
                GrassStripes(angle: angle, stripeWidth: stripeWidth, lean: lean, height: height)
                Capsule()
                    .frame(width: 70)
                    .padding(.vertical, 40)
                    .grassWear(0.75)
                Circle()
                    .frame(width: 120)
                    .offset(x: 140, y: -80)
                    .grassWear(1)
            }
        }
    }
}

/// Rolls a ball across the outfield on a loop, combing the simulated turf and drawing the ball.
private struct RollingBallOverlay: View {
    let simulation: GrassTurfSimulation
    let start: Date
    let camera: GrassCamera
    let ground: GrassGround
    let size: CGSize
    @State private var lastPosition: CGPoint?

    private func position(at t: Double) -> CGPoint {
        // A lazy S-curve across the outfield, 16 seconds per lap.
        let u = (t / 16).truncatingRemainder(dividingBy: 1)
        let x = -140 + 280 * u
        let y = 150 + 60 * sin(u * .pi * 2) + 40 * u
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(start)
            let p = position(at: t)
            Canvas { gc, _ in
                guard let screen = camera.viewPoint(of: p, elevation: 0.12, in: size, ground: ground) else { return }
                let r = max(camera.viewScale(at: p, in: size, ground: ground) * 0.12, 2)
                gc.fill(Path(ellipseIn: CGRect(x: screen.x - r, y: screen.y - r, width: r * 2, height: r * 2)), with: .color(.white))
                gc.stroke(Path(ellipseIn: CGRect(x: screen.x - r, y: screen.y - r, width: r * 2, height: r * 2)), with: .color(.red.opacity(0.6)), lineWidth: max(r * 0.12, 0.5))
            }
            .onChange(of: context.date, initial: true) { _, _ in
                let v = lastPosition.map { CGVector(dx: p.x - $0.x, dy: p.y - $0.y) } ?? .zero
                simulation.roll(at: p, radius: 0.1, velocity: v)
                lastPosition = p
            }
        }
        .allowsHitTesting(false)
    }
}

#Preview("Grass") {
    GrassPreview()
        .frame(width: 800, height: 900)
}
