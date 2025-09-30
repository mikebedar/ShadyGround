//
//  StripeShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 stripe(float2 position, SwiftUI::Layer layer, 
                             float stripeWidth, float angleRadians,
                             device const half4* colors, int colorCount) {
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
    int n = max(colorCount, 1);
    int colorIndex = abs(stripeIndex) % n;
    half4 stripeColor = colors[colorIndex];

    return stripeColor;
}
