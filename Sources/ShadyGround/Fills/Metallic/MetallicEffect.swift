//
//  MetallicEffect.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/30/25.
//

import SwiftUI
#if os(iOS)
import CoreMotion
import QuartzCore
#endif
import simd

// MARK: - Thread-Safe Parameter Container

/// Thread-safe container for shader parameters that can be updated from any thread
private final class ShaderParameters: @unchecked Sendable {
    private let lock = NSLock()
    private var _viewDirection: SIMD3<Float>
    private var _needsUpdate = false
    
    var viewDirection: SIMD3<Float> {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _viewDirection
        }
        set {
            lock.lock()
            _viewDirection = newValue
            _needsUpdate = true
            lock.unlock()
        }
    }
    
    var needsUpdate: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _needsUpdate
    }
    
    func clearUpdateFlag() {
        lock.lock()
        _needsUpdate = false
        lock.unlock()
    }
    
    init(viewDirection: SIMD3<Float>) {
        self._viewDirection = viewDirection
    }
}

// MARK: - Motion Manager (iOS only)

#if os(iOS)
/// Handles device motion updates on a background thread
private final class MetallicMotionManager: @unchecked Sendable {
    private let motionManager = CMMotionManager()
    private let parameters: ShaderParameters
    private var calibrationMatrix: simd_float3x3 = simd_float3x3(1)
    private var isCalibrated = false
    private let motionQueue = OperationQueue()
    
    init(parameters: ShaderParameters) {
        self.parameters = parameters
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInteractive
    }
    
    func start() {
        guard !motionManager.isDeviceMotionActive,
              motionManager.isDeviceMotionAvailable else { return }
        
        // Update at 60fps to capture smooth motion data
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        
        // Process motion on background queue
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }
            self.processMotion(motion)
        }
    }
    
    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    func calibrate() {
        guard let motion = motionManager.deviceMotion else { return }
        
        let forwardDevice = SIMD3<Float>(0, 0, -1)
        let currentForward = transformVector(forwardDevice, by: motion.attitude.rotationMatrix)
        
        // Store calibration: rotate so this forward becomes (0,0,1) (neutral)
        calibrationMatrix = alignVectors(from: currentForward, to: SIMD3<Float>(0, 0, 1))
        isCalibrated = true
    }
    
    private func processMotion(_ motion: CMDeviceMotion) {
        // Use rotation matrix for stability (less prone to gimbal lock)
        let forwardDevice = SIMD3<Float>(0, 0, -1)
        let currentForward = transformVector(forwardDevice, by: motion.attitude.rotationMatrix)
        
        // Apply calibration if available
        let calibratedForward = isCalibrated ?
            simd_normalize(calibrationMatrix * currentForward) :
            currentForward
        
        // Update parameters (thread-safe)
        parameters.viewDirection = calibratedForward
    }
    
    private func transformVector(_ vector: SIMD3<Float>, by matrix: CMRotationMatrix) -> SIMD3<Float> {
        let result = SIMD3<Float>(
            Float(matrix.m11) * vector.x + Float(matrix.m12) * vector.y + Float(matrix.m13) * vector.z,
            Float(matrix.m21) * vector.x + Float(matrix.m22) * vector.y + Float(matrix.m23) * vector.z,
            Float(matrix.m31) * vector.x + Float(matrix.m32) * vector.y + Float(matrix.m33) * vector.z
        )
        return simd_normalize(result)
    }
    
    private func alignVectors(from: SIMD3<Float>, to: SIMD3<Float>) -> simd_float3x3 {
        let v = simd_cross(from, to)
        let c = simd_dot(from, to)
        if c > 0.9999 { return simd_float3x3(1) } // already aligned
        let vx = simd_float3x3(rows: [
            SIMD3<Float>(   0, -v.z,  v.y),
            SIMD3<Float>( v.z,    0, -v.x),
            SIMD3<Float>(-v.y,  v.x,    0)
        ])
        return simd_float3x3(1) + vx + (vx*vx) * (1.0 / (1.0 + c))
    }
}
#endif

// MARK: - Shader Cache

/// Cache for shader instances to avoid recompilation
private final class ShaderCache {
    private struct CacheKey: Equatable {
        let size: CGSize
        let viewDir: SIMD3<Float>
        let edgeStrength: CGFloat
        let edgeHardness: CGFloat
        let specularStrength: CGFloat
        let shininess: CGFloat
        let tiltMix: CGFloat
        let fresnelPower: CGFloat
        
        static func ==(lhs: CacheKey, rhs: CacheKey) -> Bool {
            return lhs.size == rhs.size &&
                   lhs.viewDir == rhs.viewDir &&
                   lhs.edgeStrength == rhs.edgeStrength &&
                   lhs.edgeHardness == rhs.edgeHardness &&
                   lhs.specularStrength == rhs.specularStrength &&
                   lhs.shininess == rhs.shininess &&
                   lhs.tiltMix == rhs.tiltMix &&
                   lhs.fresnelPower == rhs.fresnelPower
        }
    }
    
    private var cachedShader: Shader?
    private var lastKey: CacheKey?
    
    func getShader(
        for size: CGSize,
        viewDir: SIMD3<Float>,
        edgeStrength: CGFloat,
        edgeHardness: CGFloat,
        specularStrength: CGFloat,
        shininess: CGFloat,
        tiltMix: CGFloat,
        fresnelPower: CGFloat,
        makeShader: () -> Shader
    ) -> Shader {
        let key = CacheKey(
            size: size,
            viewDir: viewDir,
            edgeStrength: edgeStrength,
            edgeHardness: edgeHardness,
            specularStrength: specularStrength,
            shininess: shininess,
            tiltMix: tiltMix,
            fresnelPower: fresnelPower
        )
        
        // Return cached shader if key matches
        if let cached = cachedShader, let last = lastKey, last == key {
            return cached
        }
        
        // Create and cache new shader
        let shader = makeShader()
        cachedShader = shader
        lastKey = key
        
        return shader
    }
}

// MARK: - View Modifier

/// A view modifier that applies a metallic matcap effect to any SwiftUI view
public struct MetallicEffectModifier: ViewModifier {
    public let matcapTexture: Image
    @Binding public var viewDirection: SIMD3<Float>
    public let edgeStrength: CGFloat
    public let edgeHardness: CGFloat
    public let specularStrength: CGFloat
    public let shininess: CGFloat
    public let tiltMix: CGFloat
    public let fresnelPower: CGFloat
    public let useMotion: Bool

    // Internal state for rendering
    @State private var renderTrigger = false
    @State private var shaderParameters: ShaderParameters?
    @State private var shaderCache = ShaderCache()
    
#if os(iOS)
    @State private var motionManager: MetallicMotionManager?
    @State private var displayLink: CADisplayLink?
#endif

    public init(
        matcapTexture: Image,
        viewDirection: Binding<SIMD3<Float>> = .constant(SIMD3<Float>(0, 0, 1)),
        edgeStrength: CGFloat = 6.0,
        edgeHardness: CGFloat = 0.5,
        specularStrength: CGFloat = 0.8,
        shininess: CGFloat = 32.0,
        tiltMix: CGFloat = 0.35,
        fresnelPower: CGFloat = 2.0,
        useMotion: Bool = false
    ) {
        self.matcapTexture = matcapTexture
        self._viewDirection = viewDirection
        self.edgeStrength = edgeStrength
        self.edgeHardness = edgeHardness
        self.specularStrength = specularStrength
        self.shininess = shininess
        self.tiltMix = tiltMix
        self.fresnelPower = fresnelPower
        self.useMotion = useMotion
    }

    private func makeShader(for size: CGSize, viewDir: SIMD3<Float>) -> Shader {
        return shaderCache.getShader(
            for: size,
            viewDir: viewDir,
            edgeStrength: edgeStrength,
            edgeHardness: edgeHardness,
            specularStrength: specularStrength,
            shininess: shininess,
            tiltMix: tiltMix,
            fresnelPower: fresnelPower
        ) {
            // This closure only runs when cache misses
            let v = simd_normalize(viewDir)
            return Shader(
                function: .init(library: ShadyGroundLibrary.default, name: "metallicMatcap"),
                arguments: [
                    .image(matcapTexture),
                    .float2(Float(size.width), Float(size.height)),
                    .float3(v.x, v.y, v.z),
                    .float(Float(edgeStrength)),
                    .float(Float(edgeHardness)),
                    .float(Float(specularStrength)),
                    .float(Float(shininess)),
                    .float(Float(tiltMix)),
                    .float(Float(fresnelPower))
                ]
            )
        }
    }

    public func body(content: Content) -> some View {
        GeometryReader { geometry in
            // Use parameters if available (motion mode), otherwise use binding
            let currentViewDir = shaderParameters?.viewDirection ?? viewDirection
            let _ = renderTrigger // Force re-render when display link updates
            
            content
                .layerEffect(
                    makeShader(for: geometry.size, viewDir: currentViewDir),
                    maxSampleOffset: CGSize(width: 3, height: 3)
                )
                .onAppear {
                    setupRendering()
                }
                .onDisappear {
                    teardownRendering()
                }
                .onChange(of: viewDirection) { oldValue, newValue in
                    // Handle external viewDirection changes (thread-safe)
                    if !useMotion, let params = shaderParameters {
                        params.viewDirection = newValue
                    }
                }
        }
    }

    // MARK: - Setup & Teardown
    
    private func setupRendering() {
        // Create thread-safe parameter container
        let params = ShaderParameters(viewDirection: viewDirection)
        shaderParameters = params
        
#if os(iOS)
        if useMotion {
            // Start motion updates on background thread
            let manager = MetallicMotionManager(parameters: params)
            manager.start()
            motionManager = manager
            
            // Auto-calibrate after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                manager.calibrate()
            }
        }
        
        // Setup DisplayLink for smooth rendering (always, regardless of motion)
        let link = CADisplayLink(target: DisplayLinkTarget { [weak params] in
            guard let params = params else { return }
            
            // Check if we need to update the view
            if params.needsUpdate {
                params.clearUpdateFlag()
                
                // Toggle render trigger to force SwiftUI update
                self.renderTrigger.toggle()
                
                // Update external binding if using motion
                if self.useMotion {
                    self.viewDirection = params.viewDirection
                }
            }
        }, selector: #selector(DisplayLinkTarget.update))
        
        link.add(to: .main, forMode: .common)
        displayLink = link
#endif
    }
    
    private func teardownRendering() {
#if os(iOS)
        displayLink?.invalidate()
        displayLink = nil
        motionManager?.stop()
        motionManager = nil
#endif
        shaderParameters = nil
    }
    
    // MARK: - Public API
    
    /// Calibrate the device orientation - call this when user holds phone in desired "neutral" position
    public func calibrate() {
#if os(iOS)
        motionManager?.calibrate()
#endif
    }
}

// MARK: - DisplayLink Target

#if os(iOS)
/// Helper class to avoid retain cycles with CADisplayLink
private final class DisplayLinkTarget {
    private let callback: () -> Void
    
    init(callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    @objc func update() {
        callback()
    }
}
#endif

// MARK: - View Extension

public extension View {
    /// Apply a metallic matcap effect to any SwiftUI view
    ///
    /// - Parameters:
    ///   - matcap: The matcap texture image (RGB = color, Alpha = specular map)
    ///   - viewDirection: 3D view direction for reflection calculations (binding allows external control)
    ///   - edgeStrength: Controls bevel depth and edge relief (default: 6.0, range: 0-20)
    ///   - edgeHardness: Controls edge character - higher = sharper edges (default: 0.5, range: 0-1)
    ///   - specularStrength: Intensity of specular highlights (default: 0.8, range: 0-2)
    ///   - shininess: Tightness of specular highlights (default: 32.0, range: 1-128)
    ///   - tiltMix: Blend between neutral and device tilt (default: 0.35, range: 0-1)
    ///   - fresnelPower: Edge lighting intensity (default: 2.0, range: 0-5)
    ///   - useMotion: Enable device motion tracking on iOS (default: false)
    ///
    /// ## Motion Tracking
    /// When `useMotion` is enabled:
    /// - Motion updates occur at 60fps on a background thread
    /// - Shader updates are synchronized to display refresh via CADisplayLink
    /// - Auto-calibration occurs 0.5s after motion starts
    /// - All parameter updates are thread-safe
    ///
    /// ## Performance
    /// - Edge computation uses 5x5 Gaussian blur for ultra-smooth results
    /// - DisplayLink ensures vsync-aligned rendering at 60fps
    /// - Background thread processing keeps UI responsive
    func metalEffect(
        matcap: Image,
        viewDirection: Binding<SIMD3<Float>> = .constant(SIMD3<Float>(0, 0, 1)),
        edgeStrength: CGFloat = 6.0,
        edgeHardness: CGFloat = 0.5,
        specularStrength: CGFloat = 0.8,
        shininess: CGFloat = 32.0,
        tiltMix: CGFloat = 0.35,
        fresnelPower: CGFloat = 2.0,
        useMotion: Bool = false
    ) -> some View {
        modifier(MetallicEffectModifier(
            matcapTexture: matcap,
            viewDirection: viewDirection,
            edgeStrength: edgeStrength,
            edgeHardness: edgeHardness,
            specularStrength: specularStrength,
            shininess: shininess,
            tiltMix: tiltMix,
            fresnelPower: fresnelPower,
            useMotion: useMotion
        ))
    }
}
