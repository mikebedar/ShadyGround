//
//  CheckerboardShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 checkerboard(float2 position, SwiftUI::Layer layer, float cellSizePx, float angleRadians, half4 backgroundColor, half4 foregroundColor) {
    // Rotate the coordinate system by the given angle
    float cosAngle = cos(angleRadians);
    float sinAngle = sin(angleRadians);
    
    // Apply rotation matrix to position
    float2 rotatedPos = float2(position.x * cosAngle - position.y * sinAngle, position.x * sinAngle + position.y * cosAngle);
    
    // Calculate which cell we're in using rotated coordinates
    float2 cell = floor(rotatedPos / max(cellSizePx, 1.0));

    // Use integer parity to determine if this cell should be foreground
    bool isForeground = ((int(cell.x) + int(cell.y)) & 1) == 1;

    // Select the appropriate color
    half4 checkerColor = isForeground ? foregroundColor : backgroundColor;

    return checkerColor;
}
