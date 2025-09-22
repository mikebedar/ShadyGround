//
//  ShaderContext.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//


import SwiftUI

// MARK: - Public API

public struct ShaderContext {
    /// Current view size (or `.zero` if `needsSize == false`)
    public var size: CGSize = .zero
    /// Elapsed time in seconds since the modifier appeared (or `0` if `timeSource == .none`)
    public var time: Double = 0
}

public enum ShaderTimeSource: Equatable {
    /// No time updates.
    case none
    /// Ticks every animation frame.
    case animation
    /// Ticks at a fixed interval (seconds).
    case periodic(by: TimeInterval)
}

public extension View {
    /// Applies a Metal shader created from a closure that can *optionally* consume the view's size and time.
    ///
    /// Set `needsSize` to `true` if your shader relies on the view’s current size (e.g., “N cells across”).
    /// Choose a `timeSource` if your shader animates over time. If both are unused, this acts like a simple, static layerEffect.
    ///
    /// The `makeShader` closure receives a `ShaderContext` containing the current `size` and `time` values
    /// (populated based on `needsSize` and `timeSource`), and returns the configured `Shader`.
    ///
    /// - Parameters:
    ///   - needsSize: When `true`, the modifier tracks the view’s size and passes it in `context.size`.
    ///   - timeSource: Choose `.animation` for per-frame updates or `.periodic(by:)` for a fixed tick rate.
    ///   - maxSampleOffset: Declare the largest neighbor offset your shader may sample (for `layer.sample`).
    ///   - isEnabled: Toggle the effect on/off without removing it.
    ///   - makeShader: Closure that builds a `Shader` from the current `ShaderContext`.
    /// - Returns: A view with the shader applied.
    @inlinable
    func shadyLayerEffect(
        needsSize: Bool = false,
        timeSource: ShaderTimeSource = .none,
        maxSampleOffset: CGSize = .zero,
        isEnabled: Bool = true,
        _ makeShader: @escaping (_ context: ShaderContext) -> Shader
    ) -> some View {
        modifier(
            UnifiedShaderModifier(
                needsSize: needsSize,
                timeSource: timeSource,
                maxSampleOffset: maxSampleOffset,
                isEnabled: isEnabled,
                makeShader: makeShader
            )
        )
    }
}

// MARK: - Implementation

@usableFromInline struct UnifiedShaderModifier: ViewModifier {
    @usableFromInline let needsSize: Bool
    @usableFromInline let timeSource: ShaderTimeSource
    @usableFromInline let maxSampleOffset: CGSize
    @usableFromInline let isEnabled: Bool
    @usableFromInline let makeShader: (_ context: ShaderContext) -> Shader

    @State private var size: CGSize = .zero
    @State private var startDate: Date = .distantPast
    @State private var now: Date = .distantPast

    @usableFromInline init(
        needsSize: Bool,
        timeSource: ShaderTimeSource,
        maxSampleOffset: CGSize,
        isEnabled: Bool,
        makeShader: @escaping (_ context: ShaderContext) -> Shader
    ) {
        self.needsSize = needsSize
        self.timeSource = timeSource
        self.maxSampleOffset = maxSampleOffset
        self.isEnabled = isEnabled
        self.makeShader = makeShader
    }

    // Compute elapsed seconds only if time is enabled
    @usableFromInline var elapsed: Double {
        guard startDate != .distantPast, now != .distantPast else { return 0 }
        return now.timeIntervalSince(startDate)
    }

    @usableFromInline func body(content: Content) -> some View {
        // Base content with optional size tracking
        let sizedContent: some View = Group {
            if needsSize {
                content
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .local) } action: { rect in
                        size = rect.size
                    }
            } else {
                content
            }
        }

        // Time overlays depending on timeSource
        let timedBackground: some View = Group {
            switch timeSource {
            case .none:
                Color.clear
            case .animation:
                TimelineView(.animation) { ctx in
                    Color.clear
                        .onAppear {
                            if startDate == .distantPast { startDate = ctx.date }
                            now = ctx.date
                        }
                        .onChange(of: ctx.date) { _, newDate in
                            now = newDate
                        }
                }
            case .periodic(let interval):
                TimelineView(.periodic(from: .now, by: max(interval, 0.001))) { ctx in
                    Color.clear
                        .onAppear {
                            if startDate == .distantPast { startDate = ctx.date }
                            now = ctx.date
                        }
                        .onChange(of: ctx.date) { _, newDate in
                            now = newDate
                        }
                }
            }
        }

        // Compute elapsed seconds only if time is enabled
        let context = ShaderContext(
            size: needsSize ? size : .zero,
            time: (timeSource == .none) ? 0 : elapsed
        )

        return sizedContent
            .background(timedBackground)
            .layerEffect(
                makeShader(context),
                maxSampleOffset: maxSampleOffset,
                isEnabled: isEnabled
            )
    }
}
