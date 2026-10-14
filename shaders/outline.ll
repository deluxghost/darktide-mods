;
; Note: shader requires additional functionality:
;       64 UAV slots
;       Wave level operations
;
;
; Input signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; SV_Position              0   xyzw        0      POS   float   xy
; TEXCOORD                15   xyz         1     NONE   float   xyz
; CUSTOM                   3      w        1     NONE   float      w
; CUSTOM                   0   xy          2     NONE   float   xy
; CUSTOM                   1     zw        2     NONE   float     zw
; CUSTOM                   2   xyz         3     NONE   float     z
; CUSTOM                   4   xyz         4     NONE   float
;
;
; Output signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; SV_Target                0   xyzw        0   TARGET   float   xyzw
;
; shader hash: a238b329f868802e7167b843000bc997
;
; Pipeline Runtime Information:
;
; Pixel Shader
; DepthOutput=0
; SampleFrequency=0
;
;
; Input signature:
;
; Name                 Index             InterpMode DynIdx
; -------------------- ----- ---------------------- ------
; SV_Position              0          noperspective
; TEXCOORD                15                 linear
; CUSTOM                   0                 linear
; CUSTOM                   1                 linear
; CUSTOM                   2                 linear
; CUSTOM                   3                 linear
; CUSTOM                   4                 linear
;
; Output signature:
;
; Name                 Index             InterpMode DynIdx
; -------------------- ----- ---------------------- ------
; SV_Target                0
;
; Buffer Definitions:
;
; cbuffer global_viewport
; {
;
;   struct hostlayout.global_viewport
;   {
;
;       float3 camera_unprojection;                   ; Offset:    0
;       float3 camera_pos;                            ; Offset:   16
;       column_major float4x4 camera_view;            ; Offset:   32
;       column_major float4x4 camera_inv_view;        ; Offset:   96
;       column_major float4x4 camera_world;           ; Offset:  160
;       column_major float4x4 camera_last_world;      ; Offset:  224
;       column_major float4x4 camera_last_view;       ; Offset:  288
;       column_major float4x4 camera_last_inv_view;   ; Offset:  352
;       column_major float4x4 camera_projection[2];   ; Offset:  416
;       column_major float4x4 camera_inv_projection[2];; Offset:  544
;       column_major float4x4 camera_last_projection[2];; Offset:  672
;       column_major float4x4 camera_last_inv_projection[2];; Offset:  800
;       column_major float4x4 camera_last_view_projection[2];; Offset:  928
;       column_major float4x4 camera_last_inv_view_projection[2];; Offset: 1056
;       column_major float4x4 camera_view_projection[2];; Offset: 1184
;       column_major float4x4 camera_inv_view_projection[2];; Offset: 1312
;       float time;                                   ; Offset: 1440
;       float delta_time;                             ; Offset: 1444
;       float2 streamer_write_feedback_threshold;     ; Offset: 1448
;       float2 sampler_lod_bias;                      ; Offset: 1456
;       float frame_number;                           ; Offset: 1464
;       float2 back_buffer_size;                      ; Offset: 1472
;       float2 output_rt_size;                        ; Offset: 1480
;       column_major float4x4 hdr_content_to_monitor_rec;; Offset: 1488
;       float taa_enabled;                            ; Offset: 1552
;       float jitter_enabled;                         ; Offset: 1556
;       float upscaling_enabled;                      ; Offset: 1560
;       float debug_rendering;                        ; Offset: 1564
;       float gamma;                                  ; Offset: 1568
;       float lens_quality_color_fringe_enabled;      ; Offset: 1572
;       float lens_quality_distortion_enabled;        ; Offset: 1576
;       float volumetric_reprojection_amount;         ; Offset: 1580
;       float volumetric_volumes_enabled;             ; Offset: 1584
;       float sun_shadows;                            ; Offset: 1588
;       float capture_cubemap;                        ; Offset: 1592
;       float capture_ddgi;                           ; Offset: 1596
;       float hair_wrapped_diffuse;                   ; Offset: 1600
;       float4 viewport;                              ; Offset: 1616
;       float is_editor;                              ; Offset: 1632
;       float2 mouse_uv;                              ; Offset: 1636
;       float rt_reflections_enabled;                 ; Offset: 1644
;       float rt_particle_reflections_enabled;        ; Offset: 1648
;       float rt_relax_denoiser_enabled;              ; Offset: 1652
;       float dlss_rr_enabled;                        ; Offset: 1656
;       float gtao_enabled;                           ; Offset: 1660
;       float cacao_enabled;                          ; Offset: 1664
;       float rt_mixed_reflections;                   ; Offset: 1668
;       float rt_shadow_ray_multiplier;               ; Offset: 1672
;       float rtxgi_enabled;                          ; Offset: 1676
;       float baked_ddgi;                             ; Offset: 1680
;       float dxr;                                    ; Offset: 1684
;       float rt_checkerboard_reflections;            ; Offset: 1688
;       float3 camera_near_far;                       ; Offset: 1696
;       float direct_diffuse_enabled;                 ; Offset: 1708
;       float direct_specular_enabled;                ; Offset: 1712
;       float indirect_diffuse_enabled;               ; Offset: 1716
;       float indirect_specular_enabled;              ; Offset: 1720
;       float occlusion_debug_opacity;                ; Offset: 1724
;       float occlusion_debug_far;                    ; Offset: 1728
;       float occlusion_debug_near;                   ; Offset: 1732
;       float occluder_debug_opacity;                 ; Offset: 1736
;       float occluder_debug_far;                     ; Offset: 1740
;       float hdr_paper_white_nits;                   ; Offset: 1744
;       float debug_hdr_compare;                      ; Offset: 1748
;       float reverse_z;                              ; Offset: 1752
;       float terrain_displacement_min_distance;      ; Offset: 1756
;       float terrain_displacement_max_distance;      ; Offset: 1760
;       float terrain_tesselation_min_distance;       ; Offset: 1764
;       float terrain_tesselation_max_distance;       ; Offset: 1768
;       float fsr_rr_enabled;                         ; Offset: 1772
;       float fsr_rr_mirror_passthrough_depth_enabled;; Offset: 1776
;       float fsr_rr_mirror_passthrough_roughness_enabled;; Offset: 1780
;       float fsr_rr_mirror_passthrough_threshold;    ; Offset: 1784
;
;   } global_viewport;                                ; Offset:    0 Size:  1788
;
; }
;
; cbuffer c_per_object
; {
;
;   struct hostlayout.c_per_object
;   {
;
;       uint __BINDLESS_SAMPLER_scanline_vertical;    ; Offset:    0
;       uint2 __BINDLESS_TEX2D_scanline_vertical;     ; Offset:    4
;       uint2 __BINDLESS_MINLOD_scanline_vertical;    ; Offset:   16
;       uint2 __BINDLESS_TEX2D_scanline_horizontal;   ; Offset:   24
;       uint2 __BINDLESS_MINLOD_scanline_horizontal;  ; Offset:   32
;       column_major float4x4 view_proj;              ; Offset:   48
;       column_major float4x4 world_view_proj;        ; Offset:  112
;       column_major float4x4 world;                  ; Offset:  176
;       column_major float4x4 last_world;             ; Offset:  240
;       float4 dev_wireframe_color;                   ; Offset:  304
;       float3 outline_color;                         ; Offset:  320
;       float culled_outline_opacity;                 ; Offset:  332
;       float outline_culling;                        ; Offset:  336
;       float distortion;                             ; Offset:  340
;       float outline_thickness;                      ; Offset:  344
;
;   } c_per_object;                                   ; Offset:    0 Size:   348
;
; }
;
;
; Resource Bindings:
;
; Name                                 Type  Format         Dim      ID      HLSL Bind  Count
; ------------------------------ ---------- ------- ----------- ------- -------------- ------
; global_viewport                   cbuffer      NA          NA     CB0            cb0     1
; c_per_object                      cbuffer      NA          NA     CB1            cb1     1
; global_samplers                   sampler      NA          NA      S0      s0,space2unbounded
; static_minlod_sampler             sampler      NA          NA      S1     s0,space31     1
; __samp_linear_depth               sampler      NA          NA      S2             s0     1
; __samp_custom_linear_depth        sampler      NA          NA      S3             s1     1
; global_texture2D                  texture     f32          2d      T0      t0,space2unbounded
; __tex_linear_depth                texture     f32          2d      T1             t0     1
; __tex_custom_linear_depth         texture     f32          2d      T2             t1     1
; global_feedback_buffers               UAV     u32         buf      U0     u0,space31unbounded
;
;
; ViewId state:
;
; Number of inputs: 19, outputs: 4
; Outputs dependent on ViewId: {  }
; Inputs contributing to computation of Outputs:
;   output 0 depends on inputs: { 0, 1, 4, 5, 6, 7, 8, 9, 10, 11, 14 }
;   output 1 depends on inputs: { 0, 1, 4, 5, 6, 7, 8, 9, 10, 11, 14 }
;   output 2 depends on inputs: { 0, 1, 4, 5, 6, 7, 8, 9, 10, 11, 14 }
;
target datalayout = "e-m:e-p:32:32-i1:32-i8:32-i16:32-i32:32-i64:64-f16:32-f32:32-f64:64-n8:16:32:64"
target triple = "dxil-ms-dx"

%dx.types.Handle = type { i8* }
%dx.types.CBufRet.f32 = type { float, float, float, float }
%dx.types.CBufRet.i32 = type { i32, i32, i32, i32 }
%dx.types.ResRet.f32 = type { float, float, float, float, i32 }
%"class.Texture2D<vector<float, 4> >" = type { <4 x float>, %"class.Texture2D<vector<float, 4> >::mips_type" }
%"class.Texture2D<vector<float, 4> >::mips_type" = type { i32 }
%"class.RWBuffer<unsigned int>" = type { i32 }
%hostlayout.global_viewport = type { <3 x float>, <3 x float>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [2 x [4 x <4 x float>]], [2 x [4 x <4 x float>]], [2 x [4 x <4 x float>]], [2 x [4 x <4 x float>]], [2 x [4 x <4 x float>]], [2 x [4 x <4 x float>]], [2 x [4 x <4 x float>]], [2 x [4 x <4 x float>]], float, float, <2 x float>, <2 x float>, float, <2 x float>, <2 x float>, [4 x <4 x float>], float, float, float, float, float, float, float, float, float, float, float, float, float, <4 x float>, float, <2 x float>, float, float, float, float, float, float, float, float, float, float, float, float, <3 x float>, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float }
%hostlayout.c_per_object = type { i32, <2 x i32>, <2 x i32>, <2 x i32>, <2 x i32>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <3 x float>, float, float, float, float }
%struct.SamplerState = type { i32 }

define void @ps_main() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 2, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 1, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 3, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 2, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 1, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %6 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %7 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %8 = call float @dx.op.loadInput.f32(i32 4, i32 5, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %9 = call float @dx.op.loadInput.f32(i32 4, i32 4, i32 0, i8 2, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %10 = call float @dx.op.loadInput.f32(i32 4, i32 3, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %11 = call float @dx.op.loadInput.f32(i32 4, i32 3, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %12 = call float @dx.op.loadInput.f32(i32 4, i32 2, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %13 = call float @dx.op.loadInput.f32(i32 4, i32 2, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %14 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %15 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %16 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 2, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %17 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %18 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %19 = fptoui float %17 to i32
  %20 = fptoui float %18 to i32
  %21 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 10)  ; CBufferLoadLegacy(handle,regIndex)
  %22 = extractvalue %dx.types.CBufRet.f32 %21, 3
  %23 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 11)  ; CBufferLoadLegacy(handle,regIndex)
  %24 = extractvalue %dx.types.CBufRet.f32 %23, 3
  %25 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 12)  ; CBufferLoadLegacy(handle,regIndex)
  %26 = extractvalue %dx.types.CBufRet.f32 %25, 3
  %27 = fsub fast float %22, %14
  %28 = fsub fast float %24, %15
  %29 = fsub fast float %26, %16
  %30 = extractvalue %dx.types.CBufRet.f32 %21, 1
  %31 = extractvalue %dx.types.CBufRet.f32 %23, 1
  %32 = extractvalue %dx.types.CBufRet.f32 %25, 1
  %33 = fsub fast float -0.000000e+00, %27
  %34 = fsub fast float -0.000000e+00, %28
  %35 = fsub fast float -0.000000e+00, %29
  %36 = call float @dx.op.dot3.f32(i32 55, float %33, float %34, float %35, float %30, float %31, float %32)  ; Dot3(ax,ay,az,bx,by,bz)
  %37 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 92)  ; CBufferLoadLegacy(handle,regIndex)
  %38 = extractvalue %dx.types.CBufRet.f32 %37, 2
  %39 = extractvalue %dx.types.CBufRet.f32 %37, 3
  %40 = fdiv fast float %17, %38
  %41 = fdiv fast float %18, %39
  %42 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %43 = extractvalue %dx.types.CBufRet.i32 %42, 0
  %44 = add i32 %43, 0
  %45 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 0, i32 %44, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %46 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %47 = extractvalue %dx.types.CBufRet.i32 %46, 1
  %48 = add i32 %47, 0
  %49 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %48, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %50 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %51 = extractvalue %dx.types.CBufRet.i32 %50, 0
  %52 = add i32 %51, 0
  %53 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %52, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %54 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %55 = extractvalue %dx.types.CBufRet.i32 %54, 1
  %56 = lshr i32 %55, 16
  %57 = extractvalue %dx.types.CBufRet.i32 %54, 0
  %58 = add i32 %57, 1
  %59 = add i32 %58, 0
  %60 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 %59, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %61 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %62 = extractvalue %dx.types.CBufRet.i32 %61, 2
  %63 = add i32 %62, 0
  %64 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %63, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %65 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %66 = extractvalue %dx.types.CBufRet.i32 %65, 0
  %67 = add i32 %66, 0
  %68 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %67, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %69 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %70 = extractvalue %dx.types.CBufRet.i32 %69, 1
  %71 = lshr i32 %70, 16
  %72 = and i32 %70, 65535
  %73 = extractvalue %dx.types.CBufRet.i32 %69, 0
  %74 = add i32 %73, 1
  %75 = add i32 %74, 0
  %76 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 %75, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %77 = call float @dx.op.unary.f32(i32 27, float %12)  ; Round_ni(value)
  %78 = call float @dx.op.unary.f32(i32 27, float %13)  ; Round_ni(value)
  %79 = fsub fast float %12, %77
  %80 = fsub fast float %13, %78
  %81 = fadd fast float %77, 1.000000e+00
  %82 = fadd fast float %78, 1.000000e+00
  %83 = fmul fast float %77, 0x3F8CD85680000000
  %84 = fmul fast float %78, 0x3F8CD85680000000
  %85 = fmul fast float %81, 0x3F8CD85680000000
  %86 = fmul fast float %82, 0x3F8CD85680000000
  %87 = call float @dx.op.unary.f32(i32 27, float %83)  ; Round_ni(value)
  %88 = call float @dx.op.unary.f32(i32 27, float %84)  ; Round_ni(value)
  %89 = call float @dx.op.unary.f32(i32 27, float %85)  ; Round_ni(value)
  %90 = call float @dx.op.unary.f32(i32 27, float %86)  ; Round_ni(value)
  %91 = fmul fast float %87, 7.100000e+01
  %92 = fmul fast float %88, 7.100000e+01
  %93 = fmul fast float %89, 7.100000e+01
  %94 = fmul fast float %90, 7.100000e+01
  %95 = fsub fast float %77, %91
  %96 = fsub fast float %78, %92
  %97 = fsub fast float %81, %93
  %98 = fsub fast float %82, %94
  %99 = fadd fast float %95, 2.600000e+01
  %100 = fadd fast float %96, 1.610000e+02
  %101 = fadd fast float %97, 2.600000e+01
  %102 = fadd fast float %98, 1.610000e+02
  %103 = fmul fast float %99, %99
  %104 = fmul fast float %100, %100
  %105 = fmul fast float %101, %101
  %106 = fmul fast float %102, %102
  %107 = fmul fast float %103, 0x3F5139C900000000
  %108 = fmul fast float %107, %104
  %109 = fmul fast float %104, 0x3F5139C900000000
  %110 = fmul fast float %109, %105
  %111 = fmul fast float %107, %106
  %112 = fmul fast float %105, 0x3F5139C900000000
  %113 = fmul fast float %112, %106
  %114 = call float @dx.op.unary.f32(i32 22, float %108)  ; Frc(value)
  %115 = call float @dx.op.unary.f32(i32 22, float %110)  ; Frc(value)
  %116 = call float @dx.op.unary.f32(i32 22, float %111)  ; Frc(value)
  %117 = call float @dx.op.unary.f32(i32 22, float %113)  ; Frc(value)
  %118 = fmul fast float %79, %79
  %119 = fmul fast float %80, %80
  %120 = fmul fast float %118, %79
  %121 = fmul fast float %119, %80
  %122 = fmul fast float %79, 6.000000e+00
  %123 = fmul fast float %80, 6.000000e+00
  %124 = fadd fast float %122, -1.500000e+01
  %125 = fadd fast float %123, -1.500000e+01
  %126 = fmul fast float %124, %79
  %127 = fmul fast float %125, %80
  %128 = fadd fast float %126, 1.000000e+01
  %129 = fadd fast float %127, 1.000000e+01
  %130 = fmul fast float %120, %128
  %131 = fmul fast float %121, %129
  %132 = fsub fast float 1.000000e+00, %130
  %133 = fsub fast float 1.000000e+00, %131
  %134 = fmul fast float %133, %132
  %135 = fmul fast float %133, %130
  %136 = fmul fast float %132, %131
  %137 = fmul fast float %131, %130
  %138 = call float @dx.op.dot4.f32(i32 56, float %114, float %115, float %116, float %117, float %134, float %135, float %136, float %137)  ; Dot4(ax,ay,az,aw,bx,by,bz,bw)
  %139 = fmul fast float %138, 0xC007333320000000
  %140 = fadd fast float %139, 0x3FF19999A0000000
  %141 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %40, float %41, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %142 = extractvalue %dx.types.ResRet.f32 %141, 0
  %143 = bitcast float %142 to i32
  %144 = and i32 %143, 2147483647
  %145 = bitcast i32 %144 to float
  %146 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %2, %dx.types.Handle %4, float %40, float %41, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %147 = extractvalue %dx.types.ResRet.f32 %146, 0
  %148 = bitcast float %147 to i32
  %149 = and i32 %148, 2147483647
  %150 = bitcast i32 %149 to float
  %151 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 20)  ; CBufferLoadLegacy(handle,regIndex)
  %152 = extractvalue %dx.types.CBufRet.f32 %151, 3
  %153 = fcmp fast ogt float %150, %145
  %154 = select i1 %153, float 1.000000e+00, float %152
  %155 = fsub fast float %145, %150
  %156 = call float @dx.op.unary.f32(i32 7, float %155)  ; Saturate(value)
  %157 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 21)  ; CBufferLoadLegacy(handle,regIndex)
  %158 = extractvalue %dx.types.CBufRet.f32 %157, 0
  %159 = fsub fast float %154, %156
  %160 = fmul fast float %159, %158
  %161 = fadd fast float %158, 1.000000e+00
  %162 = call float @dx.op.unary.f32(i32 7, float %161)  ; Saturate(value)
  %163 = fadd fast float %156, -1.000000e+00
  %164 = fadd fast float %163, %160
  %165 = fmul fast float %164, %162
  %166 = fadd fast float %165, 1.000000e+00
  %167 = fadd fast float %145, -2.000000e+03
  %168 = call float @dx.op.unary.f32(i32 28, float %167)  ; Round_pi(value)
  %169 = call float @dx.op.unary.f32(i32 7, float %168)  ; Saturate(value)
  %170 = fsub fast float 1.000000e+00, %169
  %171 = extractvalue %dx.types.CBufRet.f32 %157, 2
  %172 = fmul fast float %171, 0x3FB99999A0000000
  %173 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 106)  ; CBufferLoadLegacy(handle,regIndex)
  %174 = extractvalue %dx.types.CBufRet.f32 %173, 0
  %175 = fadd fast float %36, 0xBFB99999A0000000
  %176 = fsub fast float %175, %174
  %177 = fmul fast float %176, 0x3FB9DBCC60000000
  %178 = call float @dx.op.unary.f32(i32 7, float %177)  ; Saturate(value)
  %179 = fsub fast float 0x3F589374C0000000, %172
  %180 = fmul fast float %179, %178
  %181 = fadd fast float %180, %172
  %182 = fsub fast float %40, %181
  %183 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %182, float %41, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %184 = extractvalue %dx.types.ResRet.f32 %183, 0
  %185 = bitcast float %184 to i32
  %186 = and i32 %185, 2147483647
  %187 = bitcast i32 %186 to float
  %188 = fsub fast float %187, %145
  %189 = fadd fast float %181, %40
  %190 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %189, float %41, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %191 = extractvalue %dx.types.ResRet.f32 %190, 0
  %192 = bitcast float %191 to i32
  %193 = and i32 %192, 2147483647
  %194 = bitcast i32 %193 to float
  %195 = fsub fast float %194, %145
  %196 = call float @dx.op.binary.f32(i32 35, float %195, float %188)  ; FMax(a,b)
  %197 = fsub fast float %41, %181
  %198 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %40, float %197, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %199 = extractvalue %dx.types.ResRet.f32 %198, 0
  %200 = bitcast float %199 to i32
  %201 = and i32 %200, 2147483647
  %202 = bitcast i32 %201 to float
  %203 = fsub fast float %202, %145
  %204 = fadd fast float %181, %41
  %205 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %40, float %204, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %206 = extractvalue %dx.types.ResRet.f32 %205, 0
  %207 = bitcast float %206 to i32
  %208 = and i32 %207, 2147483647
  %209 = bitcast i32 %208 to float
  %210 = fsub fast float %209, %145
  %211 = call float @dx.op.binary.f32(i32 35, float %210, float %203)  ; FMax(a,b)
  %212 = call float @dx.op.binary.f32(i32 35, float %211, float %196)  ; FMax(a,b)
  %213 = fmul fast float %212, 0x3FF5555560000000
  %214 = call float @dx.op.unary.f32(i32 7, float %213)  ; Saturate(value)
  %215 = fmul fast float %214, 2.000000e+00
  %216 = fsub fast float 3.000000e+00, %215
  %217 = fmul fast float %166, %170
  %218 = fmul fast float %214, %214
  %219 = fmul fast float %218, %217
  %220 = fmul fast float %219, %216
  %221 = fadd fast float %220, 0x3FC99999A0000000
  %222 = fmul fast float %221, %140
  %223 = extractvalue %dx.types.CBufRet.f32 %151, 0
  %224 = extractvalue %dx.types.CBufRet.f32 %151, 1
  %225 = extractvalue %dx.types.CBufRet.f32 %151, 2
  %226 = extractvalue %dx.types.CBufRet.f32 %157, 1
  %227 = fmul fast float %138, 0x3FC99999A0000000
  %228 = fmul fast float %227, %226
  %229 = fadd fast float %228, %10
  %230 = fadd fast float %228, %11
  %231 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %53, %dx.types.Handle %5, float %229, float %230, float undef, float undef, i32 0, i32 0, i32 undef, float undef)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %232 = extractvalue %dx.types.ResRet.f32 %231, 0
  %233 = fmul fast float %232, 3.200000e+01
  %234 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %49, %dx.types.Handle %45, float %229, float %230, float undef, float undef, i32 0, i32 0, i32 undef, float %233)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %235 = extractvalue %dx.types.ResRet.f32 %234, 0
  %236 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 91)  ; CBufferLoadLegacy(handle,regIndex)
  %237 = extractvalue %dx.types.CBufRet.f32 %236, 2
  %238 = fptoui float %237 to i32
  %239 = lshr i32 %238, 3
  %240 = xor i32 %238, %19
  %241 = xor i32 %239, %20
  %242 = or i32 %241, %240
  %243 = and i32 %242, 7
  %244 = icmp eq i32 %243, 0
  %245 = sext i1 %244 to i32
  %246 = call i32 @dx.op.quadOp.i32(i32 123, i32 %245, i8 0)  ; QuadOp(value,op)
  %247 = call i32 @dx.op.quadOp.i32(i32 123, i32 %245, i8 1)  ; QuadOp(value,op)
  %248 = call i32 @dx.op.quadOp.i32(i32 123, i32 %245, i8 2)  ; QuadOp(value,op)
  %249 = or i32 %246, %247
  %250 = or i32 %249, %248
  %251 = or i32 %250, %245
  %252 = trunc i32 %251 to i1
  br i1 %252, label %253, label %269

; <label>:253                                     ; preds = %0
  %254 = and i32 %55, 65535
  %255 = call float @dx.op.calculateLOD.f32(i32 81, %dx.types.Handle %49, %dx.types.Handle %45, float %229, float %230, float undef, i1 false)  ; CalculateLOD(handle,sampler,coord0,coord1,coord2,clamped)
  %256 = fmul fast float %255, 8.000000e+00
  %257 = fptoui float %256 to i32
  %258 = call float @dx.op.unary.f32(i32 22, float %229)  ; Frc(value)
  %259 = call float @dx.op.unary.f32(i32 22, float %230)  ; Frc(value)
  %260 = uitofp i32 %56 to float
  %261 = uitofp i32 %254 to float
  %262 = fmul fast float %258, %260
  %263 = fmul fast float %259, %261
  %264 = fptoui float %262 to i32
  %265 = fptoui float %263 to i32
  %266 = mul i32 %265, %56
  %267 = add i32 %266, %264
  %268 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %60, i32 6, i32 %267, i32 undef, i32 undef, i32 %257)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  br label %269

; <label>:269                                     ; preds = %253, %0
  %270 = call float @dx.op.unary.f32(i32 23, float %235)  ; Log(value)
  %271 = fmul fast float %270, 1.000000e+01
  %272 = call float @dx.op.unary.f32(i32 21, float %271)  ; Exp(value)
  %273 = fadd fast float %272, -5.000000e-01
  %274 = call float @dx.op.unary.f32(i32 7, float %273)  ; Saturate(value)
  %275 = fmul fast float %274, 1.250000e+00
  %276 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 90)  ; CBufferLoadLegacy(handle,regIndex)
  %277 = extractvalue %dx.types.CBufRet.f32 %276, 0
  %278 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 106)  ; CBufferLoadLegacy(handle,regIndex)
  %279 = extractvalue %dx.types.CBufRet.f32 %278, 0
  %280 = fadd fast float %36, -5.000000e+00
  %281 = fsub fast float %280, %279
  %282 = fmul fast float %281, 0x3FC99999A0000000
  %283 = call float @dx.op.unary.f32(i32 7, float %282)  ; Saturate(value)
  %284 = fmul fast float %283, 1.500000e+01
  %285 = call float @dx.op.unary.f32(i32 26, float %284)  ; Round_ne(value)
  %286 = fsub fast float 3.000000e+01, %285
  %287 = fmul fast float %286, %9
  %288 = fmul fast float %277, 0x3FD51EB860000000
  %289 = fmul fast float %277, 2.000000e+00
  %290 = fadd fast float %288, %9
  %291 = fadd fast float %287, %289
  %292 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %68, %dx.types.Handle %5, float %290, float %291, float undef, float undef, i32 0, i32 0, i32 undef, float undef)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %293 = extractvalue %dx.types.ResRet.f32 %292, 0
  %294 = fmul fast float %293, 3.200000e+01
  %295 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %64, %dx.types.Handle %45, float %290, float %291, float undef, float undef, i32 0, i32 0, i32 undef, float %294)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %296 = extractvalue %dx.types.ResRet.f32 %295, 0
  %297 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 91)  ; CBufferLoadLegacy(handle,regIndex)
  %298 = extractvalue %dx.types.CBufRet.f32 %297, 2
  %299 = fptoui float %298 to i32
  %300 = lshr i32 %299, 3
  %301 = xor i32 %299, %19
  %302 = xor i32 %300, %20
  %303 = or i32 %302, %301
  %304 = and i32 %303, 7
  %305 = icmp eq i32 %304, 0
  %306 = sext i1 %305 to i32
  %307 = call i32 @dx.op.quadOp.i32(i32 123, i32 %306, i8 0)  ; QuadOp(value,op)
  %308 = call i32 @dx.op.quadOp.i32(i32 123, i32 %306, i8 1)  ; QuadOp(value,op)
  %309 = call i32 @dx.op.quadOp.i32(i32 123, i32 %306, i8 2)  ; QuadOp(value,op)
  %310 = or i32 %307, %308
  %311 = or i32 %310, %309
  %312 = or i32 %311, %306
  %313 = trunc i32 %312 to i1
  br i1 %313, label %314, label %329

; <label>:314                                     ; preds = %269
  %315 = call float @dx.op.calculateLOD.f32(i32 81, %dx.types.Handle %64, %dx.types.Handle %45, float %290, float %291, float undef, i1 false)  ; CalculateLOD(handle,sampler,coord0,coord1,coord2,clamped)
  %316 = fmul fast float %315, 8.000000e+00
  %317 = fptoui float %316 to i32
  %318 = call float @dx.op.unary.f32(i32 22, float %290)  ; Frc(value)
  %319 = call float @dx.op.unary.f32(i32 22, float %291)  ; Frc(value)
  %320 = uitofp i32 %71 to float
  %321 = uitofp i32 %72 to float
  %322 = fmul fast float %318, %320
  %323 = fmul fast float %319, %321
  %324 = fptoui float %322 to i32
  %325 = fptoui float %323 to i32
  %326 = mul i32 %325, %71
  %327 = add i32 %326, %324
  %328 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %76, i32 6, i32 %327, i32 undef, i32 undef, i32 %317)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  br label %329

; <label>:329                                     ; preds = %314, %269
  %330 = fmul fast float %296, 0x3FD3333340000000
  %331 = fadd fast float %330, %275
  %332 = fmul fast float %331, %223
  %333 = fmul fast float %331, %224
  %334 = fmul fast float %331, %225
  %335 = call float @dx.op.unary.f32(i32 7, float %332)  ; Saturate(value)
  %336 = call float @dx.op.unary.f32(i32 7, float %333)  ; Saturate(value)
  %337 = call float @dx.op.unary.f32(i32 7, float %334)  ; Saturate(value)
  %338 = fmul fast float %335, 2.000000e+00
  %339 = fmul fast float %336, 2.000000e+00
  %340 = fmul fast float %337, 2.000000e+00
  %341 = fmul fast float %338, %8
  %342 = fadd fast float %341, %338
  %343 = fadd fast float %339, %341
  %344 = fadd fast float %340, %341
  %345 = fsub fast float %222, 0.000000e+00
  %346 = fmul fast float %345, %226
  %347 = fadd fast float %346, 0.000000e+00
  %348 = fmul fast float %347, %342
  %349 = fmul fast float %347, %343
  %350 = fmul fast float %347, %344
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 0, float %348)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 1, float %349)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 2, float %350)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 3, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 0, float %223)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 1, float %224)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 2, float %225)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 3, float %217)
  ret void
}

; Function Attrs: nounwind readnone
declare float @dx.op.loadInput.f32(i32, i32, i32, i8, i32) #0

; Function Attrs: nounwind
declare void @dx.op.storeOutput.f32(i32, i32, i32, i8, float) #1

; Function Attrs: nounwind readnone
declare float @dx.op.dot3.f32(i32, float, float, float, float, float, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.unary.f32(i32, float) #0

; Function Attrs: nounwind readnone
declare float @dx.op.dot4.f32(i32, float, float, float, float, float, float, float, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32, %dx.types.Handle, %dx.types.Handle, float, float, float, float, i32, i32, i32, float) #2

; Function Attrs: nounwind readnone
declare float @dx.op.binary.f32(i32, float, float) #0

; Function Attrs: nounwind readonly
declare %dx.types.ResRet.f32 @dx.op.sample.f32(i32, %dx.types.Handle, %dx.types.Handle, float, float, float, float, i32, i32, i32, float) #2

; Function Attrs: nounwind readonly
declare float @dx.op.calculateLOD.f32(i32, %dx.types.Handle, %dx.types.Handle, float, float, float, i1) #2

; Function Attrs: nounwind
declare i32 @dx.op.atomicBinOp.i32(i32, %dx.types.Handle, i32, i32, i32, i32, i32) #1

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32, %dx.types.Handle, i32) #2

; Function Attrs: nounwind readonly
declare %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32, %dx.types.Handle, i32) #2

; Function Attrs: nounwind readonly
declare %dx.types.Handle @dx.op.createHandle(i32, i8, i32, i32, i1) #2

; Function Attrs: nounwind
declare i32 @dx.op.quadOp.i32(i32, i32, i8) #1

attributes #0 = { nounwind readnone }
attributes #1 = { nounwind }
attributes #2 = { nounwind readonly }

!llvm.ident = !{!0}
!dx.version = !{!1}
!dx.valver = !{!2}
!dx.shaderModel = !{!3}
!dx.resources = !{!4}
!dx.viewIdState = !{!21}
!dx.entryPoints = !{!22}

!0 = !{!"dxcoob 1.7.2212.40 (e043f4a12)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 7}
!3 = !{!"ps", i32 6, i32 0}
!4 = !{!5, !10, !13, !16}
!5 = !{!6, !8, !9}
!6 = !{i32 0, [0 x %"class.Texture2D<vector<float, 4> >"]* undef, !"", i32 2, i32 0, i32 -1, i32 2, i32 0, !7}
!7 = !{i32 0, i32 9}
!8 = !{i32 1, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 0, i32 1, i32 2, i32 0, !7}
!9 = !{i32 2, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 1, i32 1, i32 2, i32 0, !7}
!10 = !{!11}
!11 = !{i32 0, [0 x %"class.RWBuffer<unsigned int>"]* undef, !"", i32 31, i32 0, i32 -1, i32 10, i1 false, i1 false, i1 false, !12}
!12 = !{i32 0, i32 5}
!13 = !{!14, !15}
!14 = !{i32 0, %hostlayout.global_viewport* undef, !"", i32 0, i32 0, i32 1, i32 1788, null}
!15 = !{i32 1, %hostlayout.c_per_object* undef, !"", i32 0, i32 1, i32 1, i32 348, null}
!16 = !{!17, !18, !19, !20}
!17 = !{i32 0, [0 x %struct.SamplerState]* undef, !"", i32 2, i32 0, i32 -1, i32 0, null}
!18 = !{i32 1, %struct.SamplerState* undef, !"", i32 31, i32 0, i32 1, i32 0, null}
!19 = !{i32 2, %struct.SamplerState* undef, !"", i32 0, i32 0, i32 1, i32 0, null}
!20 = !{i32 3, %struct.SamplerState* undef, !"", i32 0, i32 1, i32 1, i32 0, null}
!21 = !{[21 x i32] [i32 19, i32 8, i32 7, i32 7, i32 0, i32 0, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 0, i32 0, i32 7, i32 0, i32 0, i32 0, i32 0]}
!22 = !{void ()* @ps_main, !"ps_main", !23, !4, !45}
!23 = !{!24, !42, null}
!24 = !{!25, !28, !31, !32, !34, !37, !40}
!25 = !{i32 0, !"SV_Position", i8 9, i8 3, !26, i8 4, i32 1, i8 4, i32 0, i8 0, !27}
!26 = !{i32 0}
!27 = !{i32 3, i32 3}
!28 = !{i32 1, !"TEXCOORD", i8 9, i8 0, !29, i8 2, i32 1, i8 3, i32 1, i8 0, !30}
!29 = !{i32 15}
!30 = !{i32 3, i32 7}
!31 = !{i32 2, !"CUSTOM", i8 9, i8 0, !26, i8 2, i32 1, i8 2, i32 2, i8 0, !27}
!32 = !{i32 3, !"CUSTOM", i8 9, i8 0, !33, i8 2, i32 1, i8 2, i32 2, i8 2, !27}
!33 = !{i32 1}
!34 = !{i32 4, !"CUSTOM", i8 9, i8 0, !35, i8 2, i32 1, i8 3, i32 3, i8 0, !36}
!35 = !{i32 2}
!36 = !{i32 3, i32 4}
!37 = !{i32 5, !"CUSTOM", i8 9, i8 0, !38, i8 2, i32 1, i8 1, i32 1, i8 3, !39}
!38 = !{i32 3}
!39 = !{i32 3, i32 1}
!40 = !{i32 6, !"CUSTOM", i8 9, i8 0, !41, i8 2, i32 1, i8 3, i32 4, i8 0, null}
!41 = !{i32 4}
!42 = !{!43, !46}
!43 = !{i32 0, !"SV_Target", i8 9, i8 16, !26, i8 0, i32 1, i8 4, i32 0, i8 0, !44}
!44 = !{i32 3, i32 15}
!45 = !{i32 0, i64 557056}


!46 = !{i32 1, !"SV_Target", i8 9, i8 16, !47, i8 0, i32 1, i8 4, i32 1, i8 0, !44}
!47 = !{i32 1}
