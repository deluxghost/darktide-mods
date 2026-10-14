Texture2D<float4> outline_mask : register(t0);
float4 ps_main(float4 position : SV_Position, float2 texcoord : TEXCOORD0) : SV_Target0
{
    uint width, height;
    outline_mask.GetDimensions(width, height);
    int2 pixel = int2(texcoord * float2(width, height));
    float4 center = outline_mask.Load(int3(pixel, 0));
    if (center.a <= 0.0) return 0.0;
    // Coverage is zero beyond 1.75 pixels: only the eight immediate neighbors matter.
    bool axial = outline_mask.Load(int3(pixel + int2(-1, 0), 0)).a <= 0.0
              || outline_mask.Load(int3(pixel + int2(1, 0), 0)).a <= 0.0
              || outline_mask.Load(int3(pixel + int2(0, -1), 0)).a <= 0.0
              || outline_mask.Load(int3(pixel + int2(0, 1), 0)).a <= 0.0;
    bool diagonal = outline_mask.Load(int3(pixel + int2(-1, -1), 0)).a <= 0.0
                 || outline_mask.Load(int3(pixel + int2(1, -1), 0)).a <= 0.0
                 || outline_mask.Load(int3(pixel + int2(-1, 1), 0)).a <= 0.0
                 || outline_mask.Load(int3(pixel + int2(1, 1), 0)).a <= 0.0;
    float coverage = axial ? 1.0 : (diagonal ? (1.0 - (sqrt(2.0) - 1.0) / 0.75) : 0.0);
    float alpha = coverage * center.a;
    // Separate hue from material intensity without changing silhouette coverage.
    float peak = max(center.r, max(center.g, center.b));
    float3 color = peak > 0.0 ? center.rgb / peak : center.rgb;
    return float4(color * alpha, alpha);
}
