//
//  File.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]]
half4 spiralStripes(
                    float2 position, SwiftUI::Layer layer,
                    float2 viewSize,
                    float stripesPerTurn,     // bands per 2π
                    float twist,              // strength of log(r) term
                    float2 centerOffsetPx,
                    float antialiasingLevel,  // 0.0 = off, 1.0 = light, 2.0 = medium, 3.0 = heavy
                    device const half4* colors, // Color Array
                    int colorCount
                    )
{
    float2 center = 0.5 * viewSize + centerOffsetPx;
    float2 p = position - center;

    // Polar pieces
    float r = max(length(p), 1e-4);
    float angleTurns = atan2(p.y, p.x) * (1.0f / (2.0f * M_PI_F)); // [-0.5, 0.5]

    // --- Periodic phase: combine, then wrap ---
    // One "unit" in phase == one stripe. pWrap ∈ [0,1) by construction, so no seam.
    float phase = stripesPerTurn * angleTurns + twist * log(r);
    float pWrap = fract(phase);                 // [0,1)

    // --- Palette (repeat cyclically) ---
    int n = max(colorCount, 1);
    int idx = clamp(int(floor(pWrap * float(n))), 0, n - 1);
    half4 base = colors[idx];
    
    if (antialiasingLevel > 0.0) {
        // --- Weighted sampling with Gaussian-like falloff for subtle antialiasing ---
        float aaWidth = antialiasingLevel;
        
        // Sample neighboring positions with multiple radii for better coverage
        float2 nrm = p / r;
        float2 tng = float2(-nrm.y, nrm.x);
        
        half4 weightedSum = half4(0.0);
        float totalWeight = 0.0;
        
        // Sample in a circular pattern with multiple radii
        for (int i = 0; i < 8; i++) {
            float angle = float(i) * (M_PI_F / 4.0); // 8 samples around the circle
            float2 direction = float2(cos(angle), sin(angle));
            
            // Sample at multiple distances for better coverage
            for (int j = 1; j <= 3; j++) {
                float distance = float(j) * aaWidth * 0.5; // 0.5, 1.0, 1.5 * aaWidth
                float2 offset = direction * distance;
                
                // Calculate phase at this sample position
                float phase = stripesPerTurn * (atan2(p.y + offset.y, p.x + offset.x) * (1.0f / (2.0f * M_PI_F))) + twist * log(length(p + offset));
                float pWrap = fract(phase);
                int idx = clamp(int(floor(pWrap * float(n))), 0, n - 1);
                half4 sampleColor = colors[idx];
                
                // Calculate weight using Gaussian-like falloff
                float weight = exp(-distance * distance / (aaWidth * aaWidth));
                
                weightedSum += sampleColor * half4(weight);
                totalWeight += weight;
            }
        }
        
        // Add center pixel with high weight
        float centerWeight = 2.0; // Higher weight for center
        weightedSum += base * half4(centerWeight);
        totalWeight += centerWeight;
        
        // Normalize by total weight for proper blending
        half4 finalColor = weightedSum / half4(totalWeight);
        
        return finalColor;
    } else {
        // No antialiasing - sharp edges
        return base;
    }
}

