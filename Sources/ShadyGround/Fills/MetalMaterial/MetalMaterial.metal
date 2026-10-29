//
//  MetalMaterial.metal
//  ShadyGround
//
//  Metal finishes (brushed, polished, satin, patina) lit by a point light above the
//  surface: a height field per finish gives the normals, Cook-Torrance GGX gives the
//  highlight and a sky/floor gradient stands in for the environment a metal reflects.
//  Ported from the 2025-09 MTKView branch (its PBR terms and material values), drawn
//  as one full-screen triangle through MetalSurfaceRenderer. Every symbol is prefixed
//  `metalMaterial` because all of the package's .metal files share one library.
//

#include <metal_stdlib>
using namespace metal;

// Mirrors MetalMaterialUniforms in MetalMaterialRenderer.swift (five float4s).
struct MetalMaterialUniforms {
    float4 baseColor;   // rgb (sRGB-encoded), a = ambient occlusion
    float4 surface;     // roughness, metallic, finish, feature size (points)
    float4 light;       // xyz direction toward the light (x right, y up, z toward the viewer), w intensity
    float4 frame;       // width (points), height (points), pixels per point, time (seconds)
    float4 extra;       // ambient light, 0, 0, 0
};

struct MetalMaterialVertexOut {
    float4 position [[position]];
};

vertex MetalMaterialVertexOut metalMaterialVertex(uint vid [[vertex_id]]) {
    // One triangle that covers the viewport.
    float2 p = float2(float((vid << 1) & 2), float(vid & 2));
    MetalMaterialVertexOut out;
    out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return out;
}

// MARK: - Noise (integer hash: no precision bands far from the origin)

static inline float metalMaterialHash(int2 c) {
    uint2 q = uint2(c) * uint2(1597334673u, 3812015801u);
    uint n = (q.x ^ q.y) * 1597334673u;
    return float(n >> 8) * (1.0 / 16777216.0);
}

static inline float metalMaterialNoise(float2 p) {
    float2 i = floor(p);
    float2 f = p - i;
    int2 c = int2(i);
    float a = metalMaterialHash(c);
    float b = metalMaterialHash(c + int2(1, 0));
    float d = metalMaterialHash(c + int2(0, 1));
    float e = metalMaterialHash(c + int2(1, 1));
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);   // quintic: no grid creases in the normals
    return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

static inline float metalMaterialFBM(float2 p) {
    // Each octave rotated (about 37 degrees) so the lattice never lines up.
    const float2x2 turn = float2x2(float2(1.6, 1.2), float2(-1.2, 1.6));
    float v = 0.0, amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * metalMaterialNoise(p);
        p = turn * p + float2(17.1, 9.7);
        amp *= 0.5;
    }
    return v;
}

// MARK: - Finishes

// Finish ids, as MetalFinish's raw values.
constant float metalMaterialPolished = 0.0;
constant float metalMaterialBrushed = 1.0;
constant float metalMaterialSatin = 2.0;

/// Height (in points) of the surface at `p` (points), and the patina mask in `patina`.
static inline float metalMaterialHeight(float2 p, float finish, float feature, thread float &patina) {
    patina = 0.0;
    float s = max(feature, 0.5);
    if (finish == metalMaterialPolished) {
        // Nearly flat: a slow, smooth ripple so the reflection is not a perfect mirror.
        float2 q = p / (s * 70.0);
        return 0.5 * (sin(q.x * 1.7 + sin(q.y * 1.3)) + sin(q.y * 2.1 - q.x * 0.7)) + 0.15 * metalMaterialNoise(q * 3.0);
    }
    if (finish == metalMaterialBrushed) {
        // Streaks along x: long in x, fine in y.
        float2 q = float2(p.x / (s * 60.0), p.y / s);
        return 0.25 * metalMaterialFBM(q) + 0.1 * metalMaterialNoise(float2(p.x / (s * 200.0), p.y / (s * 0.5)));
    }
    if (finish == metalMaterialSatin) {
        // Bead-blasted: fine isotropic grain.
        return 0.25 * metalMaterialFBM(p / s);
    }
    // Patina: blotches of verdigris over a gently pitted surface.
    float blot = metalMaterialFBM(p / (s * 18.0) + 3.1);
    patina = smoothstep(0.42, 0.62, blot);
    return 0.4 * metalMaterialFBM(p / (s * 2.0)) + 0.8 * patina;
}

// MARK: - Lighting (Cook-Torrance GGX, as in the MTKView branch)

static inline float3 metalMaterialFresnel(float cosTheta, float3 f0) {
    return f0 + (1.0 - f0) * pow(1.0 - cosTheta, 5.0);
}

static inline float metalMaterialGGX(float nh, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float d = nh * nh * (a2 - 1.0) + 1.0;
    return a2 / (M_PI_F * d * d);
}

static inline float metalMaterialSmith(float nv, float nl, float roughness) {
    float r = roughness + 1.0;
    float k = r * r / 8.0;
    return (nv / (nv * (1.0 - k) + k)) * (nl / (nl * (1.0 - k) + k));
}

/// What a metal reflects: a bright studio ceiling above, a dim floor below, the
/// transition softer with roughness. The viewer sits above the surface, so the
/// reflected ray tilts up toward the top of the view and down toward the bottom.
static inline float3 metalMaterialEnvironment(float3 r, float roughness) {
    float t = smoothstep(0.0, 1.0, 0.5 + r.y * mix(2.6, 0.9, roughness));
    float3 floorColor = float3(0.04, 0.04, 0.05);
    float3 skyColor = float3(0.80, 0.83, 0.88);
    return mix(floorColor, skyColor, t) * mix(1.0, 0.7, roughness);
}

fragment float4 metalMaterialFragment(MetalMaterialVertexOut in [[stage_in]],
                                      constant MetalMaterialUniforms &u [[buffer(0)]]) {
    float scale = max(u.frame.z, 0.5);
    float2 size = max(u.frame.xy, float2(1.0));
    // Points, y up, origin at the centre.
    float2 p = in.position.xy / scale;
    float2 c = float2(p.x - size.x * 0.5, size.y * 0.5 - p.y);

    float roughness = clamp(u.surface.x, 0.04, 1.0);
    float metallic = clamp(u.surface.y, 0.0, 1.0);
    float finish = u.surface.z;
    float feature = u.surface.w;

    // Normal from the height field by central differences (half a pixel apart).
    float e = 0.5 / scale;
    float patina, unused;
    float h = metalMaterialHeight(c, finish, feature, patina);
    float hx = metalMaterialHeight(c + float2(e, 0.0), finish, feature, unused);
    float hy = metalMaterialHeight(c + float2(0.0, e), finish, feature, unused);
    float3 n = normalize(float3(-(hx - h) / e, -(hy - h) / e, 1.0));

    // Point light above the surface in the given direction; viewer above the centre.
    float extent = max(size.x, size.y);
    float3 dir = normalize(u.light.xyz);
    float t = u.frame.w;
    if (t > 0.0) {
        // Animated: the light sways, so the highlight sweeps across the surface.
        float a = sin(t * 0.6) * 0.5;
        float ca = cos(a), sa = sin(a);
        dir = normalize(float3(dir.x * ca - dir.y * sa, dir.x * sa + dir.y * ca, dir.z));
    }
    float3 surfacePoint = float3(c, h);
    float3 lightPos = dir * extent * 1.2;
    float3 eye = float3(0.0, 0.0, extent * 2.0);
    float3 l = normalize(lightPos - surfacePoint);
    float3 v = normalize(eye - surfacePoint);
    float3 hv = normalize(l + v);

    // Colours arrive sRGB-encoded; light in linear.
    float3 base = pow(clamp(u.baseColor.rgb, 0.0, 1.0), 2.2);
    if (patina > 0.0) {
        float3 verdigris = pow(float3(0.31, 0.62, 0.50), 2.2);
        base = mix(base, verdigris, patina);
        metallic = mix(metallic, 0.0, patina);      // oxide is not a metal
        roughness = mix(roughness, 0.85, patina);
    }

    float nl = max(dot(n, l), 0.0);
    float nv = max(dot(n, v), 1e-3);
    float nh = max(dot(n, hv), 0.0);
    float3 f0 = mix(float3(0.04), base, metallic);
    float3 f = metalMaterialFresnel(max(dot(hv, v), 0.0), f0);
    float3 specular = metalMaterialGGX(nh, roughness) * metalMaterialSmith(nv, nl, roughness) * f / max(4.0 * nv * nl, 1e-3);
    float3 kd = (1.0 - f) * (1.0 - metallic);
    float3 direct = (kd * base / M_PI_F + specular) * nl * u.light.w * 3.0;

    float3 r = reflect(-v, n);
    float3 envF = metalMaterialFresnel(nv, f0);
    float3 reflected = metalMaterialEnvironment(r, roughness) * envF;
    float3 ambient = base * u.extra.x * (1.0 - metallic * 0.5);

    float3 color = (direct + reflected + ambient) * u.baseColor.a;
    color = 1.0 - exp(-color * 1.6);                // exposure tone map: highlights roll off, colour survives
    color = pow(color, 1.0 / 2.2);
    return float4(color, 1.0);
}
