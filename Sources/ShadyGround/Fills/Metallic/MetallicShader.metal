//
//  MetallicShader.metal
//  ShadyGround
//
//  Created by Michael Bedar on 9/30/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]] half4 metallic(
    float2 position,
    SwiftUI::Layer layer,
    texture2d<half> matcap,
    float2 resolution,
    float3 viewDir,
    float mixAmount,
    float edgeStrength
) {
    half4 base = layer.sample(position);
    
    // Early exit if fully transparent
    if (base.a <= 0.001h) return half4(0);
    
    // Non-linear scaling for edgeStrength - use square root for smoother control
    // This gives finer control at low values, prevents explosion at high values
    float scaledStrength = sqrt(edgeStrength * 0.5);
    
    // Clamp sample distance to prevent sampling too far away
    float sampleDist = clamp(scaledStrength, 0.5, 3.0);
    
    // Sobel filter for smoother, more accurate gradients
    // Sample 3x3 grid around current pixel
    float a00 = layer.sample(position + float2(-sampleDist, -sampleDist)).a;
    float a01 = layer.sample(position + float2(-sampleDist,  0)).a;
    float a02 = layer.sample(position + float2(-sampleDist,  sampleDist)).a;
    
    float a10 = layer.sample(position + float2(0, -sampleDist)).a;
    // a11 is the center (base.a)
    float a12 = layer.sample(position + float2(0,  sampleDist)).a;
    
    float a20 = layer.sample(position + float2(sampleDist, -sampleDist)).a;
    float a21 = layer.sample(position + float2(sampleDist,  0)).a;
    float a22 = layer.sample(position + float2(sampleDist,  sampleDist)).a;
    
    // Sobel operator weights for X gradient
    // [-1  0  1]
    // [-2  0  2]
    // [-1  0  1]
    float dx = (-a00 + a20 - 2.0*a01 + 2.0*a21 - a02 + a22) / (4.0 * sampleDist);
    
    // Sobel operator weights for Y gradient
    // [-1 -2 -1]
    // [ 0  0  0]
    // [ 1  2  1]
    float dy = (-a00 - 2.0*a10 - a20 + a02 + 2.0*a12 + a22) / (4.0 * sampleDist);
    
    // Create surface normal from alpha gradients
    // Use the original edgeStrength for final normal scaling
    float normalStrength = edgeStrength * 2.0;
    float3 N = normalize(float3(-dx * normalStrength, -dy * normalStrength, 1.0));
    
    // Transform normal to view space for matcap lookup
    // This is more stable than using reflection - prevents flashing
    float3 V = normalize(viewDir);
    
    // Project normal onto view plane (removes depth component)
    float3 viewNormal = N - V * dot(N, V);
    viewNormal = normalize(viewNormal);
    
    // Map view-space normal to matcap UV coordinates
    // Matcaps are designed to be sampled this way (hemisphere projection)
    float2 uvM = viewNormal.xy * 0.5 + 0.5;
    
    // Sample the matcap texture
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    half3 metallicColor = matcap.sample(s, uvM).rgb;
    
    // Mix with base color
    half3 outRGB = mix(base.rgb, metallicColor, half(mixAmount));
    
    return half4(outRGB, base.a);
}

// Debug shader to visualize normals as colors
[[ stitchable ]] half4 metallicDebug(
    float2 position,
    SwiftUI::Layer layer,
    float2 resolution,
    float edgeStrength
) {
    half4 base = layer.sample(position);
    if (base.a <= 0.001h) return half4(0);
    
    // Use same non-linear scaling as main shader
    float scaledStrength = sqrt(edgeStrength * 0.5);
    float sampleDist = clamp(scaledStrength, 0.5, 3.0);
    
    // Sobel filter
    float a00 = layer.sample(position + float2(-sampleDist, -sampleDist)).a;
    float a01 = layer.sample(position + float2(-sampleDist,  0)).a;
    float a02 = layer.sample(position + float2(-sampleDist,  sampleDist)).a;
    
    float a10 = layer.sample(position + float2(0, -sampleDist)).a;
    float a12 = layer.sample(position + float2(0,  sampleDist)).a;
    
    float a20 = layer.sample(position + float2(sampleDist, -sampleDist)).a;
    float a21 = layer.sample(position + float2(sampleDist,  0)).a;
    float a22 = layer.sample(position + float2(sampleDist,  sampleDist)).a;
    
    float dx = (-a00 + a20 - 2.0*a01 + 2.0*a21 - a02 + a22) / (4.0 * sampleDist);
    float dy = (-a00 - 2.0*a10 - a20 + a02 + 2.0*a12 + a22) / (4.0 * sampleDist);
    
    float normalStrength = edgeStrength * 2.0;
    float3 N = normalize(float3(-dx * normalStrength, -dy * normalStrength, 1.0));
    
    // Visualize normal as RGB (remap [-1,1] to [0,1])
    half3 normalColor = half3(N.x * 0.5 + 0.5, N.y * 0.5 + 0.5, N.z);
    
    return half4(normalColor, base.a);
}
