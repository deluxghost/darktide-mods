Texture2D<float4> outline_mask : register(t0);
cbuffer OutlineOptions : register(b1)
{
    // Supplied through the existing, otherwise unused legacy outline color parameter.
    float3 outline_options : packoffset(c7);
};

static const float EmptyDepth = 4096.0;
static const uint DepthBits = 0xfffff000;
// The 22-bit target ID leaves one alpha payload bit for component depth edges.
static const uint4 IdentityBits = uint4(0xf00, 0xf00, 0xf00, 0x7fe);
static const uint ComponentEdges = 0x800;
static const float NativeDepthEdgeRange = 0.75;
static const int ComponentSupportPixels = 3;
static const float NativeColorGain = 2.0;
static const float DiagonalCoverage = 1.0 - (sqrt(2.0) - 1.0) / 0.75;

float edge_coverage(float4 center, float4 neighbor, int2 opposite_pixel, bool components)
{
    if (neighbor.a >= EmptyDepth) return 1.0;
    uint center_depth = asuint(center.a) & DepthBits;
    uint neighbor_depth = asuint(neighbor.a) & DepthBits;
    if (center_depth >= neighbor_depth) return 0.0;
    if (any((asuint(center) & IdentityBits) != (asuint(neighbor) & IdentityBits))) return 1.0;
    if (!components || (asuint(center.a) & ComponentEdges) == 0) return 0.0;
    // Thin ridges have a depth drop on both sides; component boundaries have only one.
    float4 opposite = outline_mask.Load(int3(opposite_pixel, 0));
    float opposite_depth = asfloat(asuint(opposite.a) & DepthBits);
    float step = asfloat(neighbor_depth) - max(asfloat(center_depth), opposite_depth);
    return smoothstep(0.0, NativeDepthEdgeRange, step);
}

float4 ps_main(float4 position : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target0
{
    uint width, height;
    outline_mask.GetDimensions(width, height);
    int2 pixel = int2(texcoord * float2(width, height));
    float4 center = outline_mask.Load(int3(pixel, 0));
    if (center.a >= EmptyDepth) return 0.0;
    float4 left = outline_mask.Load(int3(pixel + int2(-1, 0), 0));
    float4 right = outline_mask.Load(int3(pixel + int2(1, 0), 0));
    float4 up = outline_mask.Load(int3(pixel + int2(0, -1), 0));
    float4 down = outline_mask.Load(int3(pixel + int2(0, 1), 0));
    float4 top_left = outline_mask.Load(int3(pixel + int2(-1, -1), 0));
    float4 top_right = outline_mask.Load(int3(pixel + int2(1, -1), 0));
    float4 bottom_left = outline_mask.Load(int3(pixel + int2(-1, 1), 0));
    float4 bottom_right = outline_mask.Load(int3(pixel + int2(1, 1), 0));
    float axial = max(max(edge_coverage(center, left, pixel + int2(ComponentSupportPixels, 0), true),
                          edge_coverage(center, right, pixel + int2(-ComponentSupportPixels, 0), true)),
                      max(edge_coverage(center, up, pixel + int2(0, ComponentSupportPixels), true),
                          edge_coverage(center, down, pixel + int2(0, -ComponentSupportPixels), true)));
    float diagonal = max(max(edge_coverage(center, top_left, pixel, false),
                             edge_coverage(center, bottom_right, pixel, false)),
                         max(edge_coverage(center, top_right, pixel, false),
                             edge_coverage(center, bottom_left, pixel, false)));
    float coverage = max(axial, diagonal * DiagonalCoverage);
    bool occluded = (asuint(center.a) & 1) != 0;
    float visibility = occluded ? 1.0 - saturate(outline_options.y) : 1.0;
    float3 rgb = (asuint(center.rgb) & 255) / 255.0;
    float opacity = coverage * visibility;
    return float4(rgb * NativeColorGain * opacity, outline_options.x != 0.0 ? opacity : 0.0);
}
