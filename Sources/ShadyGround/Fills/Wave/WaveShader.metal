//
//  WaveShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 wave(float2 position, SwiftUI::Layer layer, 
                           float amplitude, float frequency, float stripeWidth, 
                           float backgroundStripeWidth, float phase, float angleRadians,
                           device const half4* colors, int colorCount) {
    // Rotate the coordinate system by the given angle
    float cosAngle = cos(angleRadians);
    float sinAngle = sin(angleRadians);
    
    // Apply rotation matrix to position
    float2 rotatedPos = float2(position.x * cosAngle - position.y * sinAngle, position.x * sinAngle + position.y * cosAngle);
    
    // Apply sine wave distortion to the Y coordinate
    float waveDistortion = sin(rotatedPos.x * frequency + phase) * amplitude;
    float distortedY = rotatedPos.y + waveDistortion;
    
    // Use palette to select color based on stripe index
    int n = max(colorCount, 1);
    
    // Calculate total stripe cycle width (use stripeWidth as the base stripe width)
    float totalStripeWidth = stripeWidth;
    
    // Create stripes based on the distorted Y coordinate
    float stripePosition = fmod(fmod(distortedY, totalStripeWidth * float(n)) + totalStripeWidth * float(n), totalStripeWidth * float(n));
    
    // Calculate which stripe we're in based on position
    int stripeIndex = int(floor(stripePosition / totalStripeWidth));
    
    // Calculate color index
    int colorIndex = abs(stripeIndex) % n;
    
    // Select the appropriate color from palette
    half4 waveColor = colors[colorIndex];
    
    return waveColor;
}
