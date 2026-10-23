//
//  GrassControl.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/8/25.
//

import SwiftUI

// MARK: - Encoding

/// Encodes grass control values into colours for a ``GrassView`` control map.
///
/// | Channel | Meaning |
/// |---|---|
/// | R, G | Lean: `0.5 + 0.5 * lean`, so (0.5, 0.5) is upright |
/// | B | Height, 0...1 |
/// | A | Coverage, 0 is bare soil |
public enum GrassControl {

    /// Height written by the helpers when none is given: a regularly mown lawn.
    public static let defaultHeight: Double = 0.3

    /// A fully encoded control colour.
    /// - Parameters:
    ///   - lean: Blade lean. Components are clamped to -1...1. Positive y leans down the screen.
    ///   - height: Blade height, 0...1.
    ///   - coverage: 0 shows bare soil, 1 is full turf.
    public static func color(
        lean: CGVector = .zero,
        height: Double = defaultHeight,
        coverage: Double = 1
    ) -> Color {
        let x = min(max(lean.dx, -1), 1)
        let y = min(max(lean.dy, -1), 1)
        return Color(
            .sRGB,
            red: 0.5 + 0.5 * x,
            green: 0.5 + 0.5 * y,
            blue: min(max(height, 0), 1),
            opacity: min(max(coverage, 0), 1)
        )
    }

    /// A control colour whose lean points along `angle` with the given magnitude.
    public static func color(
        angle: Angle,
        lean: Double = 0.8,
        height: Double = defaultHeight,
        coverage: Double = 1
    ) -> Color {
        color(lean: vector(angle, lean), height: height, coverage: coverage)
    }

    /// Upright, fully covered turf at the default height.
    public static let upright: Color = color()

    /// Bare soil.
    ///
    /// Use it as the *bottom* layer of a control map, with grass drawn on top.
    /// Drawing it over existing content does nothing, because a transparent fill
    /// is a no-op under normal compositing. To carve dirt out of a lawn that is
    /// already drawn, use ``SwiftUICore/View/grassWear(_:)`` instead.
    public static let bare: Color = color(coverage: 0)

    static func vector(_ angle: Angle, _ magnitude: Double) -> CGVector {
        CGVector(dx: cos(angle.radians) * magnitude, dy: sin(angle.radians) * magnitude)
    }

    /// Gradient stops encoding a radial lean field, for conic gradients.
    /// - Parameter outward: `true` leans blades away from the centre.
    static func radialGradient(outward: Bool, lean: Double, height: Double) -> Gradient {
        let steps = 24
        var stops: [Gradient.Stop] = []
        stops.reserveCapacity(steps + 1)
        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let angle = Angle.radians(t * 2 * .pi)
            let v = vector(angle, outward ? lean : -lean)
            stops.append(.init(color: color(lean: v, height: height), location: t))
        }
        return Gradient(stops: stops)
    }
}

// MARK: - Wear

public extension View {
    /// Removes coverage underneath this view in a ``GrassView`` control map,
    /// leaving the lean and height of what is below intact.
    ///
    /// Use it on a shape to wear a path through the lawn:
    /// ```swift
    /// GrassView {
    ///     ZStack {
    ///         GrassStripes(angle: .degrees(-90), stripeWidth: 40)
    ///         Capsule().frame(width: 60, height: 300).grassWear(0.7)
    ///     }
    /// }
    /// ```
    /// - Parameter amount: Fraction of coverage to remove, 0...1. 1 is bare soil.
    func grassWear(_ amount: Double) -> some View {
        self
            .opacity(min(max(amount, 0), 1))
            .blendMode(.destinationOut)
    }
}

// MARK: - Mow Patterns

/// Alternating mow stripes for a ``GrassView`` control map.
///
/// Stripes run along `angle`; successive stripes lean toward and away from it.
public struct GrassStripes: View {
    public var angle: Angle
    public var stripeWidth: Double
    public var lean: Double
    public var height: Double
    /// Shifts the stripes along their perpendicular, in points.
    public var offset: Double

    public init(
        angle: Angle = .degrees(-90),
        stripeWidth: Double = 48,
        lean: Double = 0.8,
        height: Double = GrassControl.defaultHeight,
        offset: Double = 0
    ) {
        self.angle = angle
        self.stripeWidth = stripeWidth
        self.lean = lean
        self.height = height
        self.offset = offset
    }

    public var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let forward = GrassControl.color(angle: angle, lean: lean, height: height)
            let back = GrassControl.color(angle: angle + .degrees(180), lean: lean, height: height)

            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(forward))

            let width = max(stripeWidth, 1)
            let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: angle)

            let count = Int((diagonal / width).rounded(.up)) + 2
            var stripes = Path()
            for i in -count...count where i & 1 != 0 {
                let y = Double(i) * width + offset
                stripes.addRect(CGRect(x: -diagonal, y: y, width: diagonal * 2, height: width))
            }
            context.fill(stripes, with: .color(back))
        }
    }
}

/// A checkerboard mow pattern for a ``GrassView`` control map.
///
/// Models two perpendicular stripe passes: each cell leans along one of four
/// diagonal directions so the squares alternate in tone.
public struct GrassCheckerboard: View {
    public var angle: Angle
    public var cellSize: Double
    public var lean: Double
    public var height: Double

    public init(
        angle: Angle = .zero,
        cellSize: Double = 64,
        lean: Double = 0.8,
        height: Double = GrassControl.defaultHeight
    ) {
        self.angle = angle
        self.cellSize = cellSize
        self.lean = lean
        self.height = height
    }

    public var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let cell = max(cellSize, 1)
            let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
            let a = GrassControl.vector(angle, 1)
            let b = CGVector(dx: -a.dy, dy: a.dx)
            let scale = lean / 2.0.squareRoot()

            // Four cell colours in grid space (unrotated), keyed by parity.
            var colors: [Color] = []
            for sa in [1.0, -1.0] {
                for sb in [1.0, -1.0] {
                    let v = CGVector(dx: (a.dx * sa + b.dx * sb) * scale,
                                     dy: (a.dy * sa + b.dy * sb) * scale)
                    colors.append(GrassControl.color(lean: v, height: height))
                }
            }

            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: angle)

            let count = Int((diagonal / 2 / cell).rounded(.up)) + 1
            var paths = [Path(), Path(), Path(), Path()]
            for i in -count...count {
                for j in -count...count {
                    let index = (i & 1 == 0 ? 0 : 2) + (j & 1 == 0 ? 0 : 1)
                    paths[index].addRect(CGRect(x: Double(i) * cell, y: Double(j) * cell, width: cell, height: cell))
                }
            }
            for k in 0..<4 {
                context.fill(paths[k], with: .color(colors[k]))
            }
        }
    }
}

/// Concentric mow rings for a ``GrassView`` control map, alternating between
/// blades leaning away from and toward the centre.
public struct GrassRings: View {
    public var center: UnitPoint
    public var ringWidth: Double
    public var lean: Double
    public var height: Double

    public init(
        center: UnitPoint = .center,
        ringWidth: Double = 48,
        lean: Double = 0.8,
        height: Double = GrassControl.defaultHeight
    ) {
        self.center = center
        self.ringWidth = ringWidth
        self.lean = lean
        self.height = height
    }

    public var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let c = CGPoint(x: center.x * size.width, y: center.y * size.height)
            let width = max(ringWidth, 1)
            let corners = [
                CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
                CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)
            ]
            let maxRadius = corners.map { hypot($0.x - c.x, $0.y - c.y) }.max() ?? 0

            let outward = GraphicsContext.Shading.conicGradient(
                GrassControl.radialGradient(outward: true, lean: lean, height: height),
                center: c
            )
            let inward = GraphicsContext.Shading.conicGradient(
                GrassControl.radialGradient(outward: false, lean: lean, height: height),
                center: c
            )

            let count = Int((maxRadius / width).rounded(.up))
            var ringsOut = Path()
            var ringsIn = Path()
            for i in 0...count {
                let inner = Double(i) * width
                let outer = inner + width
                var ring = Path()
                ring.addEllipse(in: CGRect(x: c.x - outer, y: c.y - outer, width: outer * 2, height: outer * 2))
                if inner > 0 {
                    ring.addEllipse(in: CGRect(x: c.x - inner, y: c.y - inner, width: inner * 2, height: inner * 2))
                }
                if i & 1 == 0 { ringsOut.addPath(ring) } else { ringsIn.addPath(ring) }
            }
            context.fill(ringsOut, with: outward, style: FillStyle(eoFill: true))
            context.fill(ringsIn, with: inward, style: FillStyle(eoFill: true))
        }
    }
}

// MARK: - Height from images

public extension GrassControl {
    /// Builds a control-map image from an image's luminance: brightness sets height and
    /// chooses between two mow directions, so a photo or a logo is cut into the turf.
    ///
    /// Groundskeepers' logos are direction only, so for lawn art keep `range` narrow
    /// and give `lean` and `darkLean` opposite directions; use a wide `range` for relief.
    ///
    /// - Parameters:
    ///   - image: Any image. Brightness maps to height; alpha below 1 keeps the base height.
    ///   - range: Heights the darkest and brightest pixels map to.
    ///   - invert: Map bright pixels to short grass instead of tall.
    ///   - lean: Blade lean for the brightest pixels.
    ///   - darkLean: Blade lean for the darkest pixels. Defaults to `lean`. Mow art reads
    ///     mostly through direction, so opposite leans give the classic light/dark logo.
    ///   - baseHeight: Height where the image is transparent.
    ///   - size: Output size in pixels. Defaults to the image size.
    static func heightMap(
        from image: CGImage,
        range: ClosedRange<Double> = 0.1...1.0,
        invert: Bool = false,
        lean: CGVector = .zero,
        darkLean: CGVector? = nil,
        baseHeight: Double = defaultHeight,
        size: CGSize? = nil
    ) -> CGImage? {
        let w = Int(size?.width ?? CGFloat(image.width)), h = Int(size?.height ?? CGFloat(image.height))
        guard w > 0, h > 0 else { return nil }
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        var src = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &src, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))

        let dark = darkLean ?? lean
        let lo = range.lowerBound, hi = range.upperBound
        var out = [UInt8](repeating: 0, count: w * h * 4)
        for i in stride(from: 0, to: out.count, by: 4) {
            let a = Double(src[i + 3]) / 255
            var luma = 0.0
            if a > 0 {
                luma = (0.2126 * Double(src[i]) + 0.7152 * Double(src[i + 1]) + 0.0722 * Double(src[i + 2])) / (255 * a)
            }
            if invert { luma = 1 - luma }
            let l = min(max(luma, 0), 1)
            let height = a * (lo + (hi - lo) * l) + (1 - a) * baseHeight
            let dx = min(max(dark.dx + (lean.dx - dark.dx) * l, -1), 1)
            let dy = min(max(dark.dy + (lean.dy - dark.dy) * l, -1), 1)
            out[i] = UInt8((0.5 + 0.5 * dx) * 255 + 0.5)
            out[i + 1] = UInt8((0.5 - 0.5 * dy) * 255 + 0.5)
            out[i + 2] = UInt8(min(max(height, 0), 1) * 255 + 0.5)
            out[i + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(out) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: cs,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

// MARK: - Crosshatch

/// Two stripe passes at different angles, as on a major-league outfield.
///
/// Each cell's lean is the sum of the two passes' leans, so the grid shows three
/// tones: cells mown away from the viewer in both passes, toward in both, and the
/// mixed cells between. With passes 90° apart this is a ``GrassCheckerboard``;
/// Yankee Stadium's diamonds are about 60° apart.
public struct GrassCrosshatch: View {
    /// Direction of the first mowing pass.
    public var angle: Angle
    /// Direction of the second pass.
    public var secondAngle: Angle
    public var stripeWidth: Double
    /// Lean each pass imparts.
    public var lean: Double
    public var height: Double
    /// Shifts each pass along its perpendicular, in points.
    public var offset: Double
    public var secondOffset: Double

    public init(
        angle: Angle = .degrees(-60),
        secondAngle: Angle = .degrees(-120),
        stripeWidth: Double = 48,
        lean: Double = 0.6,
        height: Double = GrassControl.defaultHeight,
        offset: Double = 0,
        secondOffset: Double = 0
    ) {
        self.angle = angle
        self.secondAngle = secondAngle
        self.stripeWidth = stripeWidth
        self.lean = lean
        self.height = height
        self.offset = offset
        self.secondOffset = secondOffset
    }

    public var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            let w = max(stripeWidth, 1)
            let d1 = CGVector(dx: cos(angle.radians), dy: sin(angle.radians))
            let d2 = CGVector(dx: cos(secondAngle.radians), dy: sin(secondAngle.radians))
            let n1 = CGVector(dx: -d1.dy, dy: d1.dx)
            let n2 = CGVector(dx: -d2.dy, dy: d2.dx)
            let det = n1.dx * n2.dy - n1.dy * n2.dx
            guard abs(det) > 1e-4 else {
                // Parallel passes: plain stripes.
                let c = GrassControl.color(lean: CGVector(dx: d1.dx * lean, dy: d1.dy * lean), height: height)
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(c))
                return
            }
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            // Point with band coordinates (a, b): p·n1 = a, p·n2 = b, relative to the centre.
            func point(_ a: Double, _ b: Double) -> CGPoint {
                let x = (a * n2.dy - b * n1.dy) / det
                let y = (b * n1.dx - a * n2.dx) / det
                return CGPoint(x: centre.x + x, y: centre.y + y)
            }
            let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
            let count = Int((diagonal / 2 / w).rounded(.up)) + 1

            var paths = [Path(), Path(), Path(), Path()]
            for i in -count...count {
                for j in -count...count {
                    let a0 = Double(i) * w - offset, a1 = a0 + w
                    let b0 = Double(j) * w - secondOffset, b1 = b0 + w
                    var cell = Path()
                    cell.move(to: point(a0, b0))
                    cell.addLine(to: point(a1, b0))
                    cell.addLine(to: point(a1, b1))
                    cell.addLine(to: point(a0, b1))
                    cell.closeSubpath()
                    paths[(i & 1 == 0 ? 0 : 2) + (j & 1 == 0 ? 0 : 1)].addPath(cell)
                }
            }
            for k in 0..<4 {
                let s1: Double = k & 2 == 0 ? 1 : -1
                let s2: Double = k & 1 == 0 ? 1 : -1
                let v = CGVector(dx: (d1.dx * s1 + d2.dx * s2) * lean, dy: (d1.dy * s1 + d2.dy * s2) * lean)
                context.fill(paths[k], with: .color(GrassControl.color(lean: v, height: height)))
            }
        }
    }
}
