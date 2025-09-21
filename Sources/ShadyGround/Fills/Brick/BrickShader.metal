//
//  BrickShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 brick(float2 position, SwiftUI::Layer layer, float brickWidth, float brickHeight, float mortarWidth, float angle, half4 backgroundColor, half4 foregroundColor) {
    // Rotate the coordinate system by the given angle
    float cosAngle = cos(angle);
    float sinAngle = sin(angle);
    
    // Apply rotation matrix to position
    float2 rotatedPos = float2(position.x * cosAngle - position.y * sinAngle, position.x * sinAngle + position.y * cosAngle);
    
    // Create brick pattern with proper mortar spacing
    // Total cell size includes brick size plus mortar
    float2 totalCellSize = float2(brickWidth + mortarWidth, brickHeight + mortarWidth);
    float2 cellPos = rotatedPos / totalCellSize;
    
    // Get the current row and column
    float2 cellIndex = floor(cellPos);
    float2 cellCoord = fract(cellPos);
    
    // Offset every other row
    if (fract(cellIndex.y) > 0.5) {
        cellCoord.x += 0.5;
    }
    
    // Normalize mortar width to cell coordinates
    float mortarWidthNormalized = mortarWidth / totalCellSize.x;
    float mortarHeightNormalized = mortarWidth / totalCellSize.y;
    
    // Check for horizontal mortar (between rows)
    bool inHorizontalMortar = cellCoord.y < mortarHeightNormalized;
    
    // Check for vertical mortar (between bricks in same row)
    bool inVerticalMortar = cellCoord.x < mortarWidthNormalized || cellCoord.x > (1.0 - mortarWidthNormalized);
    
    // If in any mortar area, show background color (grout)
    if (inHorizontalMortar || inVerticalMortar) {
        return backgroundColor;
    }
    
    // Otherwise, show brick color
    return foregroundColor;
}
