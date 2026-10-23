//
//  ContentView.swift
//  MetalDemo
//
//  Created by Michael Bedar on 9/30/25.
//

import SwiftUI
import ShadyGround
import simd

struct ContentView: View {
    @State private var motionViewDir: SIMD3<Float> = SIMD3<Float>(0, 0, 1)
    @State private var isMotionActive: Bool = false
    @State private var edgeStrength: CGFloat = 6.0
    @State private var edgeHardness: CGFloat = 0.5
    @State private var specularStrength: CGFloat = 0.8
    @State private var shininess: CGFloat = 32.0
    @State private var tiltMix: CGFloat = 0.35
    @State private var fresnelPower: CGFloat = 2.0
    @State private var currentMatcapIndex: Int = 0
    @State private var cachedMatcap: Image?
    @State private var isShaderWarmedUp: Bool = false

    private let matcapImages = [
        "gold-specular",
        "293D21_ABC692_73B255_667C5C",
        "312C34_A2AAB3_61656A_808494",
        "736655_D9D8D5_2F281F_B1AEAB",
        "89204B_17080D_DA4377_F780B5",
        "8A6565_2E214D_D48A5F_ADA59C",
        "942967_D292B5_C76E9E_551A4C",
        "B62D33_E4868B_7E2D34_DD6469",
        "C8D1DC_575B62_818892_6E747B",
        "E6BF3C_5A4719_977726_FCFC82"
    ]

    private var currentMatcapName: String {
        matcapImages[currentMatcapIndex]
    }

    private var currentMatcap: Image {
        cachedMatcap ?? Image(currentMatcapName, bundle: .main)
    }

    var body: some View {
        ZStack {
            // Hidden view to pre-warm shader compilation on launch
            // This triggers Metal to compile the shader before the user interacts
            if !isShaderWarmedUp {
                Text("Warming up")
                    .font(.system(size: 1))
                    .foregroundStyle(.white)
                    .metalEffect(
                        matcap: currentMatcap,
                        viewDirection: $motionViewDir,
                        edgeStrength: edgeStrength,
                        edgeHardness: edgeHardness,
                        specularStrength: specularStrength,
                        shininess: shininess,
                        tiltMix: tiltMix,
                        fresnelPower: fresnelPower,
                        useMotion: false
                    )
                    .opacity(0.001) // Nearly invisible but still renders
                    .allowsHitTesting(false)
                    .onAppear {
                        // Mark as warmed up after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isShaderWarmedUp = true
                        }
                    }
            }
            
            MetallicEffectView(
                motionViewDir: $motionViewDir,
                isMotionActive: $isMotionActive,
                edgeStrength: $edgeStrength,
                edgeHardness: $edgeHardness,
                specularStrength: $specularStrength,
                shininess: $shininess,
                tiltMix: $tiltMix,
                fresnelPower: $fresnelPower,
                currentMatcapIndex: $currentMatcapIndex,
                cachedMatcap: $cachedMatcap,
                matcapImages: matcapImages,
                currentMatcapName: currentMatcapName,
                currentMatcap: currentMatcap,
                loadCurrentMatcap: loadCurrentMatcap,
                nextMatcap: nextMatcap,
                previousMatcap: previousMatcap
            )
        }
    }
    
    private func loadCurrentMatcap() {
        cachedMatcap = Image(currentMatcapName, bundle: .main)
    }

    private func nextMatcap() {
        currentMatcapIndex = (currentMatcapIndex + 1) % matcapImages.count
    }

    private func previousMatcap() {
        currentMatcapIndex = (currentMatcapIndex - 1 + matcapImages.count) % matcapImages.count
    }
}

// MARK: - Metallic Effect View
struct MetallicEffectView: View {
    @Binding var motionViewDir: SIMD3<Float>
    @Binding var isMotionActive: Bool
    @Binding var edgeStrength: CGFloat
    @Binding var edgeHardness: CGFloat
    @Binding var specularStrength: CGFloat
    @Binding var shininess: CGFloat
    @Binding var tiltMix: CGFloat
    @Binding var fresnelPower: CGFloat
    @Binding var currentMatcapIndex: Int
    @Binding var cachedMatcap: Image?
    let matcapImages: [String]
    let currentMatcapName: String
    let currentMatcap: Image
    let loadCurrentMatcap: () -> Void
    let nextMatcap: () -> Void
    let previousMatcap: () -> Void
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(white: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(alignment: .center, spacing: 0) {
                VStack(alignment: .center, spacing: 0) {
                    Text("METALLIC")
                        .font(.system(size: 80, weight: .black))

                    Image(systemName: "globe.asia.australia.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 128, minHeight: 128)
                        .padding()

                    Text("EFFECT")
                        .font(.system(size: 72, weight: .black))
                }
                .padding()
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(alignment: .center) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(style: .init(lineWidth: 4))
                }
                .metalEffect(
                    matcap: currentMatcap,
                    viewDirection: $motionViewDir,
                    edgeStrength: edgeStrength,
                    edgeHardness: edgeHardness,
                    specularStrength: specularStrength,
                    shininess: shininess,
                    tiltMix: tiltMix,
                    fresnelPower: fresnelPower,
                    useMotion: true
                )
                .onAppear {
                    loadCurrentMatcap()
                    // Check if motion is already active (device might be tilted)
                    let defaultDir = SIMD3<Float>(0, 0, 1)
                    let threshold: Float = 0.1
                    if simd_length(motionViewDir - defaultDir) > threshold {
                        isMotionActive = true
                    }
                }
                .onChange(of: currentMatcapIndex) { _, _ in
                    loadCurrentMatcap()
                }
                .padding(.horizontal, 40)
                .onChange(of: motionViewDir) { _, newValue in
                    // Detect motion is working - check if we're getting meaningful updates
                    let defaultDir = SIMD3<Float>(0, 0, 1)
                    let threshold: Float = 0.1
                    if simd_length(newValue - defaultDir) > threshold {
                        isMotionActive = true
                    }
                }

                // Status and controls
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        // Matcap selector
                        HStack(spacing: 20) {
                            Button(action: previousMatcap) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }

                            VStack(spacing: 6) {
                                Image(currentMatcapName, bundle: .main)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(10)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.white.opacity(0.3), lineWidth: 2)
                                    }

                                Text("\(currentMatcapIndex + 1) / \(matcapImages.count)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.5))
                            }

                            Button(action: nextMatcap) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)

                        // View direction indicator
                        VStack(alignment: .center, spacing: 4) {
                            Text("Tilt Device:")
                                .font(.caption2.bold())
                                .foregroundStyle(.white.opacity(0.5))

                            HStack(spacing: 20) {
                                VStack(spacing: 2) {
                                    Text("X")
                                        .font(.caption2)
                                    Text(String(format: "%.2f", motionViewDir.x))
                                        .font(.caption.monospacedDigit())
                                }
                                VStack(spacing: 2) {
                                    Text("Y")
                                        .font(.caption2)
                                    Text(String(format: "%.2f", motionViewDir.y))
                                        .font(.caption.monospacedDigit())
                                }
                                VStack(spacing: 2) {
                                    Text("Z")
                                        .font(.caption2)
                                    Text(String(format: "%.2f", motionViewDir.z))
                                        .font(.caption.monospacedDigit())
                                }
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            .containerRelativeFrame(.horizontal, count: 3, span: 1, spacing: 20, alignment: .center)

                            HStack(spacing: 12) {
                                Circle()
                                    .fill(isMotionActive ? Color.green : Color.red)
                                    .frame(width: 12, height: 12)

                                Text(isMotionActive ? "Motion Active" : "Motion Unavailable")
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            if isMotionActive {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)

                                    Text("Auto-calibrated")
                                        .font(.caption2)
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }

                    // Controls
                    HStack {
                        VStack(spacing: 12) {


                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("3D Depth")
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.1f", edgeStrength))
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.white.opacity(0.7))

                                Slider(value: $edgeStrength, in: 0...20, step: 0.5)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Edge Hardness")
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.1f", edgeHardness))
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.white.opacity(0.7))

                                Slider(value: $edgeHardness, in: 0...1, step: 0.1)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Specular")
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.1f", specularStrength))
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.white.opacity(0.7))

                                Slider(value: $specularStrength, in: 0...2, step: 0.1)
                            }
                        }
                        VStack(spacing: 12) {

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Shininess")
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.0f", shininess))
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.white.opacity(0.7))

                                Slider(value: $shininess, in: 1...256, step: 1)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Tilt Mix")
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.1f", tiltMix))
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.white.opacity(0.7))

                                Slider(value: $tiltMix, in: 0...1, step: 0.05)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Fresnel Power")
                                        .font(.caption)
                                    Spacer()
                                    Text(String(format: "%.1f", fresnelPower))
                                        .font(.caption.monospacedDigit())
                                }
                                .foregroundStyle(.white.opacity(0.7))

                                Slider(value: $fresnelPower, in: 0.5...5, step: 0.1)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)

                    Text("Tilt your device to see the metallic effect")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .statusBar(hidden: true)
    }
}

#Preview {
    ContentView()
}

