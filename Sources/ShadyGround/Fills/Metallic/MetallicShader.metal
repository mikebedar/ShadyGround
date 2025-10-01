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
    float scaledStrength = sqrt(edgeStrength * 0.5);
    
    // Clamp sample distance - smaller values reduce edge jitter
    float sampleDist = clamp(scaledStrength, 0.5, 2.0);
    
    // Multi-scale gradient sampling for smoother edges
    // Sample at two different scales and blend
    float scale1 = sampleDist;
    float scale2 = sampleDist * 1.5;
    
    // Sobel at scale 1 (sharper)
    float a00_1 = layer.sample(position + float2(-scale1, -scale1)).a;
    float a01_1 = layer.sample(position + float2(-scale1,  0)).a;
    float a02_1 = layer.sample(position + float2(-scale1,  scale1)).a;
    float a10_1 = layer.sample(position + float2(0, -scale1)).a;
    float a12_1 = layer.sample(position + float2(0,  scale1)).a;
    float a20_1 = layer.sample(position + float2(scale1, -scale1)).a;
    float a21_1 = layer.sample(position + float2(scale1,  0)).a;
    float a22_1 = layer.sample(position + float2(scale1,  scale1)).a;
    
    // Sobel at scale 2 (smoother)
    float a00_2 = layer.sample(position + float2(-scale2, -scale2)).a;
    float a01_2 = layer.sample(position + float2(-scale2,  0)).a;
    float a02_2 = layer.sample(position + float2(-scale2,  scale2)).a;
    float a10_2 = layer.sample(position + float2(0, -scale2)).a;
    float a12_2 = layer.sample(position + float2(0,  scale2)).a;
    float a20_2 = layer.sample(position + float2(scale2, -scale2)).a;
    float a21_2 = layer.sample(position + float2(scale2,  0)).a;
    float a22_2 = layer.sample(position + float2(scale2,  scale2)).a;
    
    // Calculate gradients at both scales
    float dx1 = (-a00_1 + a20_1 - 2.0*a01_1 + 2.0*a21_1 - a02_1 + a22_1) / (4.0 * scale1);
    float dy1 = (-a00_1 - 2.0*a10_1 - a20_1 + a02_1 + 2.0*a12_1 + a22_1) / (4.0 * scale1);
    
    float dx2 = (-a00_2 + a20_2 - 2.0*a01_2 + 2.0*a21_2 - a02_2 + a22_2) / (4.0 * scale2);
    float dy2 = (-a00_2 - 2.0*a10_2 - a20_2 + a02_2 + 2.0*a12_2 + a22_2) / (4.0 * scale2);
    
    // Blend gradients - more weight on smoother scale for stability
    float dx = mix(dx1, dx2, 0.6);
    float dy = mix(dy1, dy2, 0.6);
    
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
    
    // Calculate curvature for adaptive smoothing
    // High curvature = edges/corners that need smoothing
    float curvature = length(float2(dx, dy));
    curvature = smoothstep(0.0, 0.3, curvature);  // Remap to 0-1 range
    
    // Sample the matcap texture with curvature-based blur
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    half3 matcapSharp = matcap.sample(s, uvM).rgb;
    
    // Create blurred version by sampling neighbors
    // Use smaller offset for subtle smoothing
    float blurRadius = 0.015;  // Small blur in UV space
    half3 matcapBlur = (
        matcap.sample(s, uvM + float2(blurRadius, 0.0)).rgb +
        matcap.sample(s, uvM - float2(blurRadius, 0.0)).rgb +
        matcap.sample(s, uvM + float2(0.0, blurRadius)).rgb +
        matcap.sample(s, uvM - float2(0.0, blurRadius)).rgb +
        matcap.sample(s, uvM + float2(blurRadius * 0.7, blurRadius * 0.7)).rgb +
        matcap.sample(s, uvM - float2(blurRadius * 0.7, blurRadius * 0.7)).rgb +
        matcap.sample(s, uvM + float2(blurRadius * 0.7, -blurRadius * 0.7)).rgb +
        matcap.sample(s, uvM - float2(blurRadius * 0.7, -blurRadius * 0.7)).rgb
    ) * 0.125;  // Average of 8 samples
    
    // Mix based on curvature: flat areas = sharp, curved areas = blurred
    half3 metallicColor = mix(matcapSharp, matcapBlur, half(curvature * 0.7));
    
    // Fresnel effect - edges facing away from camera get brighter
    // This creates the classic metallic rim lighting effect
    float viewDot = abs(dot(viewNormal, V));
    float fresnel = pow(1.0 - viewDot, 2.5);  // Power of 2.5 gives nice falloff

    // Brighten edges based on Fresnel
    // Use the brightest part of the matcap (center) for rim highlights
    half3 rimColor = matcap.sample(s, float2(0.5, 0.5)).rgb;
    metallicColor = mix(metallicColor, rimColor * 1.5h, half(fresnel * 0.4));
    
    // Mix with base color
    half3 outRGB = mix(base.rgb, metallicColor, half(mixAmount));
    
    return half4(outRGB, base.a);
}
