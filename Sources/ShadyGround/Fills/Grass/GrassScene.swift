//
//  GrassScene.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/8/25.
//
//  Camera, ground mapping and atmosphere for GrassView, plus the uniform packer
//  that mirrors the `U` namespace in GrassShader.metal.
//

import SwiftUI
import simd

// MARK: - Ground units

/// The unit that camera positions, ground extents and fog distances are expressed in.
public enum GroundUnit: Equatable, Sendable {
    case centimetres
    case metres
    case inches
    case feet
    /// A custom unit, given as its length in centimetres.
    case custom(centimetres: Double)

    public var centimetres: Double {
        switch self {
        case .centimetres: 1
        case .metres: 100
        case .inches: 2.54
        case .feet: 30.48
        case .custom(let cm): cm
        }
    }
}

// MARK: - Ground mapping

/// How the control map (the view you draw) maps onto the ground plane.
///
/// Ground coordinates are right-handed: x to the right of the map, y *up* the map
/// (away from a camera at the bottom), z up out of the ground. Ground (0, 0) sits
/// at `origin` in the control view.
public struct GrassGround: Equatable, Sendable {
    public var unit: GroundUnit
    /// Control-map points per ground unit.
    public var pointsPerUnit: Double
    /// Where ground (0, 0) sits in the control view.
    public var origin: UnitPoint
    /// Extra offset of the origin, in points.
    public var originOffset: CGSize

    public init(unit: GroundUnit, pointsPerUnit: Double, origin: UnitPoint = .center, originOffset: CGSize = .zero) {
        self.unit = unit
        self.pointsPerUnit = pointsPerUnit
        self.origin = origin
        self.originOffset = originOffset
    }

    /// Screen-scale ground for top-down use: one point is a quarter centimetre,
    /// so a 0.4 cm blade is 1.6 points wide.
    public static let screen = GrassGround(unit: .custom(centimetres: 0.25), pointsPerUnit: 1, origin: .topLeading)

    /// A ground measured in feet.
    public static func feet(pointsPerFoot: Double, origin: UnitPoint = UnitPoint(x: 0.5, y: 0.95), originOffset: CGSize = .zero) -> GrassGround {
        GrassGround(unit: .feet, pointsPerUnit: pointsPerFoot, origin: origin, originOffset: originOffset)
    }

    /// A ground measured in metres.
    public static func metres(pointsPerMetre: Double, origin: UnitPoint = UnitPoint(x: 0.5, y: 0.95), originOffset: CGSize = .zero) -> GrassGround {
        GrassGround(unit: .metres, pointsPerUnit: pointsPerMetre, origin: origin, originOffset: originOffset)
    }

    public var cmPerPoint: Double { unit.centimetres / pointsPerUnit }

    /// The control-view point corresponding to ground (0, 0).
    public func originPoint(in size: CGSize) -> CGPoint {
        CGPoint(x: origin.x * size.width + originOffset.width,
                y: origin.y * size.height + originOffset.height)
    }

    /// Converts a ground position (in `unit`) to a control-view point.
    public func point(x: Double, y: Double, in size: CGSize) -> CGPoint {
        let o = originPoint(in: size)
        return CGPoint(x: o.x + x * pointsPerUnit, y: o.y - y * pointsPerUnit)
    }

    /// Converts a ground length (in `unit`) to points.
    public func length(_ units: Double) -> CGFloat {
        CGFloat(units * pointsPerUnit)
    }

    /// Converts a control-view point to a ground position (in `unit`).
    public func groundPoint(at point: CGPoint, in size: CGSize) -> CGPoint {
        let o = originPoint(in: size)
        return CGPoint(x: (point.x - o.x) / pointsPerUnit, y: (o.y - point.y) / pointsPerUnit)
    }
}

private struct GrassGroundKey: EnvironmentKey {
    static let defaultValue: GrassGround? = nil
}

public extension EnvironmentValues {
    /// The ground mapping of the enclosing ``GrassView``, so control-map views can
    /// draw in ground units. `nil` outside a grass view.
    var grassGround: GrassGround? {
        get { self[GrassGroundKey.self] }
        set { self[GrassGroundKey.self] = newValue }
    }
}

// MARK: - Camera

/// A perspective camera above the ground plane, positioned in the ground's units.
///
/// Heading 0 looks up the map (ground +y); positive headings turn clockwise seen
/// from above. Pitch is negative to look down. The field of view is vertical.
public struct GrassCamera: Equatable, Sendable {
    public var eye: SIMD3<Double>
    public var heading: Angle
    public var pitch: Angle
    public var fieldOfView: Angle
    /// Ignores the perspective parameters and renders the map straight down at map scale.
    public var isTopDown: Bool

    public init(eye: SIMD3<Double>, heading: Angle = .zero, pitch: Angle = .degrees(-15), fieldOfView: Angle = .degrees(55)) {
        self.eye = eye
        self.heading = heading
        self.pitch = pitch
        self.fieldOfView = fieldOfView
        self.isTopDown = false
    }

    /// Orthographic, straight down: the original ShadyGround behaviour.
    public static var topDown: GrassCamera {
        var c = GrassCamera(eye: SIMD3(0, 0, 1))
        c.isTopDown = true
        return c
    }

    /// A camera at `eye` looking at a ground point.
    public static func lookAt(eye: SIMD3<Double>, target: SIMD3<Double>, fieldOfView: Angle = .degrees(55)) -> GrassCamera {
        let d = target - eye
        let flat = (d.x * d.x + d.y * d.y).squareRoot()
        let heading = Angle.radians(atan2(d.x, d.y))
        let pitch = Angle.radians(atan2(d.z, flat))
        return GrassCamera(eye: eye, heading: heading, pitch: pitch, fieldOfView: fieldOfView)
    }

    /// A camera whose horizon lands at `horizonAt`, a fraction of the view height
    /// measured from the top. Values below 0 put the horizon above the frame.
    public static func framing(eye: SIMD3<Double>, heading: Angle = .zero, horizonAt: Double, fieldOfView: Angle = .degrees(55)) -> GrassCamera {
        let tanHalf = tan(fieldOfView.radians / 2)
        let yUp = 1 - 2 * horizonAt
        let pitch = Angle.radians(-atan(yUp * tanHalf))
        return GrassCamera(eye: eye, heading: heading, pitch: pitch, fieldOfView: fieldOfView)
    }
}

// MARK: - Atmosphere

/// Distance effects: fog, desaturation, and a glow along the horizon.
public struct GrassAtmosphere: Equatable, Sendable {
    /// Colour the ground fades to with distance. Alpha scales the effect; `.clear` disables it.
    public var fogColor: Color
    /// Distance (in ground units) over which about 63% of the fog colour is reached. 0 disables.
    public var fogDistance: Double
    /// Distance over which saturation falls to about 37%. 0 disables.
    public var desaturationDistance: Double
    /// Width in points of a fog-coloured glow above the horizon. 0 disables.
    public var horizonGlow: Double

    public init(fogColor: Color = .clear, fogDistance: Double = 0, desaturationDistance: Double = 0, horizonGlow: Double = 0) {
        self.fogColor = fogColor
        self.fogDistance = fogDistance
        self.desaturationDistance = desaturationDistance
        self.horizonGlow = horizonGlow
    }

    public static let none = GrassAtmosphere()

    /// Bright stadium haze: cream fog, desaturating with distance.
    public static func haze(distance: Double, color: Color = Color(.sRGB, red: 0.91, green: 0.92, blue: 0.86), glow: Double = 24) -> GrassAtmosphere {
        GrassAtmosphere(fogColor: color, fogDistance: distance, desaturationDistance: distance * 1.3, horizonGlow: glow)
    }
}

// MARK: - Uniform packing

/// Index layout of the float array passed to the shader. Mirror of `U` in GrassShader.metal.
enum GrassUniform {
    static let eyeX = 0, eyeY = 1, eyeZ = 2
    static let m00 = 3
    static let mapOriginX = 12, mapOriginY = 13
    static let cmPerPoint = 14
    static let mapW = 15, mapH = 16
    static let topDown = 17
    static let bladeWidth = 18, bladeLength = 19, bladeHeight = 20, heightScale = 21
    static let leanScale = 22, grainX = 23, grainY = 24, contrast = 25
    static let stripeContrast = 26, lightX = 27, lightY = 28, lightZ = 29
    static let sheen = 30, sheenPower = 31, grazeBrighten = 32
    static let windStrength = 33, windScale = 34, windSpeed = 35, windX = 36, windY = 37, time = 38
    static let variation = 39, patchScale = 40, edgeSoftness = 41
    static let shellCount = 42, shellRange = 43
    static let fogDistance = 44, desatDistance = 45, horizonGlow = 46
    static let exposure = 47, saturation = 48, vignette = 49
    static let viewX = 50, viewY = 51
    static let edgeBlur = 52, pixelScale = 53
    static let nearInterior = 54, nearFadeStart = 55, nearFadeEnd = 56, nearDense = 57
    static let count = 58

    static func pack(style: GrassStyle, camera: GrassCamera, ground: GrassGround, atmosphere: GrassAtmosphere, size: CGSize, time: Double, pixelScale: Double) -> [Float] {
        var u = [Float](repeating: 0, count: count)
        let cm = ground.unit.centimetres
        let w = max(size.width, 1), h = max(size.height, 1)

        u[topDown] = camera.isTopDown ? 1 : 0
        let eye = camera.eye * cm
        u[eyeX] = Float(eye.x); u[eyeY] = Float(eye.y); u[eyeZ] = Float(eye.z)

        if !camera.isTopDown {
            let tanHalf = tan(camera.fieldOfView.radians / 2)
            let aspect = w / h
            let th = camera.heading.radians
            let ph = camera.pitch.radians
            let fwdFlat = SIMD3<Double>(sin(th), cos(th), 0)
            let right = SIMD3<Double>(cos(th), -sin(th), 0)
            let up0 = SIMD3<Double>(0, 0, 1)
            let f = cos(ph) * fwdFlat + sin(ph) * up0
            let up = -sin(ph) * fwdFlat + cos(ph) * up0
            let c0 = right * (2 * tanHalf * aspect / w)
            let c1 = up * (-2 * tanHalf / h)
            let c2 = f - right * (tanHalf * aspect) + up * tanHalf
            // Row-major: row r = (c0[r], c1[r], c2[r])
            for r in 0..<3 {
                u[m00 + r * 3 + 0] = Float(c0[r])
                u[m00 + r * 3 + 1] = Float(c1[r])
                u[m00 + r * 3 + 2] = Float(c2[r])
            }
        }

        let o = ground.originPoint(in: size)
        u[mapOriginX] = Float(o.x); u[mapOriginY] = Float(o.y)
        u[cmPerPoint] = Float(ground.cmPerPoint)
        u[mapW] = Float(w); u[mapH] = Float(h)

        u[bladeWidth] = Float(style.bladeWidth)
        u[bladeLength] = Float(style.bladeLength)
        u[bladeHeight] = Float(style.bladeHeight)
        u[heightScale] = Float(style.heightScale)
        u[leanScale] = Float(style.leanScale)
        let grain = GrassStyle.direction(style.grainAngle)
        u[grainX] = Float(grain.x); u[grainY] = Float(-grain.y)
        u[contrast] = Float(style.contrast)

        u[stripeContrast] = Float(style.stripeContrast)
        u[lightX] = style.lightDirection.x; u[lightY] = -style.lightDirection.y; u[lightZ] = style.lightDirection.z
        u[sheen] = Float(style.sheen)
        u[sheenPower] = Float(style.sheenPower)
        u[grazeBrighten] = Float(style.grazeBrighten)

        u[windStrength] = Float(style.windStrength)
        u[windScale] = Float(style.windScale)
        u[windSpeed] = Float(style.windSpeed)
        let wind = GrassStyle.direction(style.windAngle)
        u[windX] = Float(wind.x); u[windY] = Float(-wind.y)
        u[GrassUniform.time] = Float(time)

        u[variation] = Float(style.variation)
        u[patchScale] = Float(style.patchScale)
        u[edgeSoftness] = Float(style.edgeSoftness)
        u[shellCount] = Float(style.shellCount)
        u[shellRange] = Float(style.shellRange)

        u[fogDistance] = Float(atmosphere.fogDistance * cm)
        u[desatDistance] = Float(atmosphere.desaturationDistance * cm)
        u[horizonGlow] = Float(atmosphere.horizonGlow)

        u[exposure] = Float(style.exposure)
        u[saturation] = Float(style.saturation)
        u[vignette] = Float(style.vignette)

        let view = GrassStyle.direction(style.viewAngle)
        u[viewX] = Float(view.x); u[viewY] = Float(-view.y)
        u[edgeBlur] = Float(style.edgeBlur)
        u[GrassUniform.pixelScale] = Float(pixelScale)
        return u
    }
}

// MARK: - Screen / ground conversion

public extension GrassCamera {
    private struct Basis {
        let right: SIMD3<Double>
        let up: SIMD3<Double>
        let forward: SIMD3<Double>
        let tanHalf: Double
        let aspect: Double
    }

    private func basis(size: CGSize) -> Basis {
        let tanHalf = tan(fieldOfView.radians / 2)
        let th = heading.radians, ph = pitch.radians
        let fwdFlat = SIMD3<Double>(sin(th), cos(th), 0)
        let right = SIMD3<Double>(cos(th), -sin(th), 0)
        let up0 = SIMD3<Double>(0, 0, 1)
        return Basis(
            right: right,
            up: -sin(ph) * fwdFlat + cos(ph) * up0,
            forward: cos(ph) * fwdFlat + sin(ph) * up0,
            tanHalf: tanHalf,
            aspect: max(size.width, 1) / max(size.height, 1)
        )
    }

    /// The ground point under a view location, in ground units, or `nil` above the horizon.
    func groundPoint(at point: CGPoint, in size: CGSize, ground: GrassGround) -> CGPoint? {
        if isTopDown {
            let o = ground.originPoint(in: size)
            return CGPoint(x: (point.x - o.x) / ground.pointsPerUnit, y: (o.y - point.y) / ground.pointsPerUnit)
        }
        let b = basis(size: size)
        let nx = (point.x / max(size.width, 1)) * 2 - 1
        let ny = 1 - (point.y / max(size.height, 1)) * 2
        let d = b.forward + b.right * (nx * b.tanHalf * b.aspect) + b.up * (ny * b.tanHalf)
        guard d.z < -1e-6 else { return nil }
        let t = -eye.z / d.z
        return CGPoint(x: eye.x + t * d.x, y: eye.y + t * d.y)
    }

    /// The view location of a ground point, or `nil` when it is behind the camera.
    func viewPoint(of groundPoint: CGPoint, elevation: Double = 0, in size: CGSize, ground: GrassGround) -> CGPoint? {
        if isTopDown {
            return ground.point(x: groundPoint.x, y: groundPoint.y, in: size)
        }
        let b = basis(size: size)
        let d = SIMD3<Double>(groundPoint.x, groundPoint.y, elevation) - eye
        let z = simd_dot(d, b.forward)
        guard z > 1e-6 else { return nil }
        let nx = simd_dot(d, b.right) / (z * b.tanHalf * b.aspect)
        let ny = simd_dot(d, b.up) / (z * b.tanHalf)
        return CGPoint(x: (nx + 1) / 2 * size.width, y: (1 - ny) / 2 * size.height)
    }

    /// Apparent size in points of a ground length at a ground point, for sizing overlays.
    func viewScale(at groundPoint: CGPoint, in size: CGSize, ground: GrassGround) -> Double {
        if isTopDown { return ground.pointsPerUnit }
        let b = basis(size: size)
        let d = SIMD3<Double>(groundPoint.x, groundPoint.y, 0) - eye
        let z = max(simd_dot(d, b.forward), 1e-6)
        return size.height / (2 * b.tanHalf * z)
    }
}
