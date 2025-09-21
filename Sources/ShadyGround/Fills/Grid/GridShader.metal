//
//  GridShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 grid(float2 position, SwiftUI::Layer layer, float spacing, float lineWidth, float angleRadians, half4 backgroundColor, half4 foregroundColor) {
    // Rotate the coordinate system by the given angle
    float cosAngle = cos(angleRadians);
    float sinAngle = sin(angleRadians);
    
    // Apply rotation matrix to position
    float2 rotatedPos = float2(position.x * cosAngle - position.y * sinAngle, position.x * sinAngle + position.y * cosAngle);
    
    // Ensure minimum spacing to avoid division by zero
    float safeSpacing = max(spacing, 1.0);
    
    // Calculate grid lines using modulo for infinite tiling
    float2 gridPos = rotatedPos / safeSpacing;
    
    // Calculate fractional parts for both x and y
    float2 gridFract = fract(gridPos);
    
    // Calculate distance from nearest grid line for both x and y
    // Distance to left/bottom edge
    float2 distToEdge = gridFract;
    // Distance to right/top edge  
    float2 distToNext = 1.0 - gridFract;
    // Take minimum distance to either edge
    float2 gridDist = min(distToEdge, distToNext);
    
    // Scale by spacing to get actual pixel distance
    float2 actualDist = gridDist * safeSpacing;
    
    // Find minimum distance to any grid line
    float minDist = min(actualDist.x, actualDist.y);
    
    // Create smooth line transition using smoothstep
    float lineFactor = 1.0 - smoothstep(0.0, lineWidth, minDist);
    
    // Interpolate between background and foreground colors
    half4 gridColor = mix(backgroundColor, foregroundColor, half(lineFactor));
    
    return gridColor;
}
