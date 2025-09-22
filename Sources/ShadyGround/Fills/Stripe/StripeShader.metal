//
//  StripeShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Simple palette with up to 8 colors (consistent with SpiralStripes)
inline half4 paletteAt(int i, int n,
                       half4 c0, half4 c1, half4 c2, half4 c3,
                       half4 c4, half4 c5, half4 c6, half4 c7) {
    i = (n > 0) ? (i % n) : 0;
    switch (i) {
        case 0: return c0;  case 1: return c1;  case 2: return c2;  case 3: return c3;
        case 4: return c4;  case 5: return c5;  case 6: return c6;  default: return c7;
    }
}

[[ stitchable ]] half4 stripe(float2 position, SwiftUI::Layer layer, 
                             float stripeWidth, float angleRadians, float paletteCount,
                             half4 c0, half4 c1, half4 c2, half4 c3,
                             half4 c4, half4 c5, half4 c6, half4 c7) {
    // Rotate the coordinate system by the given angle
    float cosAngle = cos(angleRadians);
    float sinAngle = sin(angleRadians);

    // Apply rotation matrix to position
    float2 rotatedPos = float2(position.x * cosAngle - position.y * sinAngle, position.x * sinAngle + position.y * cosAngle);

    // Use the x-component of rotated position to determine stripe
    // This creates stripes perpendicular to the angle direction
    float stripePosition = rotatedPos.x;

    // Ensure minimum stripe width to avoid division by zero
    float safeStripeWidth = max(stripeWidth, 1.0);

    // Calculate which stripe we're in
    int stripeIndex = int(floor(stripePosition / safeStripeWidth));

    // Use palette to select color based on stripe index
    int n = clamp(int(paletteCount), 1, 8);
    int colorIndex = abs(stripeIndex) % n;

    // Select the appropriate color from palette
    half4 stripeColor = paletteAt(colorIndex, n, c0, c1, c2, c3, c4, c5, c6, c7);

    return stripeColor;
}
