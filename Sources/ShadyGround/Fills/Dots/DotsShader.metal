//
//  DotsShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 dots(float2 position, SwiftUI::Layer layer, float dotSize, float spacing, float angleRadians, half4 backgroundColor, half4 foregroundColor) {
    // Rotate the coordinate system by the given angle
    float cosAngle = cos(angleRadians);
    float sinAngle = sin(angleRadians);
    
    // Apply rotation matrix to position
    float2 rotatedPos = float2(position.x * cosAngle - position.y * sinAngle, position.x * sinAngle + position.y * cosAngle);
    
    // Calculate which grid cell we're in using rotated coordinates
    float2 cell = floor(rotatedPos / max(spacing, 1.0));
    
    // Calculate position within the cell
    float2 cellPos = rotatedPos - cell * spacing;
    
    // Calculate distance from center of cell
    float2 center = spacing * 0.5;
    float distance = length(cellPos - center);
    
    // Create circular dot
    float dotRadius = dotSize * 0.5;
    bool isDot = distance <= dotRadius;
    
    // Select the appropriate color
    half4 dotColor = isDot ? foregroundColor : backgroundColor;
    
    return dotColor;
}
