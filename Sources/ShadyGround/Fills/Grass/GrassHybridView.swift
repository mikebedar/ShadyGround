//
//  GrassHybridView.swift
//  ShadyGround
//
//  Created by Michael Bedar on 10/9/25.
//

import SwiftUI

/// Turf rendered two ways at once: ``GrassView`` draws the whole field in one
/// fragment pass, and ``GrassInstancedView`` draws real blade geometry over the
/// first few metres, fading out where the fragment shader's texture takes over.
///
/// Both layers read the same control content. The instanced layer needs it as an
/// image, so the control view is rendered with `ImageRenderer` whenever the size
/// or `controlVersion` changes; bump `controlVersion` after animating the map.
///
/// ```swift
/// GrassHybridView(style: .ballpark, camera: camera, ground: .feet(pointsPerFoot: 2), bladeRange: 40) {
///     BallparkControl()
/// }
/// ```
public struct GrassHybridView<Control: View>: View {
    public var style: GrassStyle
    public var camera: GrassCamera
    public var ground: GrassGround
    public var atmosphere: GrassAtmosphere
    /// How far from the camera blade geometry is drawn, in ground units.
    public var bladeRange: Double
    public var bladeCount: Int
    /// Change this value to re-render the control image for the blade layer.
    public var controlVersion: Int
    private let control: Control

    @State private var controlImage: CGImage?
    @Environment(\.displayScale) private var displayScale

    public init(
        style: GrassStyle = .lawn,
        camera: GrassCamera,
        ground: GrassGround,
        atmosphere: GrassAtmosphere = .none,
        bladeRange: Double,
        bladeCount: Int = 300_000,
        controlVersion: Int = 0,
        @ViewBuilder control: () -> Control
    ) {
        self.style = style
        self.camera = camera
        self.ground = ground
        self.atmosphere = atmosphere
        self.bladeRange = bladeRange
        self.bladeCount = bladeCount
        self.controlVersion = controlVersion
        self.control = control()
    }

    /// The fragment-shader style for the far field: no shells, the blade layer has them covered.
    static func farFieldStyle(_ style: GrassStyle) -> GrassStyle {
        var far = style
        far.shellCount = 0
        return far
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                GrassView(style: Self.farFieldStyle(style), camera: camera, ground: ground, atmosphere: atmosphere) {
                    control
                }
                if !camera.isTopDown {
                    GrassInstancedView(
                        style: style, camera: camera, ground: ground, atmosphere: atmosphere,
                        controlImage: controlImage, bladeCount: bladeCount,
                        time: style.isAnimated ? nil : 0,
                        options: .nearField(range: bladeRange)
                    )
                    .allowsHitTesting(false)
                }
            }
            .task(id: ControlKey(size: geo.size, version: controlVersion)) {
                controlImage = renderControl(size: geo.size)
            }
        }
    }

    private struct ControlKey: Equatable {
        var size: CGSize
        var version: Int
    }

    @MainActor
    private func renderControl(size: CGSize) -> CGImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let renderer = ImageRenderer(
            content: control
                .environment(\.grassGround, ground)
                .frame(width: size.width, height: size.height)
        )
        renderer.scale = displayScale
        return renderer.cgImage
    }
}
