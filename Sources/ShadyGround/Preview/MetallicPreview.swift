//
//  MetallicPreview.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/30/25.
//

import SwiftUI
import simd

@MainActor
public struct MetallicPreview: View {
    @State private var text: String = "GOLD"
    @State private var matcapImage: String = "BumpyGold"
    @State private var mixAmount: CGFloat = 0.8
    @State private var edgeStrength: CGFloat = 5.0
    @State private var mousePosition: CGPoint = .zero
    @State private var viewSize: CGSize = .zero
    @State private var viewDirection: SIMD3<Float> = SIMD3<Float>(0, 0, 1)
    
    private func updateViewDirection() {
        guard viewSize.width > 0, viewSize.height > 0 else {
            viewDirection = SIMD3<Float>(0, 0, 1)
            return
        }
        
        // Convert mouse position to normalized coordinates [-1, 1]
        let normalizedX = Float((mousePosition.x / viewSize.width) * 2 - 1)
        let normalizedY = Float((mousePosition.y / viewSize.height) * 2 - 1)
        
        // Create view direction from mouse position
        let x = normalizedX * 0.5
        let y = -normalizedY * 0.5  // Invert Y for natural feel
        let z = Float(1.0)
        
        viewDirection = simd_normalize(SIMD3<Float>(x, y, z))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Main preview with mouse tracking
            GeometryReader { geometry in
                ZStack {
                    // Dark gradient background
                    LinearGradient(
                        colors: [Color.black, Color(white: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Text(text)
                        .font(.system(size: 120, weight: .black))
                        .foregroundStyle(.white)
                        .metalEffect(
                            matcap: Image(matcapImage, bundle: .module),
                            viewDirection: $viewDirection,
                            mixAmount: mixAmount,
                            edgeStrength: edgeStrength,
                            useMotion: false
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onAppear {
                    viewSize = geometry.size
                    mousePosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    updateViewDirection()
                }
                .onChange(of: geometry.size) { _, newSize in
                    viewSize = newSize
                    updateViewDirection()
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        mousePosition = location
                        updateViewDirection()
                    case .ended:
                        // Reset to center when mouse leaves
                        mousePosition = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        updateViewDirection()
                    }
                }
            }
            
            Divider()
            
            // Parameter controls
            VStack(spacing: 16) {
                // Text input field
                HStack(spacing: 12) {
                    Text("Text:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    TextField("Enter text", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .font(.headline)
                }
                .padding(.horizontal)
                
                // Matcap preview
                HStack(spacing: 12) {
                    Text("Matcap:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    
                    Image(matcapImage, bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        }
                    
                    Text(matcapImage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Parameter sliders
                ParameterControlGrid {
                    NumericParameterControl(
                        title: "Mix Amount",
                        value: $mixAmount,
                        in: 0...1,
                        step: 0.05
                    )
                    
                    NumericParameterControl(
                        title: "Edge Strength",
                        value: $edgeStrength,
                        in: 0...20,
                        step: 0.5
                    )
                }
                
                // Instructions
                VStack(spacing: 4) {
                    Text("💡 Move your mouse over the text to change the viewing angle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Text("Mouse: (\(Int(mousePosition.x)), \(Int(mousePosition.y)))")
                        Text("Dir: (\(String(format: "%.2f", viewDirection.x)), \(String(format: "%.2f", viewDirection.y)), \(String(format: "%.2f", viewDirection.z)))")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary.opacity(0.7))
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.vertical, 12)
            .background(Color(white: 0.95))
        }
    }
}

#if DEBUG
#Preview("Metallic Effect") {
    MetallicPreview()
        .frame(width: 800, height: 600)
}
#endif
