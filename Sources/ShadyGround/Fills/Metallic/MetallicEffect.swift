//
//  MetallicEffect.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/30/25.
//

import SwiftUI
#if os(iOS)
import CoreMotion
#endif
import simd

/// A view modifier that applies a metallic matcap effect to any SwiftUI view
public struct MetallicEffectModifier: ViewModifier {
    public let matcapTexture: Image
    @Binding public var viewDirection: SIMD3<Float>
    public let mixAmount: CGFloat
    public let edgeStrength: CGFloat
    public let useMotion: Bool
    
    #if os(iOS)
    @State private var motionManager: CMMotionManager?
    @State private var motionViewDir: SIMD3<Float> = SIMD3<Float>(0, 0, 1)
    #endif
    
    public init(
        matcapTexture: Image,
        viewDirection: Binding<SIMD3<Float>> = .constant(SIMD3<Float>(0, 0, 1)),
        mixAmount: CGFloat = 0.9,
        edgeStrength: CGFloat = 8.0,
        useMotion: Bool = false
    ) {
        self.matcapTexture = matcapTexture
        self._viewDirection = viewDirection
        self.mixAmount = mixAmount
        self.edgeStrength = edgeStrength
        self.useMotion = useMotion
    }
    
    private var currentViewDir: SIMD3<Float> {
        #if os(iOS)
        return useMotion ? motionViewDir : viewDirection
        #else
        return viewDirection
        #endif
    }
    
    private func makeShader(for size: CGSize) -> Shader {
        let viewDir = currentViewDir
        
        return Shader(
            function: .init(library: ShadyGroundLibrary.default, name: "metallic"),
            arguments: [
                .image(matcapTexture),
                .float2(Float(size.width), Float(size.height)),
                .float3(viewDir.x, viewDir.y, viewDir.z),
                .float(Float(mixAmount)),
                .float(Float(edgeStrength))
            ]
        )
    }
    
    public func body(content: Content) -> some View {
        GeometryReader { geometry in
            let _ = currentViewDir  // Force dependency on viewDirection
            content
                .layerEffect(
                    makeShader(for: geometry.size),
                    maxSampleOffset: CGSize(width: 4, height: 4) // Multi-scale sampling up to 3px away
                )
                .onAppear {
                    if useMotion {
                        startMotionUpdates()
                    }
                }
                .onDisappear {
                    stopMotionUpdates()
                }
        }
    }
    
    private func startMotionUpdates() {
        #if os(iOS)
        let manager = CMMotionManager()
        
        // Check if device motion is available before starting
        guard manager.isDeviceMotionAvailable else {
            return  // Silently fail - motion not available
        }
        
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [self] motion, error in
            guard let motion = motion else {
                // Silently ignore errors - CoreMotion permission warnings are normal
                return
            }
            
            let attitude = motion.attitude
            let x = Float(sin(attitude.yaw) * cos(attitude.pitch))
            let y = Float(sin(attitude.pitch))
            let z = Float(cos(attitude.yaw) * cos(attitude.pitch))
            
            let newDir = SIMD3<Float>(x, y, z)
            motionViewDir = newDir
            // Don't update the binding - just use internal state for motion
        }
        
        motionManager = manager
        #endif
    }
    
    private func stopMotionUpdates() {
        #if os(iOS)
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil
        #endif
    }
}

// MARK: - View Extension

public extension View {
    /// Applies a metallic matcap effect to the view
    ///
    /// - Parameters:
    ///   - matcap: The matcap texture Image to use for metallic reflections
    ///   - viewDirection: Binding to control viewing angle (for manual/animated control)
    ///   - mixAmount: Blend strength between original and metallic (0-1, default: 0.9)
    ///   - edgeStrength: Surface relief intensity (0-20, default: 8.0)
    ///   - useMotion: Enable iOS device motion tracking (default: false)
    /// - Returns: View with metallic effect applied
    func metalEffect(
        matcap: Image,
        viewDirection: Binding<SIMD3<Float>> = .constant(SIMD3<Float>(0, 0, 1)),
        mixAmount: CGFloat = 0.9,
        edgeStrength: CGFloat = 8.0,
        useMotion: Bool = false
    ) -> some View {
        modifier(MetallicEffectModifier(
            matcapTexture: matcap,
            viewDirection: viewDirection,
            mixAmount: mixAmount,
            edgeStrength: edgeStrength,
            useMotion: useMotion
        ))
    }
}
