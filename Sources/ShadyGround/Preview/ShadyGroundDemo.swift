//
//  ShadyGroundDemo.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

/// A comprehensive demo showcasing all available shader effects
@MainActor
public struct ShadyGroundDemo: View {
    @State private var selectedEffect: String = "Checkerboard"
    @State private var selectedCategory: String = "All"
    
    private let effects: [String: any ShaderEffect.Type] = [
            "Spiral": SpiralBackground.self,
            "Checkerboard": CheckerboardBackground.self,
            "Stripe": StripeBackground.self,
            "Dots": DotsBackground.self,
            "Wave": WaveBackground.self,
            "Grid": GridBackground.self,
            "Noise": NoiseBackground.self,
        ]
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar with effect list
            List {
                Section("Categories") {
                    ForEach(ShaderEffectRegistry.categories, id: \.self) { category in
                        Button(category) {
                            selectedCategory = category
                        }
                        .foregroundColor(selectedCategory == category ? .accentColor : .primary)
                    }
                }
                
                Section("Effects") {
                    ForEach(ShaderEffectRegistry.allEffects, id: \.name) { effect in
                        if selectedCategory == "All" || effect.category == selectedCategory {
                            Button(effect.name) {
                                selectedEffect = effect.name
                            }
                            .foregroundColor(selectedEffect == effect.name ? .accentColor : .primary)
                        }
                    }
                }
            }
            .navigationTitle("ShadyGround")
        } detail: {
            // Main preview area
            if let effectType = effects[selectedEffect] {
                ShaderEffectPreviewContainer(effectType: effectType)
            } else {
                ContentUnavailableView(
                    "Select an Effect",
                    systemImage: "slider.horizontal.3",
                    description: Text("Choose a shader effect from the sidebar to see its preview and controls")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// A container that dynamically creates previews for any shader effect
@MainActor
private struct ShaderEffectPreviewContainer: View {
    let effectType: any ShaderEffect.Type
    
    var body: some View {
        VStack(spacing: 0) {
            // Effect title and description
            VStack(alignment: .leading, spacing: 8) {
                Text(effectType.effectName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(effectType.effectDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Category: \(effectType.effectCategory)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial)
            
            // Create the appropriate preview based on effect type
            previewForEffect(effectType)
                .frame(maxWidth: CGFloat.infinity, maxHeight: CGFloat.infinity)
        }
        .navigationTitle("")
    }
    
    @ViewBuilder
    private func previewForEffect(_ effectType: any ShaderEffect.Type) -> some View {
        switch effectType {
        case is CheckerboardBackground.Type:
            CheckerboardPreview()
        case is StripeBackground.Type:
            StripePreview()
        case is DotsBackground.Type:
            DotsPreview()
        case is WaveBackground.Type:
            WavePreview()
        case is GridBackground.Type:
            GridPreview()
        case is NoiseBackground.Type:
            NoisePreview()
        case is SpiralBackground.Type:
            SpiralPreview()
        default:
            Text("Preview not available")
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - SwiftUI Preview

#Preview("ShadyGround Gallery") {
    ShadyGroundDemo()
        .frame(width: 600, height: 700, alignment: .topLeading)
}
