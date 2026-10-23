//
//  GrassInstanced.metal
//  ShadyGround
//
//  Experimental real-geometry grass: every blade is an instanced triangle strip
//  bent along a quadratic Bezier. Blades are placed procedurally from the instance
//  id on camera-relative LOD rings (see GrassInstancedRenderer.swift), read the
//  same control map as GrassShader.metal at their root, and are shaded in the
//  fragment stage. A full-screen ray-cast ground pass underneath shows soil where
//  coverage is low and stands in for the canopy beyond the blade range.
//
//  Units: centimetres in ground space (x right, y up the map, z up), like
//  GrassShader.metal. Colours are sRGB-encoded and straight (not premultiplied),
//  and shading happens in encoded space, matching the fragment shader.
//
//  Keep `Uniforms` and `Ring` in sync with GIUniforms / GIRing in Swift.
//

#include <metal_stdlib>
#include "../GrassCore.h"
using namespace metal;

namespace grassinst {

struct Uniforms {
    float4x4 viewProj;
    float4 eye;        // xyz eye (cm), w time (s)
    float4 camRight;   // xyz camera right, w tan(half horizontal fov)
    float4 camUp;      // xyz camera up, w tan(half vertical fov)
    float4 camFwd;     // xyz camera forward, w unused
    float4 lattice;    // cos(heading), sin(heading), cells per octave, far distance (cm)
    float4 map;        // ground-origin map point x, y (pt), cm per point, unused
    float4 mapSize;    // map w, h (pt), 1/w, 1/h
    float4 blade;      // width cm, height cm, leanScale, heightScale
    float4 blade2;     // width growth (fraction of spacing), min pixel width, cm per px per cm depth, ring count
    float4 wind;       // direction x, y (ground), strength, speed cm/s
    float4 wind2;      // gust scale cm, sway, blade gain, sparsity fade (natural spacings)
    float4 shade;      // stripeContrast, sheen, sheenPower, grazeBrighten
    float4 light;      // xyz toward light (ground axes), variation
    float4 atmos;      // fog distance cm, desaturation distance cm, horizon glow px, patch scale cm
    float4 grade;      // exposure, saturation, vignette, unused
    float4 viewport;   // w px, h px, 1/w, 1/h
    float4 clip;       // P00, P11, natural blade spacing (cm), unused
    float4 baseColor;
    float4 tipColor;
    float4 dryColor;
    float4 soilColor;
    float4 sheenColor;
    float4 fogColor;
};

struct Ring {
    int4 cells;     // first lattice cell u, v; cell count u, v
    float4 band;    // enumerated forward lo, hi; nominal near boundary F_k; cell size (cm)
    uint4 start;    // x: first instance id of the ring; y: hash key (cell-size index)
    float4 fade;    // crossfade half-width at the near, far boundary; nominal far boundary; unused
};

// MARK: Noise

inline uint3 pcg3d(uint3 v) {
    v = v * 1664525u + 1013904223u;
    v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
    v ^= v >> 16u;
    v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
    return v;
}

inline float3 unit3(uint3 h) { return float3(h) * (1.0 / 4294967296.0); }

inline float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

inline float vnoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

inline float fbm3(float2 p) {
    return (0.5 * vnoise(p) + 0.25 * vnoise(p * 2.03 + 17.1) + 0.125 * vnoise(p * 4.11 + 31.7)) / 0.875;
}

inline float2 rotate(float2 p, float a) {
    float c = cos(a), s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

inline float bandLimit(float period, float footprint) {
    return saturate(period / max(footprint, 1e-4) - 1.0);
}

inline float luma(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

// MARK: Control map (same decoding as GrassShader.metal)

constexpr sampler controlSampler(filter::linear, address::clamp_to_edge);

struct Control {
    float2 lean;     // ground-space lean
    float height;    // 0...1
    float coverage;  // 0...1
};

inline Control sampleControl(texture2d<float> map, float2 g, constant Uniforms &U) {
    float2 mp = U.map.xy + float2(g.x, -g.y) / U.map.z;
    float2 uv = mp * U.mapSize.zw;
    float4 c = map.sample(controlSampler, uv, level(0));
    Control ctl;
    ctl.coverage = saturate(c.a);
    float3 rgb = ctl.coverage > 0.001 ? saturate(c.rgb / ctl.coverage) : float3(0.5, 0.5, 0.3);
    float2 leanMap = (rgb.xy - 0.5) * 2.0 * U.blade.z;
    ctl.lean = float2(leanMap.x, -leanMap.y);
    ctl.height = saturate(rgb.z * U.blade.w);
    return ctl;
}

inline float2 windLean(float2 root, float phase, constant Uniforms &U) {
    float strength = U.wind.z;
    if (strength <= 0.0) { return float2(0.0); }
    float2 wdir = U.wind.xy;
    float time = U.eye.w;
    float2 wp = (root - wdir * (time * U.wind.w)) / max(U.wind2.x, 1.0);
    float gust = fbm3(wp);
    float sway = sin(time * 3.1 + phase) * U.wind2.y;
    return strength * wdir * (0.15 + 1.1 * gust + sway * (0.4 + gust));
}

/// Fog, desaturation, exposure, shoulder and vignette, as in GrassShader.metal.
inline float4 finish(float3 rgb, float alpha, float dist, float2 pixel, constant Uniforms &U) {
    float3 fog = U.fogColor.rgb;
    float fogA = U.fogColor.a;
    if (U.atmos.x > 0.0 && fogA > 0.0) {
        float f = (1.0 - exp(-dist / U.atmos.x)) * fogA;
        rgb = mix(rgb, fog, f);
    }
    float satScale = U.atmos.y > 0.0 ? exp(-dist / U.atmos.y) : 1.0;
    float3 c = rgb * U.grade.x;
    float l = luma(c);
    c = mix(float3(l), c, U.grade.y * satScale);
    c = select(c, 0.8 + 0.2 * (1.0 - exp(-(c - 0.8) / 0.2)), c > 0.8);
    if (U.grade.z > 0.0) {
        float2 uv = pixel * U.viewport.zw * 2.0 - 1.0;
        c *= 1.0 - U.grade.z * smoothstep(0.5, 1.5, length(uv));
    }
    return float4(clamp(c, 0.0, 1.0) * alpha, alpha);
}

} // namespace grassinst

using namespace grassinst;

// MARK: - Blades

struct BladeOut {
    float4 position [[position]];
    float3 world;
    float3 normal;
    float3 tangent;
    float t;
    float3 farMean [[flat]];   // far-field turf colour at the root (before fog/grading)
    float3 tipTint [[flat]];
    float jitter [[flat]];     // per-blade brightness, mean 1
    float lod [[flat]];        // 0 near, 1 when the blade is about a pixel wide
    float fade [[flat]];       // 0 solid, 1 fully faded into the far field
    float facing [[flat]];     // 0 leaning away from the viewer, 1 leaning straight at it
    float alphaMul [[flat]];   // ring handoff crossfade
};

/// Vertices per blade: 7 segments as a strip of 7 quads ending in a single tip vertex.
constant uint kBladeVertices = 15;

[[vertex]] BladeOut grassInstancedBladeVertex(uint vid [[vertex_id]],
                                              uint iid [[instance_id]],
                                              constant Uniforms &U [[buffer(0)]],
                                              constant Ring *rings [[buffer(1)]],
                                              device atomic_uint *stats [[buffer(2)]],
                                              device const float *gu [[buffer(3)]],
                                              texture2d<float> control [[texture(0)]])
{
    BladeOut o;
    // Degenerate output for culled blades: outside the depth range, zero area.
    o.position = float4(0.0, 0.0, -2.0, 1.0);
    o.world = 0; o.normal = float3(0, 0, 1); o.tangent = float3(0, 0, 1); o.t = 0;
    o.farMean = 0; o.tipTint = 0; o.jitter = 1; o.lod = 0; o.fade = 0; o.facing = 0; o.alphaMul = 1;

    // Which ring, which lattice cell.
    int ringCount = int(U.blade2.w);
    int k = 0;
    for (int i = 1; i < ringCount; i++) {
        if (iid >= rings[i].start.x) { k = i; }
    }
    Ring R = rings[k];
    uint local = iid - R.start.x;
    uint nu = uint(R.cells.z);
    if (local >= nu * uint(R.cells.w)) { return o; }
    int iu = R.cells.x + int(local % nu);
    int iv = R.cells.y + int(local / nu);

    // Lattice hierarchy. Level-0 cells (size `natural`, world axes) each seed one
    // blade. Every level-j cell designates one of its four children by hash; a
    // blade's priority is how many consecutive levels designate it. A ring at level
    // k enumerates level-k cells and draws each cell's designated descendant, which
    // is exactly the set of blades the density rule keeps once spacing exceeds the
    // level's cell size, so rings need no crossfade and blades never change identity.
    int level = int(R.start.y);
    int2 cell = int2(iu, iv);
    int2 fine = cell;
    for (int j = level; j >= 1; j--) {
        uint c = pcg3d(uint3(uint(fine.x), uint(fine.y), 0x51ed27u + uint(j) * 0x9E3779B9u)).x & 3u;
        fine = fine * 2 + int2(int(c & 1u), int(c >> 1));
    }
    int priority = level;
    int2 cur = cell;
    for (int e = 0; e < 4; e++) {
        int2 parent = cur >> 1;
        uint lvl = uint(level + e + 1);
        uint c = pcg3d(uint3(uint(parent.x), uint(parent.y), 0x51ed27u + lvl * 0x9E3779B9u)).x & 3u;
        int2 chosen = parent * 2 + int2(int(c & 1u), int(c >> 1));
        if (all(chosen == cur)) { priority++; cur = parent; } else { break; }
    }

    uint3 h0 = pcg3d(uint3(uint(fine.x), uint(fine.y), 17u));
    uint3 h1 = pcg3d(h0 ^ uint3(0x68bc21ebu, 0x02e5be93u, 0x967a889bu));
    uint3 h2 = pcg3d(h1 + uint3(0x1b873593u, 0xcc9e2d51u, 0x85ebca6bu));
    uint3 h3 = pcg3d(h2 ^ uint3(0x27d4eb2fu, 0x165667b1u, 0xd3a2646cu));
    float3 r0 = unit3(h0), r1 = unit3(h1), r2 = unit3(h2), r3 = unit3(h3);
    // Rank in [0, 1): blades designated through `priority` levels rank below 4^-priority,
    // uniformly, so "rank < keep" keeps exactly a fraction `keep` of the lattice.
    float rank = exp2(-2.0 * float(priority)) * (0.25 + 0.75 * r3.x);

    float natural = U.clip.z;
    float2 fwdH = float2(U.lattice.y, U.lattice.x);     // (sin h, cos h)
    float2 root = (float2(fine) + r0.xy) * natural;

    float f = dot(root - U.eye.xy, fwdH);
    if (f < R.band.x || f >= R.band.y || f > U.lattice.w) { return o; }

    // Density: target spacing s(f) = max(f / cellsPerOctave, natural); keep (natural/s)^2
    // of the lattice. A narrow alpha window around the threshold, so a blade crossing
    // it as the camera moves fades over a few percent of distance instead of popping.
    float targetSpacing = max(f / U.lattice.z, natural);
    float keep = (natural * natural) / (targetSpacing * targetSpacing);
    float densityFade = smoothstep(keep * 0.94, keep * 1.06, rank);
    if (densityFade >= 0.999) { return o; }
    o.alphaMul = 1.0;

    // Frustum cull with a margin for the blade's own extent.
    float hMax = U.blade.y * 1.6;
    float4 clipRoot = U.viewProj * float4(root, 0.0, 1.0);
    if (clipRoot.w < 0.1) { return o; }
    float mx = U.clip.x * hMax * 1.5, my = U.clip.y * hMax * 1.5;
    if (abs(clipRoot.x) > clipRoot.w + mx || abs(clipRoot.y) > clipRoot.w + my) { return o; }

    // Control map at the root; coverage below a per-blade threshold removes the blade.
    Control ctl = sampleControl(control, root, U);
    if (ctl.coverage < 0.1 + 0.8 * r1.x) { return o; }

    // Fade toward the far field: by distance, and by sparsity once the lattice can no
    // longer place blades at turf density. Blades shrink, thin out and turn translucent.
    float fade = 0.0;
    if (U.grade.w >= 0.0) {
        fade = smoothstep(U.grade.w, U.lattice.w, f);
    }
    float spacingHere = targetSpacing;
    // Sparsity is judged against turf spacing (2.5 blade widths), not the lattice.
    float turfSpacing = max(U.blade.x * 2.5, 0.1);
    if (U.wind2.w > 0.0) {
        float sparse = spacingHere / turfSpacing;
        fade = max(fade, smoothstep(U.wind2.w * 0.35, U.wind2.w, sparse));
    }
    fade = max(fade, densityFade);
    if (fade >= 0.999) { return o; }
    o.fade = fade;

    if (vid == 0) { atomic_fetch_add_explicit(stats, 1u, memory_order_relaxed); }

    // Mown turf is cut to one height and combed one way by the mower; long grass
    // varies in height and sprawls. The control map's height channel sets which.
    float cut = 1.0 - smoothstep(0.2, 0.7, ctl.height);

    // Blade size.
    float heightVar = mix(0.65 + 0.7 * r1.y, 0.85 + 0.3 * r1.y, cut);
    float H = U.blade.y * mix(0.6, 2.0, ctl.height) * heightVar * (1.0 - 0.45 * fade);
    float spacing = spacingHere;
    float cmPerPixel = clipRoot.w * U.blade2.z;
    float W = max(U.blade.x * (0.7 + 0.6 * r1.z), max(U.blade2.x * spacing, U.blade2.y * cmPerPixel));

    // Bend: control-map lean plus wind plus a random tilt.
    float2 wl = windLean(root, r2.x * 6.2831853, U);
    float a = r2.y * 6.2831853;
    float2 rnd = float2(cos(a), sin(a));
    // Cut stubble stands mostly upright; the mower's lean shows in the shading
    // (the stripe term uses the full control-map lean) more than in the geometry.
    // Cut stubble stands mostly upright, unless something has pressed it flat: a
    // lean near full magnitude in the control map means trampled or rolled turf.
    float pressed = smoothstep(0.75, 0.98, length(ctl.lean));
    float leanGeo = mix(mix(1.0, 0.5, cut), 1.0, pressed);
    float2 bend = ctl.lean * 0.95 * leanGeo + wl + rnd * (0.15 + 0.35 * r0.z) * mix(1.0, 0.4, cut) * (1.0 - 0.7 * pressed);
    float m = length(bend);
    float2 bdir = m > 1e-4 ? bend / m : rnd;
    m = min(m, 0.93);
    float2 tipOff = bdir * (m * H);
    float tipZ = H * sqrt(1.0 - m * m);
    float3 P0 = float3(root, 0.0);
    float3 P1 = float3(root + tipOff * 0.15, mix(tipZ, H, 0.65));
    float3 P2 = float3(root + tipOff, tipZ);

    // Width direction: across the bend, randomly twisted, partly turned to the viewer
    // so thin blades do not vanish edge-on.
    float2 side2 = rotate(float2(-bdir.y, bdir.x), (r2.z - 0.5) * 1.4);
    float2 toEye = U.eye.xy - root;
    float te = length(toEye);
    float2 toEyeDir = te > 1e-3 ? toEye / te : float2(0.0, -1.0);
    float2 viewPerp = float2(-toEyeDir.y, toEyeDir.x);
    // Blades bent toward the viewer are seen end-on in a real canopy: tips and
    // shadow, not broad faces. Only away-leaning blades get turned to the viewer.
    float facing = saturate(dot(bdir, toEyeDir) * m / 0.6);
    o.facing = facing;
    float sgnV = dot(side2, viewPerp) >= 0.0 ? 1.0 : -1.0;
    side2 = normalize(mix(side2, viewPerp * sgnV, 0.35 * (1.0 - facing)));
    float3 side = float3(side2, 0.0);

    // This vertex.
    float t, s;
    if (vid >= kBladeVertices - 1) { t = 1.0; s = 0.0; }
    else { t = float(vid >> 1) / 7.0; s = (vid & 1u) ? 1.0 : -1.0; }
    float it = 1.0 - t;
    float3 pos = it * it * P0 + 2.0 * it * t * P1 + t * t * P2;
    float3 tangent = normalize(2.0 * it * (P1 - P0) + 2.0 * t * (P2 - P1) + float3(0, 0, 1e-4));
    // Pointed tips on long grass; a mower leaves blunt, square-cut tips.
    float w = 0.5 * W * pow(max(1.0 - t, 0.0), mix(0.6, 0.3, cut));
    pos += side * (s * w);

    float3 N = normalize(cross(tangent, side));
    // Fake a rounded cross-section so the blade is not flat-shaded across its width.
    N = normalize(N + side * (s * 0.45));

    o.position = U.viewProj * float4(pos, 1.0);
    o.world = pos;
    o.normal = N;
    o.tangent = tangent;
    o.t = t;

    // Per-blade colour: dry patches and brightness jitter.
    float patch = fbm3(root / max(U.atmos.w, 1.0) + 3.7);
    float dry = U.light.w * smoothstep(0.42, 0.78, patch);
    // Blades only a pixel or two wide: flatten per-blade variation to avoid speckle.
    // Blades much sparser than real turf (~1 cm apart) would show their dark bases
    // where a real canopy hides everything but the upper blades: treat them as LOD too.
    float pixelLod = 1.0 - smoothstep(1.0, 4.0, W / max(cmPerPixel, 1e-4));
    float sparse = smoothstep(1.5, 8.0, spacing / max(U.blade.x * 2.5, 0.1));
    o.lod = max(pixelLod, 0.85 * sparse);
    o.jitter = mix(0.8 + 0.4 * r1.z, 1.0, o.lod);
    o.tipTint = mix(U.tipColor.rgb, U.dryColor.rgb, dry);

    // The far-field turf colour at the root, from the shared shader, so the blade
    // layer's average matches the texture it fades into.
    float2 fwd = te > 1e-3 ? -toEye / te : fwdH;
    float3 toEye3 = U.eye.xyz - float3(root, 0.0);
    float3 V3 = toEye3 / max(length(toEye3), 1e-4);
    // Same clump structure as the far field, at the blade root; the far field's own
    // grain term is driven by screen position, which has no meaning here, so pass a
    // position where its band limit makes it vanish (blade texture is resolved).
    float periodHere = U.blade.x * 2.0 * (0.8 + 0.8 * ctl.height);
    // Blades already vary individually, so they take a smaller share of the clump
    // variation than the texture; the two still agree on where the clumps are.
    float variation = ::turfVariation(root, periodHere, cmPerPixel, float2(0.0), gu) * 0.6;
    o.farMean = ::grassFlatShade(ctl.lean + wl, ctl.height, dry, V3, fwd, saturate(V3.z),
                                        U.baseColor.rgb, U.tipColor.rgb, U.dryColor.rgb, U.sheenColor.rgb, variation, gu);
    return o;
}

[[fragment]] float4 grassInstancedBladeFragment(BladeOut in [[stage_in]],
                                                constant Uniforms &U [[buffer(0)]])
{
    float3 toEye = U.eye.xyz - in.world;
    float dist = length(toEye);
    float3 V = toEye / max(dist, 1e-4);
    float3 N = normalize(in.normal);
    if (dot(N, V) < 0.0) { N = -N; }       // two-sided
    N = normalize(mix(N, float3(0.0, 0.0, 1.0), 0.35 + 0.3 * saturate(in.t)));
    float3 L = normalize(U.light.xyz);
    float t = saturate(in.t);
    float ndl = dot(N, L);

    // Shape of a blade around the far-field mean: dark occluded base, lit tip, a
    // little per-pixel lighting. The visible canopy is mostly tips, so the constants
    // are set for the area-weighted mean of what is seen to land near 1.
    float along = mix(0.5, 1.15, pow(t, 0.7));
    float ao = mix(0.6, 1.0, smoothstep(0.0, 0.7, t));
    float lightMod = 0.8 + 0.35 * max(ndl, 0.0) + 0.25 * max(-ndl, 0.0) * t;
    // Seen end-on, a blade shows no lit face: flatten the facet term and sit the
    // whole blade a little into the canopy shadow.
    lightMod = mix(lightMod, 0.95, in.facing * 0.8);
    float shape = along * ao * lightMod * mix(1.0, 0.82, in.facing);
    // Fading blades lose contrast too, so they converge on the texture beneath.
    shape = mix(shape, 1.0, max(in.lod * 0.7, in.fade * 0.8));
    float gain = U.wind2.z > 0.0 ? U.wind2.z : 1.0;

    float3 c = in.farMean * shape * in.jitter * gain;

    // Tip glint along the blade tangent, small, on top of the mean.
    float3 T = normalize(in.tangent);
    float3 Hv = normalize(L + V);
    float TdotH = dot(T, Hv);
    float sinTH = sqrt(max(1.0 - TdotH * TdotH, 0.0));
    float spec = pow(sinTH, max(U.shade.z, 1.0)) * U.shade.y * t * max(ndl, 0.2) * 0.35 * (1.0 - in.fade) * (1.0 - 0.7 * in.facing);
    c += spec * mix(in.tipTint, float3(1.0), 0.5);

    float alpha = (1.0 - in.fade) * in.alphaMul;
    return finish(c, alpha, dist, in.position.xy, U);
}

// MARK: - Ground (full-screen ray cast)

struct GroundOut {
    float4 position [[position]];
    float2 ndc;
};

[[vertex]] GroundOut grassInstancedGroundVertex(uint vid [[vertex_id]]) {
    float2 p = float2(vid == 1 ? 3.0 : -1.0, vid == 2 ? 3.0 : -1.0);
    GroundOut o;
    o.position = float4(p, 1.0, 1.0);
    o.ndc = p;
    return o;
}

[[fragment]] float4 grassInstancedGroundFragment(GroundOut in [[stage_in]],
                                                 constant Uniforms &U [[buffer(0)]],
                                                 texture2d<float> control [[texture(0)]])
{
    float3 d = U.camFwd.xyz + U.camRight.xyz * (in.ndc.x * U.camRight.w) + U.camUp.xyz * (in.ndc.y * U.camUp.w);
    float3 fog = U.fogColor.rgb;
    float fogA = U.fogColor.a;

    if (d.z >= -1e-6) {
        // Sky: transparent, with an optional fog glow above the horizon.
        float slope = max(abs(U.camUp.z * U.camUp.w * 2.0 * U.viewport.w), 1e-6);
        float px = d.z / slope;
        float glow = U.atmos.z;
        if (glow <= 0.0 || fogA <= 0.0) { return float4(0.0); }
        float a = fogA * exp(-pow(px / glow, 2.0));
        return float4(fog * a, a);
    }

    float3 eye = U.eye.xyz;
    float tt = -eye.z / d.z;
    float2 g = eye.xy + tt * d.xy;
    float3 toEye = eye - float3(g, 0.0);
    float dist = length(toEye);
    float sinE = saturate(toEye.z / max(dist, 1e-4));
    float footprint = dist * U.blade2.z / max(sinE, 0.05);
    float graze = 1.0 - sinE;

    Control ctl = sampleControl(control, g, U);
    float2 fwdH = float2(U.lattice.y, U.lattice.x);
    float fwdDist = dot(g - eye.xy, fwdH);
    float2 fwd = normalize(-toEye.xy + float2(1e-5, 0.0));
    float s = clamp(dot(ctl.lean, fwd), -1.0, 1.0);
    float stripe = 1.0 + U.shade.x * mix(0.7, 1.0, graze) * s;

    float3 base = U.baseColor.rgb, tip = U.tipColor.rgb;
    float patch = fbm3(g / max(U.atmos.w, 1.0) + 3.7);
    float dry = U.light.w * smoothstep(0.42, 0.78, patch);
    float3 L = normalize(U.light.xyz);
    float diffuse = 0.45 + 0.55 * max(L.z, 0.0);

    // Canopy floor between blades: dark and shadowed. Beyond the blade range (and as
    // blades thin out toward it) the ground stands in for the whole canopy.
    float3 interior = mix(base, tip, 0.35) * 0.8;
    float3 canopy = mix(mix(base, tip, 0.5), U.dryColor.rgb, dry * 0.8) * diffuse;
    float skySheen = 0.5 * U.shade.y * pow(graze, 2.5) * (0.35 + 0.65 * (0.5 + 0.5 * s));
    canopy += U.sheenColor.rgb * skySheen * 0.6;
    canopy *= 1.0 + U.shade.w * pow(graze, 2.5);
    float far = U.lattice.w;
    float farMix = smoothstep(far * 0.05, far * 0.7, fwdDist);
    float3 turf = mix(interior, canopy, farMix) * stripe;

    float grit = mix(0.5, vnoise(g / 0.6 + 2.0), bandLimit(0.6, footprint));
    float clod = mix(0.5, fbm3(g / 5.0 + 5.5), bandLimit(5.0, footprint));
    float damp = mix(0.5, fbm3(g / 40.0 + 9.0), bandLimit(40.0, footprint));
    float3 soil = U.soilColor.rgb * (0.75 + 0.5 * clod) * (0.85 + 0.3 * grit) * (0.85 + 0.3 * damp);
    soil *= 1.0 + U.shade.w * 0.4 * pow(graze, 2.5);
    soil *= mix(1.0, 0.8, smoothstep(0.0, 0.6, ctl.coverage));

    float mask = smoothstep(0.3, 0.6, ctl.coverage);
    float soilA = U.soilColor.a;
    float3 rgb = mix(soil * soilA, turf, mask);
    float alpha = mix(soilA, 1.0, mask);
    return finish(alpha > 0.0 ? rgb / alpha : rgb, alpha, dist, in.position.xy, U);
}

// MARK: - Ground pass with the full turf shader (GrassMetalRenderer)

/// Colours for the shared turf shader, straight (un-premultiplied is NOT expected:
/// the shader un-premultiplies, so these are premultiplied like SwiftUI's `.color`).
struct GrassColors {
    float4 base;
    float4 tip;
    float4 dry;
    float4 soil;
    float4 sheen;
    float4 fog;
};

/// Pixel-to-point conversion and map size for the ground pass.
struct GrassGroundParams {
    float pixelScale;   // pixels per point
    float mapW;         // control map size in points
    float mapH;
    int uCount;
};

/// Reads the control texture in control-map points, matching SwiftUI::Layer.sample.
struct TextureControlSampler {
    texture2d<half> tex;
    float2 invSize;
    half4 sample(float2 p) {
        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear);
        return tex.sample(s, p * invSize);
    }
};

[[fragment]] half4 grassMetalGroundFragment(GroundOut in [[stage_in]],
                                            device const float *u [[buffer(0)]],
                                            constant GrassColors &colors [[buffer(1)]],
                                            constant GrassGroundParams &params [[buffer(2)]],
                                            texture2d<half> control [[texture(0)]])
{
    TextureControlSampler sampler{ control, float2(1.0 / params.mapW, 1.0 / params.mapH) };
    float2 position = in.position.xy / max(params.pixelScale, 0.5);
    return grassShade(position, sampler, float2(params.mapW, params.mapH), u, params.uCount,
                      half4(colors.base), half4(colors.tip), half4(colors.dry),
                      half4(colors.soil), half4(colors.sheen), half4(colors.fog));
}
