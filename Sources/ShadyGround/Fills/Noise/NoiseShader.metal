//
//  NoiseShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/20/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// High-quality pseudo-random function with better distribution
float random(float2 st) {
    return fract(sin(dot(st, float2(12.9898, 78.233))) * 43758.5453);
}

// Better random function for gradients
float2 random2(float2 st) {
    st = float2(dot(st, float2(127.1, 311.7)),
                dot(st, float2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(st) * 43758.5453123);
}

// High-frequency random noise for TV static
float staticNoise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    
    // Get random values at each corner
    float a = random(i);
    float b = random(i + float2(1.0, 0.0));
    float c = random(i + float2(0.0, 1.0));
    float d = random(i + float2(1.0, 1.0));
    
    // Simple bilinear interpolation for sharp transitions
    float2 u = f;
    float top = mix(a, b, u.x);
    float bottom = mix(c, d, u.x);
    return mix(top, bottom, u.y);
}

// Cellular noise for organic patterns
float cellularNoise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    
    float minDist = 1.0;
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 neighbor = float2(float(x), float(y));
            float2 point = random2(i + neighbor) * 0.5 + 0.5;
            float2 diff = neighbor + point - f;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }
    
    return minDist;
}

// Smooth interpolation function
float smoothstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// Improved smoothstep for better noise transitions
float smootherstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 2D Perlin noise with gradient vectors
float noise(float2 st) {
    float2 i = floor(st);
    float2 f = fract(st);
    
    // Get gradient vectors for each corner
    float2 u = f * f * (3.0 - 2.0 * f); // Smooth interpolation
    
    // Calculate dot products with gradient vectors
    float2 gradient1 = random2(i);
    float2 gradient2 = random2(i + float2(1.0, 0.0));
    float2 gradient3 = random2(i + float2(0.0, 1.0));
    float2 gradient4 = random2(i + float2(1.0, 1.0));
    
    float dot1 = dot(gradient1, f);
    float dot2 = dot(gradient2, f - float2(1.0, 0.0));
    float dot3 = dot(gradient3, f - float2(0.0, 1.0));
    float dot4 = dot(gradient4, f - float2(1.0, 1.0));
    
    // Interpolate the dot products
    float top = mix(dot1, dot2, u.x);
    float bottom = mix(dot3, dot4, u.x);
    
    return mix(top, bottom, u.y);
}

// Simplex noise for more natural patterns
float simplexNoise(float2 st) {
    const float K1 = 0.366025404; // (sqrt(3)-1)/2
    const float K2 = 0.211324865; // (3-sqrt(3))/6
    
    // First corner
    float2 i = floor(st + (st.x + st.y) * K1);
    float2 a = st - i + (i.x + i.y) * K2;
    
    // Other corners
    float2 o = (a.x < a.y) ? float2(0.0, 1.0) : float2(1.0, 0.0);
    float2 b = a - o + K2;
    float2 c = a - 1.0 + 2.0 * K2;
    
    // Hash the corners
    float3 h = max(0.5 - float3(dot(a, a), dot(b, b), dot(c, c)), 0.0);
    float3 n = h * h * h * h * float3(dot(a, random2(i)), dot(b, random2(i + o)), dot(c, random2(i + 1.0)));
    
    return dot(n, float3(70.0, 70.0, 70.0));
}

// Fractal noise with multiple octaves and turbulence
float fractalNoise(float2 st, float octaves, float persistence) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;
    
    // Clamp octaves to prevent infinite loops
    int numOctaves = min(int(octaves), 8);
    
    for (int i = 0; i < numOctaves; i++) {
        float noiseValue = noise(st * frequency);
        value += abs(noiseValue) * amplitude; // Use absolute value for turbulence effect
        maxValue += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
    }
    
    // Normalize to 0-1 range
    return maxValue > 0.0 ? (value / maxValue) : 0.0;
}

// Ridged fractal noise for more dramatic patterns
float ridgedNoise(float2 st, float octaves, float persistence) {
    float value = 0.0;
    float amplitude = 1.0;
    float frequency = 1.0;
    float maxValue = 0.0;
    
    int numOctaves = min(int(octaves), 8);
    
    for (int i = 0; i < numOctaves; i++) {
        float noiseValue = noise(st * frequency);
        float ridgedValue = 1.0 - abs(noiseValue);
        ridgedValue = ridgedValue * ridgedValue; // Square for more dramatic ridges
        value += ridgedValue * amplitude;
        maxValue += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
    }
    
    return maxValue > 0.0 ? (value / maxValue) : 0.0;
}

[[ stitchable ]] half4 noise(float2 position, SwiftUI::Layer layer, float scale, float intensity, float octaves, float persistence, float seed, float angleRadians, half4 backgroundColor, half4 foregroundColor) {
    // Rotate the coordinate system by the given angle
    float cosAngle = cos(angleRadians);
    float sinAngle = sin(angleRadians);
    
    // Apply rotation matrix to position
    float2 rotatedPos = float2(position.x * cosAngle - position.y * sinAngle, position.x * sinAngle + position.y * cosAngle);
    
    // Better scaling for visible noise
    float adjustedScale = scale * 0.2; // Reasonable scale
    float2 noisePos = rotatedPos * adjustedScale + float2(seed * 100.0, seed * 150.0);
    
    // Generate primary noise layer
    float primaryNoise = fractalNoise(noisePos, octaves, persistence);
    
    // Add high-frequency static layer
    float2 staticPos = rotatedPos * adjustedScale * 15.0 + float2(seed * 200.0, seed * 300.0);
    float staticLayer = staticNoise(staticPos);
    
    // Combine the noise layers with better weighting
    float combinedNoise = primaryNoise * 0.6 + staticLayer * 0.4;
    
    // Apply moderate contrast enhancement
    combinedNoise = pow(combinedNoise, 0.7);
    
    // Add some digital artifacts for TV static effect
    float digitalArtifact = fract(staticLayer * 50.0) > 0.8 ? 1.0 : 0.0;
    combinedNoise = max(combinedNoise, digitalArtifact * 0.7);
    
    // Apply intensity with proper scaling
    combinedNoise *= intensity;
    
    // Ensure we always have some visible noise
    combinedNoise = max(combinedNoise, 0.05 * intensity);
    
    // Clamp to 0-1 range
    combinedNoise = clamp(combinedNoise, 0.0, 1.0);
    
    // Interpolate between background and foreground colors
    half4 noiseColor = mix(backgroundColor, foregroundColor, half(combinedNoise));
    
    return noiseColor;
}
