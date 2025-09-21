//
//  File.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

inline half4 paletteAt(int i, int n,
                       half4 c0, half4 c1, half4 c2, half4 c3,
                       half4 c4, half4 c5, half4 c6, half4 c7,
                       half4 c8, half4 c9, half4 c10, half4 c11,
                       half4 c12, half4 c13, half4 c14, half4 c15)
{
    // modulo into [0, n)
    i = (n > 0) ? (i % n) : 0;
    switch (i) {
        case 0:  return c0;   case 1:  return c1;   case 2:  return c2;   case 3:  return c3;
        case 4:  return c4;   case 5:  return c5;   case 6:  return c6;   case 7:  return c7;
        case 8:  return c8;   case 9:  return c9;   case 10: return c10;  case 11: return c11;
        case 12: return c12;  case 13: return c13;  case 14: return c14;  default: return c15;
    }
}

[[ stitchable ]]
half4 spiralStripes(float2 position, SwiftUI::Layer layer,
                    float2 viewSize,       // passed from Swift via sizeAwareShader
                    float stripesPerTurn,  // bands per full 2π rotation
                    float twist,           // log-spiral twist factor (≈ 0.0…4.0)
                    float2 centerOffsetPx, // offset from center, in pixels
                    float aaPixels,        // edge AA width in pixels (≈ 1.0)
                    float paletteCount,    // 1…16
                    half4 c0, half4 c1, half4 c2, half4 c3,
                    half4 c4, half4 c5, half4 c6, half4 c7,
                    half4 c8, half4 c9, half4 c10, half4 c11,
                    half4 c12, half4 c13, half4 c14, half4 c15)
{
    // Center in pixel space
    float2 center = 0.5 * viewSize + centerOffsetPx;
    float2 p = position - center;

    // Polar coords
    float r = max(length(p), 1e-4);
    float a = atan2(p.y, p.x);          // [-π, π]
    float turns = (a + M_PI_F) / (2.0f * M_PI_F); // [0,1) wrap-friendly

    // Log spiral phase: stripes advance with angle and also with radius
    // Larger `twist` → tighter spiral toward center.
    float phase = stripesPerTurn * (a / (2.0f * M_PI_F)) + twist * log(r);

    // Integer stripe index and fractional position within the stripe
    float stripeIdxF = floor(phase);
    int stripeIdx = int(stripeIdxF);

    float frac = phase - stripeIdxF;            // [0,1)
    float distToBoundary = min(frac, 1.0 - frac); // distance to nearest stripe edge

    // Anti-alias in pixel units: convert phase-space delta to pixels by sampling two nearby points.
    // (Cheap approximation when derivatives aren’t available.)
    float2 dp = normalize(p) * max(aaPixels, 0.0001); // step radially ~1px
    float phase2 = stripesPerTurn * (atan2(p.y + dp.y, p.x + dp.x) / (2.0f * M_PI_F))
    + twist * log(length(p + dp));
    float dPhasePx = abs(phase2 - phase);
    float aa = clamp(distToBoundary / max(dPhasePx, 1e-4), 0.0, 1.0);
    // Sharpen a bit
    aa = smoothstep(0.0, 1.0, aa);

    // Pick base color by repeating palette
    int n = clamp(int(paletteCount), 1, 16);
    half4 baseColor = paletteAt(stripeIdx, n,
                                c0,c1,c2,c3,c4,c5,c6,c7,
                                c8,c9,c10,c11,c12,c13,c14,c15);

    // Optionally blend towards neighbor color near the edge for a tiny AA softness
    half4 nextColor = paletteAt(stripeIdx + 1, n,
                                c0,c1,c2,c3,c4,c5,c6,c7,
                                c8,c9,c10,c11,c12,c13,c14,c15);

    // Edge mix (small range near boundary). Feel free to tighten/loosen 0.25 factor.
    half edgeMix = half(smoothstep(0.75, 1.0, aa));
    half4 color = mix(nextColor, baseColor, edgeMix);

    return color;
}
