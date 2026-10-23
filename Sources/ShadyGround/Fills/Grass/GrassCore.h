//
//  GrassCore.h
//  ShadyGround
//
//  The turf shading shared by the SwiftUI layer effect (GrassShader.metal) and the
//  Metal surface renderer (Instanced/GrassInstanced.metal). The control map is
//  abstracted as any type with `half4 sample(float2 mapPoint)`, where mapPoint is in
//  control-map points, so the same code reads a SwiftUI::Layer or a texture.
//
//  See GrassShader.metal for the control-map encoding and GrassUniform in
//  GrassScene.swift for the float-array layout mirrored by namespace U below.
//

#pragma once
#include <metal_stdlib>
using namespace metal;

namespace U {
    constant int eyeX = 0, eyeY = 1, eyeZ = 2;
    constant int m00 = 3;                          // 3x3 ray matrix, row-major, 9 floats
    constant int mapOriginX = 12, mapOriginY = 13; // map point (pt) of ground origin
    constant int cmPerPoint = 14;
    constant int mapW = 15, mapH = 16;
    constant int topDown = 17;
    constant int bladeWidth = 18, bladeLength = 19, bladeHeight = 20, heightScale = 21;
    constant int leanScale = 22, grainX = 23, grainY = 24, contrast = 25;
    constant int stripeContrast = 26, lightX = 27, lightY = 28, lightZ = 29;
    constant int sheen = 30, sheenPower = 31, grazeBrighten = 32;
    constant int windStrength = 33, windScale = 34, windSpeed = 35, windX = 36, windY = 37, time = 38;
    constant int variation = 39, patchScale = 40, edgeSoftness = 41;
    constant int shellCount = 42, shellRange = 43;
    constant int fogDistance = 44, desatDistance = 45, horizonGlow = 46;
    constant int exposure = 47, saturation = 48, vignette = 49;
    constant int viewX = 50, viewY = 51;
    constant int edgeBlur = 52, pixelScale = 53;
    constant int nearInterior = 54, nearFadeStart = 55, nearFadeEnd = 56, nearDense = 57;
    constant int count = 58;
}

namespace grassfx {

// MARK: Noise

inline float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

inline float2 hash22(float2 p) {
    float3 p3 = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
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
    float v = 0.0;
    v += 0.5   * vnoise(p);
    v += 0.25  * vnoise(p * 2.03 + 17.1);
    v += 0.125 * vnoise(p * 4.11 + 31.7);
    return v / 0.875;
}

inline float2 rotate(float2 p, float a) {
    float c = cos(a), s = sin(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

/// Band limit: 1 when the noise period is well above the pixel footprint, 0 when below.
inline float bandLimit(float period, float footprint) {
    return saturate(period / max(footprint, 1e-4) - 1.0);
}

/// Streak noise: a short line-integral convolution along `dir`, producing blade-like
/// streaks that follow a spatially varying direction field. Tap count drops with footprint.
inline float streakNoise(float2 p, float2 dir, float period, float length, float footprint) {
    // A fixed tap count: switching counts by footprint changes the texture's whole
    // character across a line that moves with the camera.
    const int taps = 9;
    float maxLength = float(taps - 1) * period * 0.9;
    length = min(length, maxLength);
    float sum = 0.0;
    for (int k = 0; k < taps; k++) {
        float t = (float(k) / float(taps - 1) - 0.5) * length;
        sum += vnoise((p + dir * t) / period);
    }
    return sum / float(taps);
}

/// Cone field for soil clods: distance to jittered feature points.
inline float coneField(float2 p, float cell) {
    float2 q = p / cell;
    float2 i = floor(q);
    float2 f = fract(q);
    float best = 8.0;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 n = float2(x, y);
            float2 fp = n + hash22(i + n) - f;
            best = min(best, dot(fp, fp));
        }
    }
    return saturate(1.0 - sqrt(best) / 0.95);
}

/// Blade height field. Each cell (width `cell`, length `cell * aspect`) seeds one
/// blade that starts at a jittered root and runs along +y with a random tilt,
/// tapering toward the tip. Height rises from 0 at the root to the blade's full
/// height at the tip, so the top shells catch only tips and lower shells the body.
/// `aa` is the pixel footprint in cell units and softens the blade edges.
/// Returns height fraction, blade id, position along the blade (0 root, 1 tip) and
/// edge coverage 0...1.
inline float4 bladeField(float2 p, float cell, float aspect, float aa) {
    float2 q = p / float2(cell, cell * aspect);
    float2 i = floor(q);
    float2 f = fract(q);
    float best = 0.0;
    float id = 0.0;
    float along = 0.0;
    float alpha = 0.0;
    for (int y = -1; y <= 0; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 n = float2(x, y);
            float2 h = hash22(i + n);
            float2 d = f - (n + h * float2(1.0, 0.5));     // root -> this point
            float tilt = (h.x - 0.5) * 1.1;
            float ct = cos(tilt), st = sin(tilt);
            float2 dr = float2(ct * d.x - st * d.y / aspect, st * d.x * aspect + ct * d.y);
            float len = 0.65 + 0.6 * h.y;
            float t = dr.y / len;
            if (t < 0.0 || t > 1.0) { continue; }
            float w = 0.5 * (1.0 - 0.85 * t) * (0.7 + 0.6 * h.x);
            float e = saturate((w - abs(dr.x)) / max(aa, 1e-3) + 0.5);
            if (e <= 0.0) { continue; }
            float bid = hash21(i + n + 7.0);
            float height = t * (0.55 + 0.45 * bid);
            if (height > best) { best = height; id = bid; along = t; alpha = e; }
        }
    }
    return float4(best, id, along, alpha);
}

/// SwiftUI passes `.color()` arguments premultiplied; recover straight colour.
inline float3 straight(half4 c) {
    float a = float(c.a);
    return a > 0.001 ? float3(c.rgb) / a : float3(0.0);
}

inline float luma(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }

// MARK: Ground projection

struct Ground {
    float2 g;        // ground point, cm
    float3 V;        // unit vector from ground point to eye
    float sinE;      // sine of view elevation (1 = straight down)
    float2 fwd;      // horizontal view direction from eye to point
    float fMaj;      // pixel footprint on the ground, cm, major axis
    float fMin;      // minor axis
    float2 majDir;   // ground direction of the major axis
    float dist;      // eye to point, cm
    bool valid;      // below the horizon
    float aboveHorizonPx;
};

inline Ground project(float2 pos, device const float *u) {
    Ground r;
    float3 eye = float3(u[U::eyeX], u[U::eyeY], u[U::eyeZ]);
    float cmpp = u[U::cmPerPoint];
    float2 origin = float2(u[U::mapOriginX], u[U::mapOriginY]);

    if (u[U::topDown] > 0.5) {
        r.g = float2((pos.x - origin.x) * cmpp, -(pos.y - origin.y) * cmpp);
        r.V = float3(0.0, 0.0, 1.0);
        r.sinE = 1.0;
        r.fwd = float2(u[U::viewX], u[U::viewY]);
        r.fMaj = cmpp / max(u[U::pixelScale], 0.5); r.fMin = r.fMaj;
        r.majDir = float2(1.0, 0.0);
        r.dist = 0.0;
        r.valid = true;
        r.aboveHorizonPx = -1.0;
        return r;
    }

    float3 c0 = float3(u[U::m00 + 0], u[U::m00 + 3], u[U::m00 + 6]);
    float3 c1 = float3(u[U::m00 + 1], u[U::m00 + 4], u[U::m00 + 7]);
    float3 c2 = float3(u[U::m00 + 2], u[U::m00 + 5], u[U::m00 + 8]);
    float3 d = c0 * pos.x + c1 * pos.y + c2;

    // Pixels per unit of d.z, for an anti-aliased horizon.
    float dzSlope = max(length(float2(c0.z, c1.z)), 1e-6);
    r.aboveHorizonPx = d.z / dzSlope;

    if (d.z >= -1e-5) {
        r.valid = false;
        r.g = 0; r.V = float3(0, 0, 1); r.sinE = 0; r.fwd = float2(0, 1);
        r.fMaj = r.fMin = 1e6; r.majDir = float2(1, 0); r.dist = 1e9;
        return r;
    }

    float t = -eye.z / d.z;
    r.g = eye.xy + t * d.xy;

    // Beyond a couple of kilometres the ground is fog anyway, and the noise
    // functions lose precision, so treat it as horizon.
    const float farLimit = 2.0e5;
    if (t * length(d) > farLimit) {
        r.valid = false;
        r.aboveHorizonPx = 0.0;
        r.V = float3(0, 0, 1); r.sinE = 0; r.fwd = float2(0, 1);
        r.fMaj = r.fMin = 1e6; r.majDir = float2(1, 0); r.dist = farLimit;
        return r;
    }

    // Jacobian of the ground point with respect to pixel position.
    float dt0 = eye.z * c0.z / (d.z * d.z);
    float dt1 = eye.z * c1.z / (d.z * d.z);
    float2 j0 = t * c0.xy + dt0 * d.xy;
    float2 j1 = t * c1.xy + dt1 * d.xy;
    float l0 = length(j0), l1 = length(j1);
    if (l0 >= l1) { r.fMaj = l0; r.fMin = l1; r.majDir = j0 / max(l0, 1e-6); }
    else          { r.fMaj = l1; r.fMin = l0; r.majDir = j1 / max(l1, 1e-6); }

    float px = max(u[U::pixelScale], 0.5);
    r.fMaj /= px; r.fMin /= px;

    float3 toEye = eye - float3(r.g, 0.0);
    r.dist = length(toEye);
    r.V = toEye / max(r.dist, 1e-4);
    r.sinE = saturate(r.V.z);
    float2 h = -r.V.xy;
    float hl = length(h);
    r.fwd = hl > 1e-5 ? h / hl : float2(0.0, 1.0);
    r.valid = true;
    return r;
}

/// Ground cm -> control map points (map y runs down the screen, ground y runs up the field).
inline float2 toMap(float2 g, device const float *u) {
    float cmpp = u[U::cmPerPoint];
    float2 mp = float2(u[U::mapOriginX], u[U::mapOriginY]) + float2(g.x, -g.y) / cmpp;
    return clamp(mp, float2(0.5), float2(u[U::mapW], u[U::mapH]) - 0.5);
}

struct Control {
    float2 lean;     // ground-space lean
    float height;    // 0...1
    float coverage;  // 0...1
};

/// Footprint-filtered control sample: up to 4 taps along the major axis, premultiplied
/// average, then decoded.
template <typename Sampler>
inline Control sampleControl(Sampler layer, Ground gr, float2 g, device const float *u) {
    float blur = u[U::edgeBlur];
    float rMaj = max(gr.fMaj * 0.5, blur);
    float rMin = max(gr.fMin * 0.5, blur);
    float2 minDir = float2(-gr.majDir.y, gr.majDir.x);
    half4 acc = layer.sample(toMap(g, u)) * 2.0h;
    acc += layer.sample(toMap(g + gr.majDir * rMaj, u));
    acc += layer.sample(toMap(g - gr.majDir * rMaj, u));
    acc += layer.sample(toMap(g + minDir * rMin, u));
    acc += layer.sample(toMap(g - minDir * rMin, u));
    float4 c = float4(acc) / 6.0;
    Control ctl;
    ctl.coverage = saturate(c.a);
    float3 rgb = ctl.coverage > 0.001 ? saturate(c.rgb / ctl.coverage) : float3(0.5, 0.5, 0.3);
    float2 leanMap = (rgb.xy - 0.5) * 2.0 * u[U::leanScale];
    ctl.lean = float2(leanMap.x, -leanMap.y);
    ctl.height = saturate(rgb.z * u[U::heightScale]);
    return ctl;
}

template <typename Sampler>
inline float coverageAt(Sampler layer, float2 g, device const float *u) {
    return float(layer.sample(toMap(g, u)).a);
}

} // namespace grassfx

// MARK: - Main Shader

// MARK: - Lighting shared by the far field and blade geometry

struct Lighting {
    float diffuse;
    float stripe;
    float spec;       // anisotropic highlight factor, before the blade-texture weight
    float skySheen;
    float grazeGain;
    float s;          // stripe term, -1...1
};

inline Lighting grassLighting(float2 leanShade, float3 V, float2 fwd, float sinE, device const float *u) {
    Lighting r;
    float3 L = normalize(float3(u[U::lightX], u[U::lightY], u[U::lightZ]));
    float graze = 1.0 - sinE;
    float m = length(leanShade);

    float3 N = normalize(float3(-leanShade * 0.12, 1.0));
    r.diffuse = 0.4 + 0.6 * max(dot(N, L), 0.0);

    float3 T = normalize(float3(leanShade, max(1.0 - 0.7 * m, 0.15)));
    float3 H = normalize(L + V);
    float TdotH = dot(T, H);
    float sinTH = sqrt(max(1.0 - TdotH * TdotH, 0.0));
    // Blade sheen is a grazing-angle effect; from above it would paint one stripe set.
    float sheen = u[U::sheen] * mix(0.1, 1.0, graze * graze);
    r.spec = pow(sinTH, max(u[U::sheenPower], 1.0)) * sheen;

    // Mow stripe. Near grazing angles blades leaning away from the viewer show their
    // lit flat sides; looking down, blades leaning away from the sun show their lit
    // tops. Measured ratios: about 1.1-1.3x from stands and drones, 2x+ from ground level.
    float2 Lh = L.xy;
    float LhLen = length(Lh);
    Lh = LhLen > 1e-4 ? Lh / LhLen : float2(0.0, -1.0);
    float viewness = pow(graze, 1.5);
    float sView = clamp(dot(leanShade, fwd), -1.0, 1.0);
    float sLight = clamp(dot(leanShade, -Lh), -1.0, 1.0);
    r.s = mix(sLight, sView, viewness);
    float stripeContrast = u[U::stripeContrast] * mix(0.15, 0.6, pow(graze, 2.5));
    r.stripe = 1.0 + stripeContrast * r.s;

    // Sky sheen: additive, desaturating, strongest at grazing angles and on away-leaning blades.
    r.skySheen = 0.5 * sheen * pow(graze, 2.5) * (0.35 + 0.65 * (0.5 + 0.5 * r.s));
    r.grazeGain = 1.0 + u[U::grazeBrighten] * pow(graze, 2.5);
    return r;
}

/// Brightness variation of turf at clump scales, 0-centred: log-spaced mottle octaves
/// from a few centimetres to a couple of metres plus tuft noise, each band-limited by
/// the pixel footprint. Shared by the far field and the blade geometry so the two
/// carry the same clump structure. `screenPos` is in points for the pixel grain.
inline float turfVariation(float2 g, float period, float fp, float2 screenPos, device const float *u) {
    using namespace grassfx;
    float mottle = 0.0;
    float mp = max(period * 4.0, 2.0);
    float amp = 0.45;
    for (int k = 0; k < 5; k++) {
        float bl = bandLimit(mp, fp);
        if (bl > 0.0) {
            float n = vnoise(rotate(g, float(k) * 0.9) / mp + float(k) * 13.1) - 0.5;
            mottle += n * bl * amp;
        }
        mp *= 3.0;
        amp *= 0.4;
    }
    float tuftPeriod = period * 2.5;
    float bl4 = bandLimit(tuftPeriod, fp);
    if (bl4 > 0.0) { mottle += (vnoise(rotate(g, 0.9) / tuftPeriod + 19.0) - 0.5) * bl4 * 0.55; }
    // Unresolved blades still sparkle. Screen-space grain, only where blade texture
    // is fully gone (grain fixed to the screen over ground that is still resolved
    // reads as a dirty window under camera motion), and re-seeded every frame so it
    // twinkles like sub-pixel blades do instead of sticking to the pixels.
    float bl1 = bandLimit(period, fp);
    float px = max(u[U::pixelScale], 0.5);
    float seed = floor(u[U::time] * 60.0) * 0.37;
    float grain = hash21(floor(screenPos * px) + 0.5 + seed) - 0.5;
    mottle += grain * 0.14 * smoothstep(0.25, 0.0, bl1);
    return mottle;
}

/// The far-field turf colour at a point with every texture term at its mean, before
/// fog and grading. Blade geometry modulates around this so its average matches the
/// texture it fades into.
inline float3 grassFlatShade(float2 leanShade, float height, float dryMix, float3 V, float2 fwd, float sinE,
                             float3 base, float3 tip, float3 dry, float3 sheenTint, float variation,
                             device const float *u) {
    float3 col = mix(base, tip, saturate(0.5 + 0.22 * sinE * sinE));
    col *= max(1.0 + variation * u[U::contrast], 0.05);
    col = mix(col, dry, dryMix);
    col *= mix(1.0, 0.72 + 0.28 * 0.5, height);
    Lighting lt = grassLighting(leanShade, V, fwd, sinE, u);
    float3 c = col * lt.diffuse * lt.stripe + lt.spec * 0.75 * mix(tip, float3(1.0), 0.5) + sheenTint * lt.skySheen;
    return c * lt.grazeGain;
}

// MARK: - Shading entry point

/// Shades one pixel of turf. `position` and `size` are in control-map points.
template <typename Sampler>
inline half4 grassShade(float2 position,
                        Sampler layer,
                        float2 size,
                        device const float *u,
                        int uCount,
                        half4 baseColor,
                        half4 tipColor,
                        half4 dryColor,
                        half4 soilColor,
                        half4 sheenColor,
                        half4 fogColor)
{
    using namespace grassfx;
    if (uCount < U::count) { return half4(1.0h, 0.0h, 1.0h, 1.0h); }

    Ground gr = project(position, u);

    float3 fog = straight(fogColor);
    float fogA = float(fogColor.a);

    // MARK: Sky

    if (!gr.valid) {
        float glow = u[U::horizonGlow];
        if (glow <= 0.0 || fogA <= 0.0) { return half4(0.0h); }
        float a = fogA * exp(-pow(gr.aboveHorizonPx / glow, 2.0));
        return half4(half3(fog * a), half(a));
    }

    float2 g = gr.g;
    float fp = gr.fMaj;
    float fpMin = gr.fMin;

    // MARK: Control map

    float jitterPeriod = max(u[U::bladeWidth], 0.02) * 5.0;
    float jitterAmp = jitterPeriod * 0.8 * bandLimit(jitterPeriod, fp);
    float2 jitter = jitterAmp > 0.0
        ? (float2(vnoise(g / jitterPeriod + 23.0), vnoise(rotate(g, 1.1) / jitterPeriod + 57.0)) - 0.5) * jitterAmp
        : float2(0.0);
    Control ctl = sampleControl(layer, gr, g + jitter, u);
    float2 lean = ctl.lean;
    float height = ctl.height;
    float coverage = ctl.coverage;

    // MARK: Wind

    float2 wind = float2(0.0);
    float windStrength = u[U::windStrength];
    if (windStrength > 0.0) {
        float2 wdir = float2(u[U::windX], u[U::windY]);
        float wlen = length(wdir);
        wdir = wlen > 0.001 ? wdir / wlen : float2(1.0, 0.0);
        float2 wp = (g - wdir * (u[U::time] * u[U::windSpeed])) / max(u[U::windScale], 1.0);
        float gust = fbm3(wp) * 2.0 - 1.0;
        float sway = fbm3(wp * 1.7 + 41.3) * 2.0 - 1.0;
        float2 across = float2(-wdir.y, wdir.x);
        wind = windStrength * (wdir * (0.55 + 0.45 * gust) + across * 0.35 * sway);
    }
    float2 leanShade = lean + wind;

    // MARK: Blade texture (far field)

    float leanMag = length(lean);
    float2 grain = float2(u[U::grainX], u[U::grainY]);
    float grainLen = length(grain);
    grain = grainLen > 0.001 ? grain / grainLen : float2(0.0, 1.0);
    float2 dir = leanMag > 0.02 ? lean / leanMag : grain;

    float bladeWidth = max(u[U::bladeWidth], 0.02);
    float period = bladeWidth * 2.0 * (0.8 + 0.8 * height);
    float streak = u[U::bladeLength] * period * (0.35 + 0.65 * min(leanMag, 1.0)) * (0.6 + 0.8 * height);

    float graze = 1.0 - gr.sinE;

    // Standing blades: at grazing angles a texture lying on the ground foreshortens
    // into fine horizontal grain, while real blades stand up and project tall on
    // screen. Parallax-map the blade texture with a ground-anchored height field:
    // each sample is offset along the view direction by the local canopy height
    // times cot(elevation), so features stand up and parallax like geometry, and
    // never slide over the ground when the camera moves.
    // A noise height field cannot parallax rigidly like real blades: at grazing
    // angles a full-height offset shears the texture as the camera moves. Keep the
    // parallax small and get the standing look mostly from streaks elongated along
    // the view direction, which stay anchored to the ground.
    float stand = graze * graze;
    float cotE = min(sqrt(max(1.0 - gr.sinE * gr.sinE, 0.0)) / max(gr.sinE, 0.05), 8.0);
    float canopy = max(u[U::bladeHeight], 0.05) * (0.4 + 0.8 * height);
    float hField = vnoise(g / (period * 2.0) + 43.0);
    float2 sp = g + wind * 3.0 * bladeWidth;
    float2 spStand = sp + gr.fwd * (hField * canopy * cotE * stand * 0.2);
    float2 dirStand = normalize(mix(dir, gr.fwd, stand * 0.8));
    float standStretch = mix(1.0, 1.0 / max(gr.sinE, 0.2), stand);

    // Anisotropic filtering. The pixel footprint on the ground is long along the view
    // and short across it. The streak integral runs along the view at grazing angles,
    // so making it at least as long as the along-view footprint filters that axis;
    // the band limit then only has to respect the across-view footprint. Without
    // this the texture aliases along the view and boils under camera motion.
    float fpAcross = max(gr.fMin, gr.fMaj / 8.0);
    // Blade-scale features reach full contrast at about three pixels, not two: at
    // two pixels the speckle boils under motion even though it is anchored.
    float bl1 = bandLimit(period, fpAcross * 1.5);
    float n = 0.5;
    if (bl1 > 0.0) {
        float aniso = 1.0 - smoothstep(0.15, 0.5, fpAcross / period);
        float along = max(streak * aniso * standStretch, 1.5 * gr.fMaj);
        n = streakNoise(spStand, dirStand, period, along, fpAcross);
    }
    float fpStand = fpAcross;
    // Isotropic detail terms cannot be filtered along the view, so they keep the full footprint.
    float finePeriod = period * 0.55;
    float bl2 = bandLimit(finePeriod, fp);
    float fine = bl2 > 0.0 ? vnoise(rotate(spStand, 0.61) / finePeriod + 7.3) : 0.5;

    float contrast = u[U::contrast];
    // Blades have hard edges: sharpen the averaged streak noise where it is well
    // resolved so texture matches blade geometry's crispness. Sharpening adds
    // harmonics above the noise's own band, so it must stop well before the band
    // limit does, or the edges crawl under camera motion.
    float sharpAmt = bandLimit(period * 0.5, fpStand * 2.0);
    float nSharp = mix(n, smoothstep(0.36, 0.64, n), sharpAmt);
    float blades = clamp((nSharp - 0.5) * mix(2.4, 1.6, sharpAmt) * contrast * bl1 + 0.5, 0.0, 1.0);
    blades = mix(blades, mix(0.5, fine, bl2), 0.22);

    float mottle = turfVariation(g, period, fp, position, u);

    // MARK: Colour

    float3 base = straight(baseColor);
    float3 tip  = straight(tipColor);
    float3 dry  = straight(dryColor);

    // Looking down you see lit blade tops; looking across you see shaded sides.
    float tipView = 0.22 * gr.sinE * gr.sinE;
    float3 col = mix(base, tip, saturate(blades + tipView));
    col *= max(1.0 + mottle * contrast, 0.05);

    float patchScale = max(u[U::patchScale], 1.0);
    float patch = mix(0.5, fbm3(g / patchScale + 3.7), bandLimit(patchScale * 0.5, fp));
    col = mix(col, dry, saturate(u[U::variation]) * smoothstep(0.42, 0.78, patch));
    col *= mix(1.0, 0.72 + 0.28 * blades, height);

    // MARK: Lighting

    float3 V = gr.V;
    Lighting lt = grassLighting(leanShade, V, gr.fwd, gr.sinE, u);
    float diffuse = lt.diffuse;
    float sheen = u[U::sheen];
    float spec = lt.spec * (0.5 + 0.5 * blades);
    float s = lt.s;
    float stripe = lt.stripe;
    float3 sheenTint = straight(sheenColor);
    float skySheen = lt.skySheen;

    float3 far = col * diffuse * stripe + spec * mix(tip, float3(1.0), 0.5) + sheenTint * skySheen;
    far *= lt.grazeGain;

    // Under a blade-geometry layer the ground is the canopy interior, in shadow;
    // the lit tips are drawn by the blades. Fades back to the plain far field
    // where the blades fade out.
    float interior = u[U::nearInterior];
    if (interior > 0.0) {
        // Blade coverage: full while the lattice is at canopy density, then falling as
        // 1/d² once the lattice thins, and with the blades' own alpha fade on top.
        float f = smoothstep(u[U::nearFadeStart], u[U::nearFadeEnd], gr.dist);
        float dense = u[U::nearDense];
        float density = dense > 0.0 ? min(1.0, (dense * dense) / max(gr.dist * gr.dist, 1.0)) : 1.0;
        float covered = density * (1.0 - f);
        far *= mix(1.0, 1.0 - interior, covered);
    }

    // MARK: Foreground blade shells

    float bladeHeight = max(u[U::bladeHeight], 0.05) * (0.4 + 0.8 * height);
    float shellRange = u[U::shellRange];
    float nearW = smoothstep(bladeWidth * shellRange, bladeWidth * shellRange * 0.25, fpMin);
    if (u[U::topDown] > 0.5) { nearW = 0.0; }
    int maxShells = clamp(int(u[U::shellCount]), 0, 16);
    float3 near = far;
    float nearCoverage = coverage;

    if (nearW > 0.0 && maxShells > 0) {
        float3 eye = float3(u[U::eyeX], u[U::eyeY], u[U::eyeZ]);
        float cell = bladeWidth * 2.0;
        float bladeAngle = atan2(dir.y, dir.x) - 1.5707963;
        float aa = fpMin / cell;

        // Parallax of the full blade height on the ground; keep slices closer than a blade width.
        float clumpPeriodNear = bladeWidth * 18.0;
        float2 clumpLean = (float2(vnoise(g / clumpPeriodNear + 71.0), vnoise(rotate(g, 2.1) / clumpPeriodNear + 93.0)) - 0.5) * 1.1;
        float2 bladeLean = leanShade + clumpLean;

        float2 par = (eye.xy - g) * (bladeHeight / max(eye.z, 1e-3));
        int shells = clamp(int(length(par) / bladeWidth) + 1, 3, maxShells);
        float sliceH = bladeHeight / float(shells);

        float3 acc = float3(0.0);
        float accA = 0.0;
        float topCov = 0.0;
        float stripeNear = 1.0 + u[U::stripeContrast] * mix(0.15, 0.6, pow(graze, 2.5)) * s * 0.35;

        for (int i = 0; i < shells && accA < 0.97; i++) {
            float h = bladeHeight * (1.0 - float(i) / float(shells));
            float2 gi = g + (eye.xy - g) * (h / max(eye.z, 1e-3));
            float covi = coverageAt(layer, gi + jitter, u);
            if (i == 0) { topCov = covi; }
            float2 root = gi - bladeLean * h * 0.8;
            float4 bf = bladeField(rotate(root, -bladeAngle), cell, 5.0, aa);
            float bh = bf.x * bladeHeight;
            float gate = vnoise(rotate(root, -0.4) / (cell * 2.5) + 11.0) * 0.8 + 0.1;
            float a = saturate((bh - h) / sliceH + 0.5) * bf.w * step(gate, covi);
            if (a <= 0.0) { continue; }
            float hf = saturate(bf.z);
            float ao = mix(0.35, 1.0, pow(hf, 0.7));
            float3 bc = mix(base, tip, pow(hf, 0.7)) * (0.85 + 0.3 * bf.y);
            bc = mix(bc, dry, saturate(u[U::variation]) * smoothstep(0.42, 0.78, patch) * 0.7);
            float tipGlint = pow(hf, 6.0) * sheen * 0.8 * (0.5 + 0.5 * s);
            float3 sc = bc * ao * diffuse * stripeNear + tipGlint * mix(tip, float3(1.0), 0.6) + sheenTint * skySheen * hf;
            sc *= 1.0 + u[U::grazeBrighten] * pow(graze, 2.5) * 0.5;
            float wgt = a * (1.0 - accA);
            acc += sc * wgt;
            accA += wgt;
        }

        // Whatever is left shows the dark canopy interior.
        float3 interior = mix(base, tip, 0.2) * 0.6 * stripeNear * diffuse;
        near = acc + interior * (1.0 - accA);
        nearCoverage = max(coverage, topCov * accA);
    }

    col = mix(far, near, nearW);
    coverage = mix(coverage, nearCoverage, nearW);

    // MARK: Coverage and soil

    // Close up, one map texel spans many pixels and its bilinear ramp would smear the
    // dirt edge. Treat the ramp as a distance field and re-threshold it at the pixel scale.
    float texel = u[U::cmPerPoint];
    float sharpW = clamp(fp / texel * 0.5, 0.03, 0.5);
    coverage = mix(smoothstep(0.5 - sharpW, 0.5 + sharpW, coverage), coverage, smoothstep(0.5, 2.0, fp / texel));

    float maskPeriod = period * 1.6;
    float blm = bandLimit(maskPeriod, fp);
    float maskNoise = mix(0.5, vnoise(rotate(g, -0.4) / maskPeriod + 11.0) * 0.8 + 0.1, blm);
    float soft = mix(clamp(u[U::edgeSoftness], 0.001, 0.5), 0.5, 1.0 - blm);
    float mask = smoothstep(maskNoise - soft, maskNoise + soft, coverage);

    float3 soil = straight(soilColor);
    float soilAlpha = float(soilColor.a);
    float grit = mix(0.5, vnoise(g / 0.5 + 2.0), bandLimit(0.5, fp));
    float clod = mix(0.5, fbm3(g / 4.0 + 5.5), bandLimit(4.0, fp));
    float pebble = mix(0.5, coneField(g, 1.6), bandLimit(1.6, fp));
    float damp = mix(0.5, fbm3(g / 30.0 + 9.0), bandLimit(30.0, fp));
    float3 soilCol = soil * (0.75 + 0.5 * clod) * (0.85 + 0.3 * grit) * (0.8 + 0.4 * pebble) * (0.85 + 0.3 * damp);
    soilCol *= 1.0 + u[U::grazeBrighten] * 0.4 * pow(graze, 2.5);
    // Dirt between sparse blades sits in their shadow.
    soilCol *= mix(1.0, 0.82, smoothstep(0.0, 0.6, coverage) * (1.0 - mask));

    float3 outRGB = mix(soilCol * soilAlpha, col, mask);
    float outA = mix(soilAlpha, 1.0, mask);

    // MARK: Atmosphere and grading

    float fogDistance = u[U::fogDistance];
    if (fogDistance > 0.0 && fogA > 0.0) {
        float f = (1.0 - exp(-gr.dist / fogDistance)) * fogA;
        outRGB = mix(outRGB, fog * outA, f);
    }
    float desat = u[U::desatDistance];
    float satScale = desat > 0.0 ? exp(-gr.dist / desat) : 1.0;

    float3 c = outRGB * u[U::exposure];
    float lum = luma(c);
    c = mix(float3(lum), c, u[U::saturation] * satScale);
    // Soft shoulder above 0.8 so highlights roll off instead of clipping.
    c = select(c, 0.8 + 0.2 * (1.0 - exp(-(c - 0.8) / 0.2)), c > 0.8);

    float vig = u[U::vignette];
    if (vig > 0.0) {
        float2 uv = position / max(size, float2(1.0)) * 2.0 - 1.0;
        c *= 1.0 - vig * smoothstep(0.5, 1.5, length(uv));
    }

    return half4(half3(clamp(c, 0.0, 1.0)), half(outA));
}
