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
    @State private var mixAmount: CGFloat = 0.9
    @State private var edgeStrength: CGFloat = 8.0
    @State private var currentMatcapIndex: Int = 0
    @State private var cachedMatcap: Image?
    
    private let matcapImages = [
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
            // Dark gradient background
            LinearGradient(
                colors: [Color.black, Color(white: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(alignment: .center, spacing: 72) {
                VStack(alignment: .center, spacing: 0) {
                    Text("Hello")
                        .font(.system(size: 80, weight: .black))

                    Image(systemName: "globe.asia.australia.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 128, minHeight: 128)
                        .padding()

                    Text("World")
                        .font(.system(size: 72, weight: .black))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .background(alignment: .center) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(style: .init(lineWidth: 8))
                }
                .metalEffect(
                    matcap: currentMatcap,
                    viewDirection: $motionViewDir,
                    mixAmount: mixAmount,
                    edgeStrength: edgeStrength,
                    useMotion: true
                )
                .onAppear {
                    loadCurrentMatcap()
                }
                .onChange(of: currentMatcapIndex) { _, _ in
                    loadCurrentMatcap()
                }
                .padding(.horizontal, 40)
                .onChange(of: motionViewDir) { _, newValue in
                    // Detect motion is working
                    if newValue != SIMD3<Float>(0, 0, 1) {
                        isMotionActive = true
                    }
                }

                Spacer()
                
                // Status and controls
                VStack(spacing: 16) {
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
                    
                    // Motion status indicator
                    HStack(spacing: 12) {
                        Circle()
                            .fill(isMotionActive ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                        
                        Text(isMotionActive ? "Motion Active" : "Motion Unavailable")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    // View direction indicator
                    VStack(alignment: .leading, spacing: 4) {
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
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    
                    // Controls
                    VStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Metallic Mix")
                                    .font(.caption)
                                Spacer()
                                Text(String(format: "%.0f%%", mixAmount * 100))
                                    .font(.caption.monospacedDigit())
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            
                            Slider(value: $mixAmount, in: 0...1, step: 0.05)
                        }
                        
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

#Preview {
    ContentView()
}
