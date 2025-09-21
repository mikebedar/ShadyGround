//
//  WaveShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 wave(float2 position, SwiftUI::Layer layer, float amplitude, float frequency, float foregroundStripeWidth, float backgroundStripeWidth, float phase, float angleRadians, half4 backgroundColor, half4 foregroundColor) {
    // Rotate the coordinate system by the given angle
    float cosAngle = cos(angleRadians);
    float sinAngle = sin(angleRadians);
    
    // Apply rotation matrix to position
    float2 rotatedPos = float2(position.x * cosAngle - position.y * sinAngle, position.x * sinAngle + position.y * cosAngle);
    
    // Apply sine wave distortion to the Y coordinate
    float waveDistortion = sin(rotatedPos.x * frequency + phase) * amplitude;
    float distortedY = rotatedPos.y + waveDistortion;
    
    // Calculate total stripe cycle width
    float totalCycleWidth = foregroundStripeWidth + backgroundStripeWidth;
    
    // Create infinite alternating width stripes using modulo
    // Use fmod with proper handling of negative values to ensure infinite tiling
    float stripePosition = fmod(fmod(distortedY, totalCycleWidth) + totalCycleWidth, totalCycleWidth);
    
    // Determine if we're in a foreground or background stripe
    bool isForegroundStripe = stripePosition < foregroundStripeWidth;
    
    // Select the appropriate color
    half4 waveColor = isForegroundStripe ? foregroundColor : backgroundColor;
    
    return waveColor;
}
