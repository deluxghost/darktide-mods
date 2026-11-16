#ifdef GOO_LAYERS
// Counter, overflow, dimensions, per-pixel heads, then four-word linked fragments.
Buffer<uint4> outline_layers : register(t0);
uint layer_word(uint index)
{
    return outline_layers.Load(index / 4)[index % 4];
}
uint2 layer_dimensions()
{
    return outline_layers.Load(0).zw;
}
#else
Texture2D<float4> outline_mask : register(t0);
#endif
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
struct Neighborhood
{
    float4 center, left, right, up, down;
    float4 top_left, top_right, bottom_left, bottom_right;
};

bool same_target(float4 a, float4 b)
{
#ifdef GOO_LAYERS
    // Layered neighborhoods query one target ID, so every nonempty sample belongs to it.
    return true;
#else
    return all((asuint(a) & IdentityBits) == (asuint(b) & IdentityBits));
#endif
}

uint target_id(float4 value)
{
    uint4 bits = asuint(value);
    return ((bits.x >> 8) & 15) | ((bits.y >> 4) & 240)
        | (bits.z & 3840) | ((bits.w & 2046) << 11);
}

#ifdef GOO_LAYERS
uint layer_head(int2 pixel)
{
    if (any(pixel < 0) || any(pixel >= int2(layer_dimensions()))) return 0;
    return layer_word(4 + pixel.y * uint(layer_dimensions().x) + pixel.x);
}

uint4 layer_node(uint index)
{
    uint start = (4 + uint(layer_dimensions().x) * uint(layer_dimensions().y) + 3) / 4;
    return outline_layers.Load(start + index - 1);
}

uint node_identity(uint4 node)
{
    return (node.y & 4095) | ((node.w >> 2) << 12);
}

float4 decode_node(uint4 node)
{
    uint depth = node.y & DepthBits;
    uint identity = node_identity(node);
    uint4 payload = uint4(((identity & 15) << 8) | (node.z & 255),
        (((identity >> 4) & 15) << 8) | ((node.z >> 8) & 255),
        (((identity >> 8) & 15) << 8) | ((node.z >> 16) & 255),
        ((identity >> 12) << 1) | (node.w & 1) | ((node.w & 2) << 10));
    return asfloat(depth | payload);
}

uint find_target(int2 pixel, uint identity, bool nearest = true)
{
    uint best = 0, depth = asuint(EmptyDepth);
    for (uint index = layer_head(pixel); index != 0; )
    {
        uint4 node = layer_node(index);
        uint candidate_depth = node.y & DepthBits;
        if (node_identity(node) == identity
            && (candidate_depth < depth || (candidate_depth == depth && index < best)))
        {
            if (!nearest) return index;
            best = index;
            depth = candidate_depth;
        }
        index = node.x;
    }
    return best;
}

float4 read_mask(int2 pixel, uint identity, bool components = false)
{
    uint index = find_target(pixel, identity, components);
    if (index == 0) return EmptyDepth.xxxx;
    if (!components) return 0.0;
    uint4 node = layer_node(index);
    return float4(0.0, 0.0, 0.0, asfloat((node.y & DepthBits) | ((node.w & 2) << 10)));
}
#else
float4 read_mask(int2 pixel, uint identity, bool components = false)
{
    return outline_mask.Load(int3(pixel, 0));
}
#endif

Neighborhood neighborhood(int2 pixel, uint identity, float4 center)
{
    Neighborhood n;
    n.center = center;
    bool components = (asuint(center.a) & ComponentEdges) != 0;
    n.left = read_mask(pixel + int2(-1, 0), identity, components);
    n.right = read_mask(pixel + int2(1, 0), identity, components);
    n.up = read_mask(pixel + int2(0, -1), identity, components);
    n.down = read_mask(pixel + int2(0, 1), identity, components);
    n.top_left = read_mask(pixel + int2(-1, -1), identity, components);
    n.top_right = read_mask(pixel + int2(1, -1), identity, components);
    n.bottom_left = read_mask(pixel + int2(-1, 1), identity, components);
    n.bottom_right = read_mask(pixel + int2(1, 1), identity, components);
    return n;
}

float edge_coverage(float4 center, float4 neighbor, int2 opposite_pixel, bool components, uint identity)
{
    if (neighbor.a >= EmptyDepth) return 1.0;
    uint center_depth = asuint(center.a) & DepthBits;
    uint neighbor_depth = asuint(neighbor.a) & DepthBits;
    if (center_depth >= neighbor_depth) return 0.0;
    if (!same_target(center, neighbor)) return 1.0;
    if (!components || (asuint(center.a) & ComponentEdges) == 0) return 0.0;
    // Thin ridges have a depth drop on both sides; component boundaries have only one.
    float4 opposite = read_mask(opposite_pixel, identity, true);
    float opposite_depth = asfloat(asuint(opposite.a) & DepthBits);
    float step = asfloat(neighbor_depth) - max(asfloat(center_depth), opposite_depth);
    return smoothstep(0.0, NativeDepthEdgeRange, step);
}

float4 shade_outline(int2 pixel, float4 target, Neighborhood n, bool hidden)
{
    float4 center = n.center, left = n.left, right = n.right, up = n.up, down = n.down;
    float4 top_left = n.top_left, top_right = n.top_right;
    float4 bottom_left = n.bottom_left, bottom_right = n.bottom_right;
    uint identity = target_id(target);
    float axial = max(max(edge_coverage(center, left, pixel + int2(ComponentSupportPixels, 0), true, identity),
                          edge_coverage(center, right, pixel + int2(-ComponentSupportPixels, 0), true, identity)),
                      max(edge_coverage(center, up, pixel + int2(0, ComponentSupportPixels), true, identity),
                          edge_coverage(center, down, pixel + int2(0, -ComponentSupportPixels), true, identity)));
    float diagonal = max(max(edge_coverage(center, top_left, pixel, false, identity),
                             edge_coverage(center, bottom_right, pixel, false, identity)),
                         max(edge_coverage(center, top_right, pixel, false, identity),
                             edge_coverage(center, bottom_left, pixel, false, identity)));
    float coverage = max(axial, diagonal * DiagonalCoverage);
    bool occluded = hidden || (asuint(target.a) & 1) != 0;
    float visibility = occluded ? 1.0 - saturate(outline_options.y) : 1.0;
    float3 rgb = (asuint(target.rgb) & 255) / 255.0;
    float base_opacity = uint(outline_options.z) / 100.0;
    float opacity = coverage * visibility * base_opacity;
    return float4(rgb * NativeColorGain * opacity, outline_options.x != 0.0 ? opacity : 0.0);
}

#ifdef GOO_LAYERS
float4 shade_layer(int2 pixel, uint index, bool hidden)
{
    float4 target = decode_node(layer_node(index));
    return shade_outline(pixel, target, neighborhood(pixel, target_id(target), target), hidden);
}
#endif

float4 ps_main(float4 position : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target0
{
#ifdef GOO_LAYERS
    if (any(layer_dimensions() == 0)) return 0.0;
    int2 pixel = int2(texcoord * layer_dimensions());
    uint words;
    outline_layers.GetDimensions(words);
    if (outline_layers.Load(0).y != 0 || words * 4 <= 4 + uint(layer_dimensions().x) * uint(layer_dimensions().y)) return 0.0;
    uint head = layer_head(pixel);
    uint nearest = 0, nearest_depth = asuint(EmptyDepth);
    for (uint index = head; index != 0; )
    {
        uint4 node = layer_node(index);
        if ((node.y & DepthBits) < nearest_depth)
        {
            nearest = node_identity(node);
            nearest_depth = node.y & DepthBits;
        }
        index = node.x;
    }
    // Resolve the front target once; its own overlapping meshes need no further searches.
    if (head != 0)
    {
        float4 front = shade_layer(pixel, find_target(pixel, nearest), false);
        if (any(front != 0.0)) return front;
    }
    float4 result = 0.0;
    uint result_depth = asuint(EmptyDepth);
    for (uint index = head; index != 0; )
    {
        uint4 node = layer_node(index);
        uint identity = node_identity(node);
        uint depth = node.y & DepthBits;
        if (identity != nearest && depth < result_depth && find_target(pixel, identity) == index)
        {
            float4 color = shade_layer(pixel, index, nearest_depth < depth);
            if (any(color != 0.0))
            {
                result = color;
                result_depth = depth;
            }
        }
        index = node.x;
    }
    return result;
#else
    uint width, height;
    outline_mask.GetDimensions(width, height);
    int2 pixel = int2(texcoord * float2(width, height));
    float4 center = read_mask(pixel, 0);
    if (center.a >= EmptyDepth) return 0.0;
    return shade_outline(pixel, center, neighborhood(pixel, 0, center), false);
#endif
}
