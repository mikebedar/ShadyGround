//
//  GrassShader.metal
//  ShadyGround
//
//  Realistic turf rendered from a multichannel control map, in perspective.
//
//  The layer passed to this effect *is* the control map, a top-down plan of the ground:
//    R, G : blade lean direction, flow-map encoded (0.5, 0.5 = upright)
//    B    : blade height (0 = scalped, 1 = long)
//    A    : coverage (0 = bare soil, 1 = full turf)
//
//  Coverage lives in alpha on purpose: SwiftUI hands the layer over premultiplied,
//  and scaling the other channels by coverage loses nothing where there is no grass.
//
//  All of the shading lives in GrassCore.h so the Metal surface renderer can draw the
//  identical turf; this file is only the SwiftUI layer-effect entry point.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include "GrassCore.h"
using namespace metal;

[[ stitchable ]] half4 grass(float2 position,
                             SwiftUI::Layer layer,
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
    return grassShade(position, layer, size, u, uCount,
                      baseColor, tipColor, dryColor, soilColor, sheenColor, fogColor);
}
