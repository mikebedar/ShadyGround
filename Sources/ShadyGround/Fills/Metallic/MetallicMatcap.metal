//
//  MetallicMatcap.metal
//  Metallic Matcap Shader Effect
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Matcap Sampling Helpers

/// Sample matcap texture with bilinear filtering
half4 sampleMatcap(texture2d<half> matcap, float2 uv) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    return matcap.sample(s, uv);
}

/// High-quality multi-tap blur for smooth normal derivation
/// Uses 5x5 Gaussian kernel to prevent noise in fine details
float sampleAlphaSmooth(SwiftUI::Layer layer, float2 position, float2 texelSize, float2 resolution) {
    float sum = 0.0;

    // 5x5 Gaussian kernel weights (sigma ~1.4) - unrolled for Metal compatibility
    // Row -2
    sum += float(layer.sample(position + float2(-2, -2) * texelSize * resolution).a) * 0.023528;
    sum += float(layer.sample(position + float2(-1, -2) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2( 0, -2) * texelSize * resolution).a) * 0.038393;
    sum += float(layer.sample(position + float2( 1, -2) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2( 2, -2) * texelSize * resolution).a) * 0.023528;

    // Row -1
    sum += float(layer.sample(position + float2(-2, -1) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2(-1, -1) * texelSize * resolution).a) * 0.049045;
    sum += float(layer.sample(position + float2( 0, -1) * texelSize * resolution).a) * 0.055432;
    sum += float(layer.sample(position + float2( 1, -1) * texelSize * resolution).a) * 0.049045;
    sum += float(layer.sample(position + float2( 2, -1) * texelSize * resolution).a) * 0.033969;

    // Row 0 (center)
    sum += float(layer.sample(position + float2(-2,  0) * texelSize * resolution).a) * 0.038393;
    sum += float(layer.sample(position + float2(-1,  0) * texelSize * resolution).a) * 0.055432;
    sum += float(layer.sample(position + float2( 0,  0) * texelSize * resolution).a) * 0.062651;
    sum += float(layer.sample(position + float2( 1,  0) * texelSize * resolution).a) * 0.055432;
    sum += float(layer.sample(position + float2( 2,  0) * texelSize * resolution).a) * 0.038393;

    // Row 1
    sum += float(layer.sample(position + float2(-2,  1) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2(-1,  1) * texelSize * resolution).a) * 0.049045;
    sum += float(layer.sample(position + float2( 0,  1) * texelSize * resolution).a) * 0.055432;
    sum += float(layer.sample(position + float2( 1,  1) * texelSize * resolution).a) * 0.049045;
    sum += float(layer.sample(position + float2( 2,  1) * texelSize * resolution).a) * 0.033969;

    // Row 2
    sum += float(layer.sample(position + float2(-2,  2) * texelSize * resolution).a) * 0.023528;
    sum += float(layer.sample(position + float2(-1,  2) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2( 0,  2) * texelSize * resolution).a) * 0.038393;
    sum += float(layer.sample(position + float2( 1,  2) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2( 2,  2) * texelSize * resolution).a) * 0.023528;

    return sum;
}

// MARK: - Normal Computation

/// Compute screen-space normal from alpha channel using Sobel operator
/// With additional bilateral filtering to preserve edges while reducing noise
/// Enhanced with distance field approximation to prevent corner artifacts
float3 computeNormal(SwiftUI::Layer layer,
                     float2 position,
                     float2 resolution,
                     float edgeStrength,
                     float edgeHardness) {
    float2 texelSize = 1.0 / resolution;

    // Use larger sampling radius for smoother normals
    float radius = 1.5;

    // Sample center alpha for distance field approximation
    float c = sampleAlphaSmooth(layer, position, texelSize, resolution);

    // Sobel kernel sampling with enhanced smoothing
    float tl = sampleAlphaSmooth(layer, position + float2(-1, -1) * radius, texelSize, resolution);
    float t  = sampleAlphaSmooth(layer, position + float2( 0, -1) * radius, texelSize, resolution);
    float tr = sampleAlphaSmooth(layer, position + float2( 1, -1) * radius, texelSize, resolution);
    float l  = sampleAlphaSmooth(layer, position + float2(-1,  0) * radius, texelSize, resolution);
    float r  = sampleAlphaSmooth(layer, position + float2( 1,  0) * radius, texelSize, resolution);
    float bl = sampleAlphaSmooth(layer, position + float2(-1,  1) * radius, texelSize, resolution);
    float b  = sampleAlphaSmooth(layer, position + float2( 0,  1) * radius, texelSize, resolution);
    float br = sampleAlphaSmooth(layer, position + float2( 1,  1) * radius, texelSize, resolution);

    // Enhanced Sobel operator with 3x3 kernel
    float dx = (tr + 2.0*r + br) - (tl + 2.0*l + bl);
    float dy = (bl + 2.0*b + br) - (tl + 2.0*t + tr);

    // Compute gradient magnitude for corner detection
    float gradientMagnitude = length(float2(dx, dy));

    // Distance field approximation: how far from edge?
    // Center value of 0.5 = edge, 1.0 = interior, 0.0 = exterior
    float distanceFromEdge = abs(c - 0.5) * 2.0;

    // Edge hardness control: adjusts the transition from flat to beveled
    // Higher values = sharper, more chiseled edges
    // Lower values = softer, more rounded edges
    // Apply power function to distance for non-linear falloff
    float hardnessPower = mix(1.5, 4.0, edgeHardness);
    float hardnessModulation = pow(1.0 - distanceFromEdge, hardnessPower);

    // Detect corners by looking at gradient magnitude
    // High gradient magnitude = sharp corner or edge
    float cornerFactor = smoothstep(0.5, 2.0, gradientMagnitude);

    // Apply bilateral-style filtering: reduce gradient strength in low-alpha regions
    // This prevents noise amplification on thin/detailed geometry
    float alphaMask = smoothstep(0.1, 0.3, c);

    // Modulate edge strength based on distance from edge with hardness control
    // Hardness affects how quickly the bevel transitions
    float transitionStart = mix(0.3, 0.1, edgeHardness);
    float transitionEnd = mix(0.8, 0.5, edgeHardness);
    float distanceModulation = 1.0 - smoothstep(transitionStart, transitionEnd, distanceFromEdge);

    // Apply hardness to the modulation curve
    distanceModulation = pow(distanceModulation, 1.0 / hardnessPower);

    // In corners, reduce the gradient even more to prevent overlapping
    // Use the corner factor to detect when gradients are perpendicular
    float cornerModulation = mix(1.0, 0.4, cornerFactor * distanceFromEdge);

    // Apply all modulations including hardness
    dx *= alphaMask * distanceModulation * cornerModulation * hardnessModulation;
    dy *= alphaMask * distanceModulation * cornerModulation * hardnessModulation;

    // Scale by edge strength with non-linear curve for better control
    float effectiveStrength = edgeStrength * 0.25;

    // Construct normal with clamped gradients to prevent extreme angles
    float maxGradient = 2.0;
    dx = clamp(dx * effectiveStrength, -maxGradient, maxGradient);
    dy = clamp(dy * effectiveStrength, -maxGradient, maxGradient);

    float3 normal = normalize(float3(-dx, -dy, 1.0));

    // Additional smoothing: lerp toward neutral normal in low-alpha areas
    // Reduced lerping for harder edges
    float neutralBlend = mix(1.0, 0.5, edgeHardness);
    float3 neutralNormal = float3(0.0, 0.0, 1.0);
    normal = mix(neutralNormal, normal, alphaMask * neutralBlend);

    return normal;
}

// MARK: - Lighting Calculations

/// Fresnel effect (Schlick approximation)
float fresnel(float3 normal, float3 view, float power) {
    float NdotV = max(dot(normal, view), 0.0);
    return pow(1.0 - NdotV, power);
}

/// Phong specular highlight
float specularPhong(float3 normal, float3 view, float3 lightDir, float shininess) {
    float3 reflection = reflect(-lightDir, normal);
    float RdotV = max(dot(reflection, view), 0.0);
    return pow(RdotV, shininess);
}

// MARK: - Main Shader

[[ stitchable ]] half4 metallicMatcap(
                                      float2 position,
                                      SwiftUI::Layer layer,
                                      texture2d<half> matcap,
                                      float2 resolution,
                                      float3 viewDir,
                                      float edgeStrength,
                                      float edgeHardness,
                                      float specularStrength,
                                      float shininess,
                                      float tiltMix,
                                      float fresnelPower
                                      ) {
    // Sample base layer for alpha mask
    half4 baseColor = layer.sample(position);
    float baseAlpha = float(baseColor.a);

    // Early exit for fully transparent pixels
    if (baseAlpha < 0.001) {
        return half4(0.0);
    }

    // Compute screen-space normal from alpha channel with hardness control
    float3 normal = computeNormal(layer, position, resolution, edgeStrength, edgeHardness);

    // Interpolate view direction based on tilt mix
    float3 neutralView = float3(0.0, 0.0, 1.0);
    float3 effectiveView = normalize(mix(neutralView, viewDir, tiltMix));

    // Reflect view vector across normal for matcap lookup
    // Ensure both vectors are normalized for consistent results
    float3 reflected = reflect(-normalize(effectiveView), normalize(normal));
    reflected = normalize(reflected);

    // Convert reflection vector to matcap UV coordinates
    // Standard sphere mapping: project XY onto UV [0,1]
    // The Z component encodes depth which affects how X,Y map to the sphere
    float2 matcapUV = reflected.xy * 0.5 + 0.5;

    // Sample matcap texture
    // The texture sampler already provides bilinear filtering
    half4 matcapSample = sampleMatcap(matcap, matcapUV);

    // Extract color and specular from matcap
    half3 matcapColor = matcapSample.rgb;
    float matcapSpec = float(matcapSample.a);
    
    // Add subtle ambient lighting to prevent overly dark areas
    // This ensures the effect never goes completely black at extreme angles
    float ambientStrength = 0.15;  // 15% ambient light
    half3 ambient = matcapColor * half(ambientStrength);
    matcapColor = mix(matcapColor, max(matcapColor, ambient), 0.3h);

    // Apply subtle Fresnel rim lighting
    float fresnelFactor = fresnel(normal, effectiveView, fresnelPower);
    matcapColor += half3(fresnelFactor * 0.15); // Subtle brightening at edges

    // Compute specular highlight
    // Use light direction from slightly offset view for more dynamic highlights
    float3 lightDir = normalize(effectiveView + float3(0.2, 0.3, 0.5));
    float specular = specularPhong(normal, effectiveView, lightDir, shininess);

    // Modulate specular by matcap alpha and strength parameter
    specular *= matcapSpec * specularStrength;

    // Combine matcap color with specular highlight
    half3 finalColor = matcapColor + half3(specular);

    // Preserve base alpha for masking
    return half4(finalColor, half(baseAlpha));
}


/* leave this alone

//
//  MetallicMatcap.metal
//  Metallic Matcap Shader Effect
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Matcap Sampling Helpers

/// Sample matcap texture with bilinear filtering
half4 sampleMatcap(texture2d<half> matcap, float2 uv) {
    constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
    return matcap.sample(s, uv);
}

/// High-quality multi-tap blur for smooth normal derivation
/// Uses 5x5 Gaussian kernel to prevent noise in fine details
float sampleAlphaSmooth(SwiftUI::Layer layer, float2 position, float2 texelSize, float2 resolution) {
    float sum = 0.0;

    // 5x5 Gaussian kernel weights (sigma ~1.4) - unrolled for Metal compatibility
    // Row -2
    sum += float(layer.sample(position + float2(-2, -2) * texelSize * resolution).a) * 0.023528;
    sum += float(layer.sample(position + float2(-1, -2) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2( 0, -2) * texelSize * resolution).a) * 0.038393;
    sum += float(layer.sample(position + float2( 1, -2) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2( 2, -2) * texelSize * resolution).a) * 0.023528;

    // Row -1
    sum += float(layer.sample(position + float2(-2, -1) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2(-1, -1) * texelSize * resolution).a) * 0.049045;
    sum += float(layer.sample(position + float2( 0, -1) * texelSize * resolution).a) * 0.055432;
    sum += float(layer.sample(position + float2( 1, -1) * texelSize * resolution).a) * 0.049045;
    sum += float(layer.sample(position + float2( 2, -1) * texelSize * resolution).a) * 0.033969;

    // Row 0 (center)
    sum += float(layer.sample(position + float2(-2,  0) * texelSize * resolution).a) * 0.038393;
    sum += float(layer.sample(position + float2(-1,  0) * texelSize * resolution).a) * 0.055432;
    sum += float(layer.sample(position + float2( 0,  0) * texelSize * resolution).a) * 0.062651;
    sum += float(layer.sample(position + float2( 1,  0) * texelSize * resolution).a) * 0.055432;
    sum += float(layer.sample(position + float2( 2,  0) * texelSize * resolution).a) * 0.038393;

    // Row 1
    sum += float(layer.sample(position + float2(-2,  1) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2(-1,  1) * texelSize * resolution).a) * 0.049045;
    sum += float(layer.sample(position + float2( 0,  1) * texelSize * resolution).a) * 0.055432;
    sum += float(layer.sample(position + float2( 1,  1) * texelSize * resolution).a) * 0.049045;
    sum += float(layer.sample(position + float2( 2,  1) * texelSize * resolution).a) * 0.033969;

    // Row 2
    sum += float(layer.sample(position + float2(-2,  2) * texelSize * resolution).a) * 0.023528;
    sum += float(layer.sample(position + float2(-1,  2) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2( 0,  2) * texelSize * resolution).a) * 0.038393;
    sum += float(layer.sample(position + float2( 1,  2) * texelSize * resolution).a) * 0.033969;
    sum += float(layer.sample(position + float2( 2,  2) * texelSize * resolution).a) * 0.023528;

    return sum;
}

// MARK: - Normal Computation

/// Compute screen-space normal from alpha channel using Sobel operator
/// With additional bilateral filtering to preserve edges while reducing noise
/// Enhanced with distance field approximation to prevent corner artifacts
float3 computeNormal(SwiftUI::Layer layer,
                     float2 position,
                     float2 resolution,
                     float edgeStrength,
                     float edgeHardness) {
    float2 texelSize = 1.0 / resolution;

    // Use larger sampling radius for smoother normals
    float radius = 1.5;

    // Sample center alpha for distance field approximation
    float c = sampleAlphaSmooth(layer, position, texelSize, resolution);

    // Sobel kernel sampling with enhanced smoothing
    float tl = sampleAlphaSmooth(layer, position + float2(-1, -1) * radius, texelSize, resolution);
    float t  = sampleAlphaSmooth(layer, position + float2( 0, -1) * radius, texelSize, resolution);
    float tr = sampleAlphaSmooth(layer, position + float2( 1, -1) * radius, texelSize, resolution);
    float l  = sampleAlphaSmooth(layer, position + float2(-1,  0) * radius, texelSize, resolution);
    float r  = sampleAlphaSmooth(layer, position + float2( 1,  0) * radius, texelSize, resolution);
    float bl = sampleAlphaSmooth(layer, position + float2(-1,  1) * radius, texelSize, resolution);
    float b  = sampleAlphaSmooth(layer, position + float2( 0,  1) * radius, texelSize, resolution);
    float br = sampleAlphaSmooth(layer, position + float2( 1,  1) * radius, texelSize, resolution);

    // Enhanced Sobel operator with 3x3 kernel
    float dx = (tr + 2.0*r + br) - (tl + 2.0*l + bl);
    float dy = (bl + 2.0*b + br) - (tl + 2.0*t + tr);

    // Compute gradient magnitude for corner detection
    float gradientMagnitude = length(float2(dx, dy));

    // Distance field approximation: how far from edge?
    // Center value of 0.5 = edge, 1.0 = interior, 0.0 = exterior
    float distanceFromEdge = abs(c - 0.5) * 2.0;

    // Edge hardness control: adjusts the transition from flat to beveled
    // Higher values = sharper, more chiseled edges
    // Lower values = softer, more rounded edges
    // Apply power function to distance for non-linear falloff
    float hardnessPower = mix(1.5, 4.0, edgeHardness);
    float hardnessModulation = pow(1.0 - distanceFromEdge, hardnessPower);

    // Detect corners by looking at gradient magnitude
    // High gradient magnitude = sharp corner or edge
    float cornerFactor = smoothstep(0.5, 2.0, gradientMagnitude);

    // Apply bilateral-style filtering: reduce gradient strength in low-alpha regions
    // This prevents noise amplification on thin/detailed geometry
    float alphaMask = smoothstep(0.1, 0.3, c);

    // Modulate edge strength based on distance from edge with hardness control
    // Hardness affects how quickly the bevel transitions
    float transitionStart = mix(0.3, 0.1, edgeHardness);
    float transitionEnd = mix(0.8, 0.5, edgeHardness);
    float distanceModulation = 1.0 - smoothstep(transitionStart, transitionEnd, distanceFromEdge);

    // Apply hardness to the modulation curve
    distanceModulation = pow(distanceModulation, 1.0 / hardnessPower);

    // In corners, reduce the gradient even more to prevent overlapping
    // Use the corner factor to detect when gradients are perpendicular
    float cornerModulation = mix(1.0, 0.4, cornerFactor * distanceFromEdge);

    // Apply all modulations including hardness
    dx *= alphaMask * distanceModulation * cornerModulation * hardnessModulation;
    dy *= alphaMask * distanceModulation * cornerModulation * hardnessModulation;

    // Scale by edge strength with non-linear curve for better control
    float effectiveStrength = edgeStrength * 0.25;

    // Construct normal with clamped gradients to prevent extreme angles
    float maxGradient = 2.0;
    dx = clamp(dx * effectiveStrength, -maxGradient, maxGradient);
    dy = clamp(dy * effectiveStrength, -maxGradient, maxGradient);

    float3 normal = normalize(float3(-dx, -dy, 1.0));

    // Additional smoothing: lerp toward neutral normal in low-alpha areas
    // Reduced lerping for harder edges
    float neutralBlend = mix(1.0, 0.5, edgeHardness);
    float3 neutralNormal = float3(0.0, 0.0, 1.0);
    normal = mix(neutralNormal, normal, alphaMask * neutralBlend);

    return normal;
}

// MARK: - Lighting Calculations

/// Fresnel effect (Schlick approximation)
float fresnel(float3 normal, float3 view, float power) {
    float NdotV = max(dot(normal, view), 0.0);
    return pow(1.0 - NdotV, power);
}

/// Phong specular highlight
float specularPhong(float3 normal, float3 view, float3 lightDir, float shininess) {
    float3 reflection = reflect(-lightDir, normal);
    float RdotV = max(dot(reflection, view), 0.0);
    return pow(RdotV, shininess);
}

// MARK: - Main Shader

[[ stitchable ]] half4 metallicMatcap(
                                      float2 position,
                                      SwiftUI::Layer layer,
                                      texture2d<half> matcap,
                                      float2 resolution,
                                      float3 viewDir,
                                      float edgeStrength,
                                      float edgeHardness,
                                      float specularStrength,
                                      float shininess,
                                      float tiltMix,
                                      float fresnelPower
                                      ) {
    // Sample base layer for alpha mask
    half4 baseColor = layer.sample(position);
    float baseAlpha = float(baseColor.a);

    // Early exit for fully transparent pixels
    if (baseAlpha < 0.01) {
        return half4(0.0);
    }

    // Compute screen-space normal from alpha channel with hardness control
    float3 normal = computeNormal(layer, position, resolution, edgeStrength, edgeHardness);

    // Interpolate view direction based on tilt mix
    float3 neutralView = float3(0.0, 0.0, 1.0);
    float3 effectiveView = normalize(mix(neutralView, viewDir, tiltMix));

    // Reflect view vector across normal for matcap lookup
    // Ensure both vectors are normalized for consistent results
    float3 reflected = reflect(-normalize(effectiveView), normalize(normal));
    reflected = normalize(reflected);

    // Convert reflection vector to matcap UV coordinates
    // Standard sphere mapping: project XY onto UV [0,1]
    // The Z component encodes depth which affects how X,Y map to the sphere
    float2 matcapUV = reflected.xy * 0.5 + 0.5;

    // Sample matcap texture
    // The texture sampler already provides bilinear filtering
    half4 matcapSample = sampleMatcap(matcap, matcapUV);

    // Extract color and specular from matcap
    half3 matcapColor = matcapSample.rgb;
    float matcapSpec = float(matcapSample.a);
    
    // Add subtle ambient lighting to prevent overly dark areas
    // This ensures the effect never goes completely black at extreme angles
    float ambientStrength = 0.15;  // 15% ambient light
    half3 ambient = matcapColor * half(ambientStrength);
    matcapColor = mix(matcapColor, max(matcapColor, ambient), 0.3h);

    // Apply subtle Fresnel rim lighting
    float fresnelFactor = fresnel(normal, effectiveView, fresnelPower);
    matcapColor += half3(fresnelFactor * 0.15); // Subtle brightening at edges

    // Compute specular highlight
    // Use light direction from slightly offset view for more dynamic highlights
    float3 lightDir = normalize(effectiveView + float3(0.2, 0.3, 0.5));
    float specular = specularPhong(normal, effectiveView, lightDir, shininess);

    // Modulate specular by matcap alpha and strength parameter
    specular *= matcapSpec * specularStrength;

    // Combine matcap color with specular highlight
    half3 finalColor = matcapColor + half3(specular);

    // Preserve base alpha for masking
    return half4(finalColor, half(baseAlpha));
}


 */
