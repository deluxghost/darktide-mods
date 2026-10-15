Texture2D<float4> outline_mask : register(t0);
cbuffer OutlineOptions : register(b1)
{
    // Supplied through the existing, otherwise unused legacy outline color parameter.
    float3 outline_options : packoffset(c7);
};

static const float EmptyDepth = 4096.0;
static const uint DepthBits = 0xfffff000;
// The 23-bit target ID uses four bits in each RGB channel and eleven in alpha.
static const uint4 IdentityBits = uint4(0xf00, 0xf00, 0xf00, 0xffe);
static const float NativeColorGain = 2.0;
static const float DiagonalCoverage = 1.0 - (sqrt(2.0) - 1.0) / 0.75;

bool is_edge(float4 center, float4 neighbor)
{
    if (neighbor.a >= EmptyDepth) return true;
    return (asuint(center.a) & DepthBits) < (asuint(neighbor.a) & DepthBits)
        && any((asuint(center) & IdentityBits) != (asuint(neighbor) & IdentityBits));
}

float4 ps_main(float4 position : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target0
{
    uint width, height;
    outline_mask.GetDimensions(width, height);
    int2 pixel = int2(texcoord * float2(width, height));
    float4 center = outline_mask.Load(int3(pixel, 0));
    if (center.a >= EmptyDepth) return 0.0;
    bool axial = is_edge(center, outline_mask.Load(int3(pixel + int2(-1, 0), 0)))
              || is_edge(center, outline_mask.Load(int3(pixel + int2(1, 0), 0)))
              || is_edge(center, outline_mask.Load(int3(pixel + int2(0, -1), 0)))
              || is_edge(center, outline_mask.Load(int3(pixel + int2(0, 1), 0)));
    bool diagonal = is_edge(center, outline_mask.Load(int3(pixel + int2(-1, -1), 0)))
                 || is_edge(center, outline_mask.Load(int3(pixel + int2(1, -1), 0)))
                 || is_edge(center, outline_mask.Load(int3(pixel + int2(-1, 1), 0)))
                 || is_edge(center, outline_mask.Load(int3(pixel + int2(1, 1), 0)));
    float coverage = axial ? 1.0 : (diagonal ? DiagonalCoverage : 0.0);
    bool occluded = (asuint(center.a) & 1) != 0;
    float visibility = occluded ? 1.0 - saturate(outline_options.y) : 1.0;
    float3 rgb = (asuint(center.rgb) & 255) / 255.0;
    float opacity = coverage * visibility;
    return float4(rgb * NativeColorGain * opacity, outline_options.x != 0.0 ? opacity : 0.0);
}
