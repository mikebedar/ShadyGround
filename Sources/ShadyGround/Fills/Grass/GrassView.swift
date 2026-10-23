//
//  GrassView.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/8/25.
//

import SwiftUI

/// Renders realistic turf from a control map drawn with ordinary SwiftUI views,
/// straight down or through a perspective camera.
///
/// The `control` content is not displayed. It is rasterised and read by the shader
/// as a top-down plan of the ground with four channels:
///
/// | Channel | Meaning |
/// |---|---|
/// | R, G | Blade lean direction (0.5, 0.5 is upright) |
/// | B | Blade height |
/// | A | Coverage: 0 is bare soil, 1 is full turf |
///
/// Use ``GrassControl`` to produce correctly encoded colours, and the pattern views
/// ``GrassStripes``, ``GrassCheckerboard`` and ``GrassRings`` for mow patterns.
/// Because the map is a view, animating it animates the grass.
///
/// ```swift
/// GrassView(
///     style: .ballpark,
///     camera: .framing(eye: [0, -20, 5], horizonAt: 0.4),
///     ground: .feet(pointsPerFoot: 2),
///     atmosphere: .haze(distance: 70)
/// ) {
///     BallparkControl()
/// }
/// ```
///
/// The ground mapping is published to the control content through the
/// `grassGround` environment value, so maps can draw in ground units.
public struct GrassView<Control: View>: View {
    public var style: GrassStyle
    public var camera: GrassCamera
    public var ground: GrassGround
    public var atmosphere: GrassAtmosphere
    private let control: Control
    @Environment(\.displayScale) private var displayScale

    /// Creates a grass view driven by a control map you draw.
    /// - Parameters:
    ///   - style: The turf appearance.
    ///   - camera: The viewpoint. Defaults to straight down.
    ///   - ground: How the control map maps onto the ground. Defaults to screen scale.
    ///   - atmosphere: Fog and distance effects. Defaults to none.
    ///   - control: A view builder producing the control map. See ``GrassControl``.
    public init(
        style: GrassStyle = .lawn,
        camera: GrassCamera = .topDown,
        ground: GrassGround = .screen,
        atmosphere: GrassAtmosphere = .none,
        @ViewBuilder control: () -> Control
    ) {
        self.style = style
        self.camera = camera
        self.ground = ground
        self.atmosphere = atmosphere
        self.control = control()
    }

    public var body: some View {
        control
            .environment(\.grassGround, ground)
            // SwiftUI skips the layer effect entirely when the content is fully
            // transparent, so a bare map would render nothing. A 1/255 alpha floor
            // keeps the effect running; the shader treats it as zero coverage.
            .background(Color.black.opacity(1.0 / 255.0))
            .compositingGroup()
            .shadyLayerEffect(
                needsSize: true,
                timeSource: style.isAnimated ? .animation : .none
            ) { context in
                style.makeShader(camera: camera, ground: ground, atmosphere: atmosphere, size: context.size, time: context.time, pixelScale: Double(displayScale))
            }
    }
}

public extension GrassView where Control == Color {
    /// Creates a uniform lawn with the same lean, height and coverage everywhere.
    init(
        style: GrassStyle = .lawn,
        camera: GrassCamera = .topDown,
        ground: GrassGround = .screen,
        atmosphere: GrassAtmosphere = .none,
        lean: CGVector = .zero,
        height: Double = GrassControl.defaultHeight,
        coverage: Double = 1
    ) {
        self.init(style: style, camera: camera, ground: ground, atmosphere: atmosphere) {
            GrassControl.color(lean: lean, height: height, coverage: coverage)
        }
    }
}

public extension GrassView where Control == Image {
    /// Creates a grass view driven by a pre-authored control map image.
    ///
    /// The image is stretched to fill the view. Its channels must follow the
    /// ``GrassControl`` encoding: red and green are lean, blue is height, alpha is coverage.
    init(
        style: GrassStyle = .lawn,
        camera: GrassCamera = .topDown,
        ground: GrassGround = .screen,
        atmosphere: GrassAtmosphere = .none,
        controlMap: Image
    ) {
        self.init(style: style, camera: camera, ground: ground, atmosphere: atmosphere) {
            controlMap.resizable()
        }
    }
}
