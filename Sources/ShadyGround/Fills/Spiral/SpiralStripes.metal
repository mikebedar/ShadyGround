//
//  File.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/21/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

inline half4 paletteAt(int i,
                       int n,
                       half4 c0, half4 c1, half4 c2, half4 c3,
                       half4 c4, half4 c5, half4 c6, half4 c7,
                       half4 c8, half4 c9, half4 c10, half4 c11,
                       half4 c12, half4 c13, half4 c14, half4 c15)
{
    i = (n > 0) ? (i % n) : 0;
    switch (i) {
        case 0: return c0;  case 1: return c1;  case 2: return c2;  case 3: return c3;
        case 4: return c4;  case 5: return c5;  case 6: return c6;  case 7: return c7;
        case 8: return c8;  case 9: return c9;  case 10: return c10; case 11: return c11;
        case 12: return c12; case 13: return c13; case 14: return c14; default: return c15;
    }
}

inline float diff01(float a, float b) {
    float d = a - b;           // any real
    return d - round(d);       // fold to (-0.5, 0.5]
}

[[ stitchable ]]
half4 spiralStripes(float2 position, SwiftUI::Layer layer,
                    float2 viewSize,
                    float stripesPerTurn,     // bands per 2π
                    float twist,              // strength of log(r) term
                    float2 centerOffsetPx,
                    float paletteCount,       // 1…16
                    half4 c0, half4 c1, half4 c2, half4 c3,
                    half4 c4, half4 c5, half4 c6, half4 c7,
                    half4 c8, half4 c9, half4 c10, half4 c11,
                    half4 c12, half4 c13, half4 c14, half4 c15)
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
    float distToEdge = min(pWrap, 1.0 - pWrap); // distance to nearest stripe boundary

    // --- Simple AA using fixed pixel step ---
    float aaPixels = 1.0; // Fixed AA width
    float2 nrm = p / r;
    float2 tng = float2(-nrm.y, nrm.x);
    float2 dpR = nrm * aaPixels;
    float2 dpT = tng * aaPixels;

    float phaseR = stripesPerTurn *
    (atan2(p.y + dpR.y, p.x + dpR.x) * (1.0f / (2.0f * M_PI_F)))
    + twist * log(length(p + dpR));
    float phaseT = stripesPerTurn *
    (atan2(p.y + dpT.y, p.x + dpT.x) * (1.0f / (2.0f * M_PI_F)))
    + twist * log(length(p + dpT));

    // Wrap both neighbors too, then take minimal signed difference.
    float dR = diff01(fract(phaseR), pWrap);
    float dT = diff01(fract(phaseT), pWrap);
    float bandsPerPx = length(float2(dR, dT));      // how fast pWrap changes per pixel
    float aaBands = max(aaPixels, 0.0001) * max(bandsPerPx, 1e-5);

    // Coverage: 0 at edge → 1 mid-stripe (smooth and seam-free)
    float coverage = smoothstep(0.0, aaBands, distToEdge);

    // --- Palette (repeat cyclically) ---
    int n = clamp(int(paletteCount), 1, 16);
    int idx  = clamp(int(floor(pWrap * float(n))), 0, n - 1);
    int idxN = (idx + 1) % n;

    half4 base = paletteAt(idx, n, c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,c14,c15);
    half4 next = paletteAt(idxN, n, c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13,c14,c15);

    // Slight cross-fade near the edge for crisp AA
    half4 color = mix(next, base, half(coverage));
    return color;
}

