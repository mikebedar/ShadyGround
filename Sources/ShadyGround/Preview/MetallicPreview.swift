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
    @State private var edgeStrength: CGFloat = 6.0
    @State private var edgeHardness: CGFloat = 0.5
    @State private var specularStrength: CGFloat = 0.8
    @State private var shininess: CGFloat = 32.0
    @State private var tiltMix: CGFloat = 0.35
    @State private var fresnelPower: CGFloat = 2.0
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
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Text(text)
                        .font(.system(size: 120, weight: .black))
                        .foregroundStyle(.white)
                        .metalEffect(
                            matcap: Image(matcapImage, bundle: .module),
                            viewDirection: $viewDirection,
                            edgeStrength: edgeStrength,
                            edgeHardness: edgeHardness,
                            specularStrength: specularStrength,
                            shininess: shininess,
                            tiltMix: tiltMix,
                            fresnelPower: fresnelPower,
                            useMotion: false
                        )
                }
                .background {
                    LinearGradient(
                        colors: [Color.black, Color(white: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
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
                        mousePosition = CGPoint(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
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
                        title: "Edge Strength",
                        value: $edgeStrength,
                        in: 0...20,
                        step: 0.5
                    )
                    
                    NumericParameterControl(
                        title: "Edge Hardness",
                        value: $edgeHardness,
                        in: 0...1,
                        step: 0.05
                    )
                    
                    NumericParameterControl(
                        title: "Specular",
                        value: $specularStrength,
                        in: 0...2,
                        step: 0.1
                    )
                    
                    NumericParameterControl(
                        title: "Shininess",
                        value: $shininess,
                        in: 1...128,
                        step: 1
                    )
                    
                    NumericParameterControl(
                        title: "Tilt Mix",
                        value: $tiltMix,
                        in: 0...1,
                        step: 0.05
                    )
                    
                    NumericParameterControl(
                        title: "Fresnel",
                        value: $fresnelPower,
                        in: 0...5,
                        step: 0.1
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

// MARK: - Metal2 Preview

@MainActor
public struct MetallicPreview2: View {
    @State private var text: String = "METAL2"
    @State private var matcapImage: String = "BumpyGold"
    @State private var edgeStrength: CGFloat = 6.0
    @State private var specularStrength: CGFloat = 0.8
    @State private var shininess: CGFloat = 32.0
    @State private var tiltMix: CGFloat = 0.35
    @State private var fresnelPower: CGFloat = 2.0
    @State private var mousePosition: CGPoint = .zero
    @State private var viewSize: CGSize = .zero
    @State private var viewDirection: SIMD3<Float> = SIMD3<Float>(0, 0, 1)
    @State private var selectedPreset: String = "Custom"
    
    private let presets = ["Custom", "Gold", "Chrome", "Brushed"]
    
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
            GeometryReader { geometry in
                ZStack(alignment: .center) {
                    Text(text)
                        .font(.system(size: 120, weight: .black))
                        .foregroundStyle(.white)
                        .metalEffect(
                            matcap: Image(matcapImage, bundle: .module),
                            viewDirection: $viewDirection,
                            edgeStrength: edgeStrength,
                            edgeHardness: 0.5,
                            specularStrength: specularStrength,
                            shininess: shininess,
                            tiltMix: tiltMix,
                            fresnelPower: fresnelPower,
                            useMotion: false
                        )
                }
                .background {
                    LinearGradient(
                        colors: [Color.black, Color(white: 0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
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
                        mousePosition = CGPoint(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
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
                
                // Preset selector
                HStack(spacing: 12) {
                    Text("Preset:")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    
                    Picker("Preset", selection: $selectedPreset) {
                        ForEach(presets, id: \.self) { preset in
                            Text(preset).tag(preset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedPreset) { _, newPreset in
                        applyPreset(newPreset)
                    }
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
                        title: "Edge Strength",
                        value: $edgeStrength,
                        in: 0...20,
                        step: 0.5
                    )
                    
                    NumericParameterControl(
                        title: "Specular",
                        value: $specularStrength,
                        in: 0...2,
                        step: 0.1
                    )
                    
                    NumericParameterControl(
                        title: "Shininess",
                        value: $shininess,
                        in: 1...128,
                        step: 1
                    )
                    
                    NumericParameterControl(
                        title: "Tilt Mix",
                        value: $tiltMix,
                        in: 0...1,
                        step: 0.05
                    )
                    
                    NumericParameterControl(
                        title: "Fresnel",
                        value: $fresnelPower,
                        in: 0...5,
                        step: 0.1
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
    
    private func applyPreset(_ preset: String) {
        switch preset {
        case "Gold":
            edgeStrength = 6.0
            specularStrength = 0.85
            shininess = 48.0
            tiltMix = 0.35
            fresnelPower = 2.2
        case "Chrome":
            edgeStrength = 8.0
            specularStrength = 0.95
            shininess = 80.0
            tiltMix = 0.45
            fresnelPower = 2.8
        case "Brushed":
            edgeStrength = 4.0
            specularStrength = 0.5
            shininess = 16.0
            tiltMix = 0.2
            fresnelPower = 1.5
        default:
            break // Keep current values for Custom
        }
    }
}

#if DEBUG
#Preview("Metallic Effect") {
    MetallicPreview()
}

#Preview("Metallic Effect 2") {
    MetallicPreview2()
}
#endif
