//
//  SPMBundleTest.swift
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

import SwiftUI

/// Test to verify SPM bundle shader loading works correctly
@MainActor
public struct SPMBundleTest: View {
    @State private var testStatus: String = "Testing..."
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 30) {
            Text("SPM Bundle Shader Test")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Status: \(testStatus)")
                .font(.headline)
                .foregroundColor(.secondary)
            
            // Test 1: Very obvious checkerboard
            VStack {
                Text("Checkerboard Test")
                    .font(.headline)
                CheckerboardBackground(
                    cellSize: 40,
                    angle: .pi / 4, // 45 degrees
                    backgroundColor: .blue,
                    foregroundColor: .red
                )
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .border(.black, width: 2)
            }
            
            // Test 2: Very obvious stripe
            VStack {
                Text("Stripe Test")
                    .font(.headline)
                StripeBackground(
                    stripeWidth: 50,
                    angle: .pi / 4, // 45 degrees
                    backgroundColor: .yellow,
                    foregroundColor: .green
                )
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .border(.black, width: 2)
            }
            
            // Test 3: Dots pattern
            VStack {
                Text("Dots Test")
                    .font(.headline)
                DotsBackground(
                    dotSize: 12,
                    spacing: 25,
                    angle: .pi / 6, // 30 degrees
                    backgroundColor: .purple,
                    foregroundColor: .orange
                )
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .border(.black, width: 2)
            }
            
            // Test 4: Multiple variations
            HStack(spacing: 20) {
                VStack {
                    Text("Small Cells")
                    CheckerboardBackground(
                        cellSize: 15,
                        angle: .pi / 6, // 30 degrees
                        backgroundColor: .orange,
                        foregroundColor: .purple
                    )
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                VStack {
                    Text("Vertical Stripes")
                    StripeBackground(
                        stripeWidth: 25,
                        angle: .pi / 2, // 90 degrees
                        backgroundColor: .pink,
                        foregroundColor: .cyan
                    )
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            Text("If you see solid colors instead of patterns, the SPM bundle shaders aren't loading")
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
        .onAppear {
            testStatus = "SPM Bundle approach with ShaderLibrary.bundle(.module)"
        }
    }
}

#Preview("SPM Bundle Test") {
    SPMBundleTest()
}
