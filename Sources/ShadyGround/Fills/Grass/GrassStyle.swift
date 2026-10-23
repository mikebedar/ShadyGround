//
//  GrassStyle.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/8/25.
//

import SwiftUI
import simd

/// Appearance parameters for ``GrassView``.
///
/// A style describes what the turf looks like. *Where* blades lean, how tall they
/// are, and where the dirt shows through come from the control map (see ``GrassControl``),
/// and the viewpoint comes from ``GrassCamera``.
///
/// Physical sizes are in centimetres so a style looks the same whatever ground
/// units the scene uses. Angles follow SwiftUI's screen convention on the control
/// map: measured from the positive x axis, positive y down the map, so
/// `.degrees(-90)` points up the map (ground +y).
public struct GrassStyle: Equatable, Sendable {

    // MARK: Palette

    /// Colour at the base of the blades, in the shadowed gaps.
    public var baseColor: Color
    /// Colour of blade tips, the lit side of the texture.
    public var tipColor: Color
    /// Colour blended in by ``variation`` for dry or stressed patches.
    public var dryColor: Color
    /// Colour of the soil revealed where coverage is low. Alpha below 1 lets
    /// whatever sits behind the view show through the dirt.
    public var soilColor: Color
    /// Colour of the sky reflected off blades at grazing angles. Light stripes take on this tint.
    public var sheenColor: Color

    // MARK: Blade geometry (centimetres)

    /// Visible blade width.
    public var bladeWidth: Double
    /// Streak length as a multiple of blade width. Longer streaks read as combed, mown turf.
    public var bladeLength: Double
    /// Blade height at full control-map height. Drives the foreground blade shells.
    public var bladeHeight: Double
    /// Multiplier for the control map's height channel.
    public var heightScale: Double
    /// Multiplier for the control map's lean vector.
    public var leanScale: Double
    /// Direction the texture grain runs where blades are upright (no lean).
    public var grainAngle: Angle
    /// Strength of the blade texture contrast.
    public var contrast: Double

    // MARK: Lighting

    /// Direction the viewer is looking across the lawn when the camera is top-down.
    /// Perspective cameras use their own per-pixel view direction instead.
    public var viewAngle: Angle
    /// How strong the light/dark mow striping is. 0 disables it.
    public var stripeContrast: Double
    /// Direction *toward* the light, in map axes (x right, y down the map, z up).
    /// Mow stripes seen from above depend on it: they are strongest with the light
    /// behind the viewer and fade when facing it, as on a real lawn.
    public var lightDirection: SIMD3<Float>
    /// Strength of the anisotropic sheen and sky reflection on leaning blades.
    public var sheen: Double
    /// Tightness of the sheen highlight.
    public var sheenPower: Double
    /// How much the turf brightens toward grazing view angles (sky reflection).
    public var grazeBrighten: Double

    // MARK: Foreground blades

    /// Number of height slices used to draw individual blades close to the camera. 0 disables.
    public var shellCount: Int
    /// How close the camera must be before blades are drawn individually, as the
    /// pixel footprint in multiples of ``bladeWidth``.
    public var shellRange: Double
    /// How much darker the ground is between individually drawn blades, 0...1.
    /// A dense canopy hides its base in shadow; the lit tips are the blades themselves.
    public var canopyInterior: Double

    // MARK: Wind

    /// Lean added by wind gusts. 0 disables wind and the effect stops animating.
    public var windStrength: Double
    /// Gust size in centimetres.
    public var windScale: Double
    /// Gust travel speed in centimetres per second.
    public var windSpeed: Double
    /// Direction the wind blows toward, in map axes.
    public var windAngle: Angle

    // MARK: Variation

    /// Amount of ``dryColor`` patchiness, 0...1.
    public var variation: Double
    /// Size of the dry patches in centimetres.
    public var patchScale: Double
    /// Softness of the grass-to-dirt transition at partial coverage, 0...0.5.
    public var edgeSoftness: Double
    /// Blur radius applied to the control map in centimetres, softening stripe and dirt edges.
    public var edgeBlur: Double

    // MARK: Grading

    /// Overall brightness multiplier.
    public var exposure: Double
    /// Saturation multiplier.
    public var saturation: Double
    /// Darkening toward the corners, 0...1.
    public var vignette: Double

    public init(
        baseColor: Color = Color(.sRGB, red: 0.10, green: 0.28, blue: 0.07),
        tipColor: Color = Color(.sRGB, red: 0.52, green: 0.72, blue: 0.30),
        dryColor: Color = Color(.sRGB, red: 0.58, green: 0.60, blue: 0.26),
        soilColor: Color = Color(.sRGB, red: 0.47, green: 0.32, blue: 0.19),
        sheenColor: Color = Color(.sRGB, red: 0.88, green: 0.92, blue: 0.70),
        bladeWidth: Double = 0.4,
        bladeLength: Double = 7,
        bladeHeight: Double = 4,
        heightScale: Double = 1,
        leanScale: Double = 1,
        grainAngle: Angle = .degrees(-90),
        contrast: Double = 1,
        viewAngle: Angle = .degrees(-90),
        stripeContrast: Double = 0.35,
        lightDirection: SIMD3<Float> = SIMD3<Float>(-0.35, -0.5, 0.8),
        sheen: Double = 0.3,
        sheenPower: Double = 20,
        grazeBrighten: Double = 0.5,
        shellCount: Int = 4,
        shellRange: Double = 2,
        canopyInterior: Double = 0.45,
        windStrength: Double = 0,
        windScale: Double = 35,
        windSpeed: Double = 22,
        windAngle: Angle = .degrees(20),
        variation: Double = 0.25,
        patchScale: Double = 55,
        edgeSoftness: Double = 0.08,
        edgeBlur: Double = 5,
        exposure: Double = 1,
        saturation: Double = 1,
        vignette: Double = 0
    ) {
        self.baseColor = baseColor
        self.tipColor = tipColor
        self.dryColor = dryColor
        self.soilColor = soilColor
        self.sheenColor = sheenColor
        self.bladeWidth = bladeWidth
        self.bladeLength = bladeLength
        self.bladeHeight = bladeHeight
        self.heightScale = heightScale
        self.leanScale = leanScale
        self.grainAngle = grainAngle
        self.contrast = contrast
        self.viewAngle = viewAngle
        self.stripeContrast = stripeContrast
        self.lightDirection = lightDirection
        self.sheen = sheen
        self.sheenPower = sheenPower
        self.grazeBrighten = grazeBrighten
        self.shellCount = shellCount
        self.shellRange = shellRange
        self.canopyInterior = canopyInterior
        self.windStrength = windStrength
        self.windScale = windScale
        self.windSpeed = windSpeed
        self.windAngle = windAngle
        self.variation = variation
        self.patchScale = patchScale
        self.edgeSoftness = edgeSoftness
        self.edgeBlur = edgeBlur
        self.exposure = exposure
        self.saturation = saturation
        self.vignette = vignette
    }

    /// Whether this style needs per-frame time updates.
    public var isAnimated: Bool { windStrength > 0 }

    // MARK: Shader

    @MainActor
    func makeShader(camera: GrassCamera, ground: GrassGround, atmosphere: GrassAtmosphere, size: CGSize, time: Double, pixelScale: Double) -> Shader {
        let uniforms = GrassUniform.pack(style: self, camera: camera, ground: ground, atmosphere: atmosphere, size: size, time: time, pixelScale: pixelScale)
        return ShadyGroundLibrary.default.grass(
            .float2(Float(size.width), Float(size.height)),
            .floatArray(uniforms),
            .color(baseColor),
            .color(tipColor),
            .color(dryColor),
            .color(soilColor),
            .color(sheenColor),
            .color(atmosphere.fogColor)
        )
    }

    static func direction(_ angle: Angle) -> CGPoint {
        CGPoint(x: cos(angle.radians), y: sin(angle.radians))
    }
}

// MARK: - Presets

public extension GrassStyle {

    /// A healthy, regularly mown domestic lawn.
    static let lawn = GrassStyle()

    /// Major-league outfield in overcast light: olive-green, strong striping, tan clay.
    static let ballpark = GrassStyle(
        baseColor: Color(.sRGB, red: 0.17, green: 0.25, blue: 0.09),
        tipColor: Color(.sRGB, red: 0.48, green: 0.57, blue: 0.27),
        dryColor: Color(.sRGB, red: 0.54, green: 0.54, blue: 0.27),
        soilColor: Color(.sRGB, red: 0.58, green: 0.44, blue: 0.31),
        sheenColor: Color(.sRGB, red: 0.82, green: 0.82, blue: 0.72),
        bladeWidth: 0.35,
        bladeLength: 9,
        bladeHeight: 3,
        stripeContrast: 0.3,
        sheen: 0.3,
        sheenPower: 18,
        grazeBrighten: 0.35,
        shellRange: 3,
        variation: 0.15,
        patchScale: 80
    )

    /// Sunlit stadium turf as seen from the stands or the air: bright, saturated,
    /// smooth, with clean stripes. Measured against daylight upper-deck photos.
    static let stadium = GrassStyle(
        baseColor: Color(.sRGB, red: 0.28, green: 0.42, blue: 0.10),
        tipColor: Color(.sRGB, red: 0.74, green: 0.92, blue: 0.27),
        dryColor: Color(.sRGB, red: 0.66, green: 0.72, blue: 0.28),
        soilColor: Color(.sRGB, red: 0.72, green: 0.45, blue: 0.24),
        sheenColor: Color(.sRGB, red: 0.85, green: 0.95, blue: 0.50),
        bladeWidth: 0.35,
        bladeLength: 8,
        bladeHeight: 3,
        contrast: 0.8,
        stripeContrast: 0.3,
        // Sun high and behind a viewer looking up the map: stripes read strongest
        // with the light behind you and wash out facing it.
        lightDirection: SIMD3<Float>(0.3, 0.6, 0.75),
        sheen: 0.2,
        sheenPower: 18,
        grazeBrighten: 0.12,
        variation: 0.06,
        patchScale: 150
    )

    /// Floodlit night game: lime-green, flat lighting, orange clay.
    static let nightGame = GrassStyle(
        baseColor: Color(.sRGB, red: 0.10, green: 0.32, blue: 0.07),
        tipColor: Color(.sRGB, red: 0.42, green: 0.74, blue: 0.28),
        dryColor: Color(.sRGB, red: 0.60, green: 0.70, blue: 0.30),
        soilColor: Color(.sRGB, red: 0.75, green: 0.44, blue: 0.22),
        sheenColor: Color(.sRGB, red: 0.85, green: 0.90, blue: 0.70),
        bladeWidth: 0.35,
        bladeLength: 6,
        bladeHeight: 3,
        stripeContrast: 0,
        sheen: 0.25,
        sheenPower: 16,
        grazeBrighten: 0.7,
        variation: 0.08,
        patchScale: 120,
        saturation: 1.1
    )

    /// Putting-green turf: tiny, uniform, glossy.
    static let golfGreen = GrassStyle(
        baseColor: Color(.sRGB, red: 0.16, green: 0.40, blue: 0.12),
        tipColor: Color(.sRGB, red: 0.42, green: 0.70, blue: 0.24),
        soilColor: Color(.sRGB, red: 0.40, green: 0.33, blue: 0.22),
        bladeWidth: 0.2,
        bladeLength: 5,
        bladeHeight: 1,
        heightScale: 0.4,
        contrast: 0.7,
        stripeContrast: 0.3,
        sheen: 0.5,
        sheenPower: 30,
        variation: 0.05
    )

    /// Unmown grass with taller, looser blades and a breeze.
    static let meadow = GrassStyle(
        baseColor: Color(.sRGB, red: 0.13, green: 0.30, blue: 0.09),
        tipColor: Color(.sRGB, red: 0.55, green: 0.70, blue: 0.28),
        dryColor: Color(.sRGB, red: 0.66, green: 0.62, blue: 0.30),
        bladeWidth: 0.6,
        bladeLength: 10,
        bladeHeight: 25,
        heightScale: 1,
        stripeContrast: 0.2,
        sheen: 0.2,
        windStrength: 0.35,
        windScale: 45,
        windSpeed: 30,
        variation: 0.45,
        patchScale: 65
    )

    /// Late-summer lawn, sun-bleached and patchy.
    static let dry = GrassStyle(
        baseColor: Color(.sRGB, red: 0.36, green: 0.40, blue: 0.16),
        tipColor: Color(.sRGB, red: 0.72, green: 0.68, blue: 0.34),
        dryColor: Color(.sRGB, red: 0.76, green: 0.64, blue: 0.36),
        soilColor: Color(.sRGB, red: 0.52, green: 0.42, blue: 0.28),
        bladeWidth: 0.45,
        stripeContrast: 0.2,
        sheen: 0.15,
        variation: 0.6,
        patchScale: 40
    )

    /// Artificial turf: saturated, uniform, no dry patches.
    static let artificial = GrassStyle(
        baseColor: Color(.sRGB, red: 0.10, green: 0.42, blue: 0.14),
        tipColor: Color(.sRGB, red: 0.30, green: 0.70, blue: 0.26),
        soilColor: Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15),
        bladeWidth: 0.3,
        bladeLength: 6,
        bladeHeight: 2,
        heightScale: 0.6,
        contrast: 0.8,
        stripeContrast: 0.3,
        sheen: 0.45,
        sheenPower: 14,
        variation: 0
    )
}
