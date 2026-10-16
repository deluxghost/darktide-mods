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
; CUSTOM                   0   xy          2     NONE   float   xy  
; CUSTOM                   1   xyz         3     NONE   float     z 
;
;
; Output signature:
;
; Name                 Index   Mask Register SysValue  Format   Used
; -------------------- ----- ------ -------- -------- ------- ------
; SV_Target                0   xyzw        0   TARGET   float   xyzw
;
; shader hash: 8cdc834d0847cb06c4601e402fcc2204
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
;       float3 color;                                 ; Offset:  320
;       float outline_thickness;                      ; Offset:  332
;   
;   } c_per_object;                                   ; Offset:    0 Size:   336
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
; global_texture2D                  texture     f32          2d      T0      t0,space2unbounded
; __tex_linear_depth                texture     f32          2d      T1             t0     1
; global_feedback_buffers               UAV     u32         buf      U0     u0,space31unbounded
;
;
; ViewId state:
;
; Number of inputs: 15, outputs: 4
; Outputs dependent on ViewId: {  }
; Inputs contributing to computation of Outputs:
;   output 0 depends on inputs: { 0, 1, 4, 5, 6, 8, 9, 14 }
;   output 1 depends on inputs: { 0, 1, 4, 5, 6, 8, 9, 14 }
;   output 2 depends on inputs: { 0, 1, 4, 5, 6, 8, 9, 14 }
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
%hostlayout.c_per_object = type { i32, <2 x i32>, <2 x i32>, <2 x i32>, <2 x i32>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, <3 x float>, float }
%struct.SamplerState = type { i32 }

define void @ps_main() {
  %1 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 1, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %2 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 2, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %3 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 1, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %4 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 1, i32 1, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %5 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 2, i32 0, i32 0, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %6 = call float @dx.op.loadInput.f32(i32 4, i32 3, i32 0, i8 2, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %7 = call float @dx.op.loadInput.f32(i32 4, i32 2, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %8 = call float @dx.op.loadInput.f32(i32 4, i32 2, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %9 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %10 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %11 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 2, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %12 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %13 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %14 = fptoui float %12 to i32
  %15 = fptoui float %13 to i32
  %16 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 10)  ; CBufferLoadLegacy(handle,regIndex)
  %17 = extractvalue %dx.types.CBufRet.f32 %16, 3
  %18 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 11)  ; CBufferLoadLegacy(handle,regIndex)
  %19 = extractvalue %dx.types.CBufRet.f32 %18, 3
  %20 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 12)  ; CBufferLoadLegacy(handle,regIndex)
  %21 = extractvalue %dx.types.CBufRet.f32 %20, 3
  %22 = fsub fast float %17, %9
  %23 = fsub fast float %19, %10
  %24 = fsub fast float %21, %11
  %25 = extractvalue %dx.types.CBufRet.f32 %16, 1
  %26 = extractvalue %dx.types.CBufRet.f32 %18, 1
  %27 = extractvalue %dx.types.CBufRet.f32 %20, 1
  %28 = fsub fast float -0.000000e+00, %22
  %29 = fsub fast float -0.000000e+00, %23
  %30 = fsub fast float -0.000000e+00, %24
  %31 = call float @dx.op.dot3.f32(i32 55, float %28, float %29, float %30, float %25, float %26, float %27)  ; Dot3(ax,ay,az,bx,by,bz)
  %32 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 92)  ; CBufferLoadLegacy(handle,regIndex)
  %33 = extractvalue %dx.types.CBufRet.f32 %32, 2
  %34 = extractvalue %dx.types.CBufRet.f32 %32, 3
  %35 = fdiv fast float %12, %33
  %36 = fdiv fast float %13, %34
  %37 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %38 = extractvalue %dx.types.CBufRet.i32 %37, 0
  %39 = add i32 %38, 0
  %40 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 0, i32 %39, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %41 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %42 = extractvalue %dx.types.CBufRet.i32 %41, 1
  %43 = add i32 %42, 0
  %44 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %43, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %45 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %46 = extractvalue %dx.types.CBufRet.i32 %45, 0
  %47 = add i32 %46, 0
  %48 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %47, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %49 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %50 = extractvalue %dx.types.CBufRet.i32 %49, 1
  %51 = lshr i32 %50, 16
  %52 = extractvalue %dx.types.CBufRet.i32 %49, 0
  %53 = add i32 %52, 1
  %54 = add i32 %53, 0
  %55 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 %54, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %56 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %57 = extractvalue %dx.types.CBufRet.i32 %56, 2
  %58 = add i32 %57, 0
  %59 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %58, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %60 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %61 = extractvalue %dx.types.CBufRet.i32 %60, 0
  %62 = add i32 %61, 0
  %63 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %62, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %64 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %4, i32 2)  ; CBufferLoadLegacy(handle,regIndex)
  %65 = extractvalue %dx.types.CBufRet.i32 %64, 1
  %66 = lshr i32 %65, 16
  %67 = and i32 %65, 65535
  %68 = extractvalue %dx.types.CBufRet.i32 %64, 0
  %69 = add i32 %68, 1
  %70 = add i32 %69, 0
  %71 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 %70, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %72 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %2, float %35, float %36, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %73 = extractvalue %dx.types.ResRet.f32 %72, 0
  %74 = bitcast float %73 to i32
  %75 = and i32 %74, 2147483647
  %76 = bitcast i32 %75 to float
  %77 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 20)  ; CBufferLoadLegacy(handle,regIndex)
  %78 = extractvalue %dx.types.CBufRet.f32 %77, 3
  %79 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 106)  ; CBufferLoadLegacy(handle,regIndex)
  %80 = extractvalue %dx.types.CBufRet.f32 %79, 0
  %81 = fsub fast float %31, %80
  %82 = fsub fast float 0x3F40624DE0000000, %78
  %83 = fmul fast float %82, 0x3F847AE140000000
  %84 = fmul fast float %83, %81
  %85 = fadd fast float %84, %78
  %86 = fsub fast float %35, %85
  %87 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %2, float %86, float %36, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %88 = extractvalue %dx.types.ResRet.f32 %87, 0
  %89 = bitcast float %88 to i32
  %90 = and i32 %89, 2147483647
  %91 = bitcast i32 %90 to float
  %92 = fsub fast float %91, %76
  %93 = fadd fast float %85, %35
  %94 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %2, float %93, float %36, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %95 = extractvalue %dx.types.ResRet.f32 %94, 0
  %96 = bitcast float %95 to i32
  %97 = and i32 %96, 2147483647
  %98 = bitcast i32 %97 to float
  %99 = fsub fast float %98, %76
  %100 = call float @dx.op.binary.f32(i32 35, float %99, float %92)  ; FMax(a,b)
  %101 = fsub fast float %36, %85
  %102 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %2, float %35, float %101, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %103 = extractvalue %dx.types.ResRet.f32 %102, 0
  %104 = bitcast float %103 to i32
  %105 = and i32 %104, 2147483647
  %106 = bitcast i32 %105 to float
  %107 = fsub fast float %106, %76
  %108 = fadd fast float %85, %36
  %109 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %2, float %35, float %108, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %110 = extractvalue %dx.types.ResRet.f32 %109, 0
  %111 = bitcast float %110 to i32
  %112 = and i32 %111, 2147483647
  %113 = bitcast i32 %112 to float
  %114 = fsub fast float %113, %76
  %115 = call float @dx.op.binary.f32(i32 35, float %114, float %107)  ; FMax(a,b)
  %116 = call float @dx.op.binary.f32(i32 35, float %115, float %100)  ; FMax(a,b)
  %117 = fmul fast float %116, 0x3FF5555560000000
  %118 = call float @dx.op.unary.f32(i32 7, float %117)  ; Saturate(value)
  %119 = fmul fast float %118, 2.000000e+00
  %120 = fsub fast float 3.000000e+00, %119
  %121 = fmul fast float %118, %118
  %122 = fmul fast float %121, %120
  %123 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %48, %dx.types.Handle %3, float %7, float %8, float undef, float undef, i32 0, i32 0, i32 undef, float undef)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %124 = extractvalue %dx.types.ResRet.f32 %123, 0
  %125 = fmul fast float %124, 3.200000e+01
  %126 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %44, %dx.types.Handle %40, float %7, float %8, float undef, float undef, i32 0, i32 0, i32 undef, float %125)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %127 = extractvalue %dx.types.ResRet.f32 %126, 0
  %128 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 91)  ; CBufferLoadLegacy(handle,regIndex)
  %129 = extractvalue %dx.types.CBufRet.f32 %128, 2
  %130 = fptoui float %129 to i32
  %131 = lshr i32 %130, 3
  %132 = xor i32 %130, %14
  %133 = xor i32 %131, %15
  %134 = or i32 %133, %132
  %135 = and i32 %134, 7
  %136 = icmp eq i32 %135, 0
  %137 = sext i1 %136 to i32
  %138 = call i32 @dx.op.quadOp.i32(i32 123, i32 %137, i8 0)  ; QuadOp(value,op)
  %139 = call i32 @dx.op.quadOp.i32(i32 123, i32 %137, i8 1)  ; QuadOp(value,op)
  %140 = call i32 @dx.op.quadOp.i32(i32 123, i32 %137, i8 2)  ; QuadOp(value,op)
  %141 = or i32 %138, %139
  %142 = or i32 %141, %140
  %143 = or i32 %142, %137
  %144 = trunc i32 %143 to i1
  br i1 %144, label %145, label %161

; <label>:145                                     ; preds = %0
  %146 = and i32 %50, 65535
  %147 = call float @dx.op.calculateLOD.f32(i32 81, %dx.types.Handle %44, %dx.types.Handle %40, float %7, float %8, float undef, i1 false)  ; CalculateLOD(handle,sampler,coord0,coord1,coord2,clamped)
  %148 = fmul fast float %147, 8.000000e+00
  %149 = fptoui float %148 to i32
  %150 = call float @dx.op.unary.f32(i32 22, float %7)  ; Frc(value)
  %151 = call float @dx.op.unary.f32(i32 22, float %8)  ; Frc(value)
  %152 = uitofp i32 %51 to float
  %153 = uitofp i32 %146 to float
  %154 = fmul fast float %150, %152
  %155 = fmul fast float %151, %153
  %156 = fptoui float %154 to i32
  %157 = fptoui float %155 to i32
  %158 = mul i32 %157, %51
  %159 = add i32 %158, %156
  %160 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %55, i32 6, i32 %159, i32 undef, i32 undef, i32 %149)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  br label %161

; <label>:161                                     ; preds = %145, %0
  %162 = call float @dx.op.unary.f32(i32 23, float %127)  ; Log(value)
  %163 = fmul fast float %162, 1.000000e+01
  %164 = call float @dx.op.unary.f32(i32 21, float %163)  ; Exp(value)
  %165 = fadd fast float %164, -5.000000e-01
  %166 = call float @dx.op.unary.f32(i32 7, float %165)  ; Saturate(value)
  %167 = fmul fast float %166, 1.250000e+00
  %168 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 90)  ; CBufferLoadLegacy(handle,regIndex)
  %169 = extractvalue %dx.types.CBufRet.f32 %168, 0
  %170 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 106)  ; CBufferLoadLegacy(handle,regIndex)
  %171 = extractvalue %dx.types.CBufRet.f32 %170, 0
  %172 = fadd fast float %31, -5.000000e+00
  %173 = fsub fast float %172, %171
  %174 = fmul fast float %173, 0x3FC99999A0000000
  %175 = call float @dx.op.unary.f32(i32 7, float %174)  ; Saturate(value)
  %176 = fmul fast float %175, 1.500000e+01
  %177 = call float @dx.op.unary.f32(i32 26, float %176)  ; Round_ne(value)
  %178 = fsub fast float 3.000000e+01, %177
  %179 = fmul fast float %178, %6
  %180 = fmul fast float %169, 0x3FD51EB860000000
  %181 = fmul fast float %169, 2.000000e+00
  %182 = fadd fast float %180, %6
  %183 = fadd fast float %179, %181
  %184 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %63, %dx.types.Handle %3, float %182, float %183, float undef, float undef, i32 0, i32 0, i32 undef, float undef)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %185 = extractvalue %dx.types.ResRet.f32 %184, 0
  %186 = fmul fast float %185, 3.200000e+01
  %187 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %59, %dx.types.Handle %40, float %182, float %183, float undef, float undef, i32 0, i32 0, i32 undef, float %186)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %188 = extractvalue %dx.types.ResRet.f32 %187, 0
  %189 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %5, i32 91)  ; CBufferLoadLegacy(handle,regIndex)
  %190 = extractvalue %dx.types.CBufRet.f32 %189, 2
  %191 = fptoui float %190 to i32
  %192 = lshr i32 %191, 3
  %193 = xor i32 %191, %14
  %194 = xor i32 %192, %15
  %195 = or i32 %194, %193
  %196 = and i32 %195, 7
  %197 = icmp eq i32 %196, 0
  %198 = sext i1 %197 to i32
  %199 = call i32 @dx.op.quadOp.i32(i32 123, i32 %198, i8 0)  ; QuadOp(value,op)
  %200 = call i32 @dx.op.quadOp.i32(i32 123, i32 %198, i8 1)  ; QuadOp(value,op)
  %201 = call i32 @dx.op.quadOp.i32(i32 123, i32 %198, i8 2)  ; QuadOp(value,op)
  %202 = or i32 %199, %200
  %203 = or i32 %202, %201
  %204 = or i32 %203, %198
  %205 = trunc i32 %204 to i1
  br i1 %205, label %206, label %221

; <label>:206                                     ; preds = %161
  %207 = call float @dx.op.calculateLOD.f32(i32 81, %dx.types.Handle %59, %dx.types.Handle %40, float %182, float %183, float undef, i1 false)  ; CalculateLOD(handle,sampler,coord0,coord1,coord2,clamped)
  %208 = fmul fast float %207, 8.000000e+00
  %209 = fptoui float %208 to i32
  %210 = call float @dx.op.unary.f32(i32 22, float %182)  ; Frc(value)
  %211 = call float @dx.op.unary.f32(i32 22, float %183)  ; Frc(value)
  %212 = uitofp i32 %66 to float
  %213 = uitofp i32 %67 to float
  %214 = fmul fast float %210, %212
  %215 = fmul fast float %211, %213
  %216 = fptoui float %214 to i32
  %217 = fptoui float %215 to i32
  %218 = mul i32 %217, %66
  %219 = add i32 %218, %216
  %220 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %71, i32 6, i32 %219, i32 undef, i32 undef, i32 %209)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  br label %221

; <label>:221                                     ; preds = %206, %161
  %222 = fmul fast float %188, 0x3FD3333340000000
  %223 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 20)  ; CBufferLoadLegacy(handle,regIndex)
  %224 = extractvalue %dx.types.CBufRet.f32 %223, 0
  %225 = extractvalue %dx.types.CBufRet.f32 %223, 1
  %226 = extractvalue %dx.types.CBufRet.f32 %223, 2
  %227 = fsub fast float %167, %222
  %228 = fadd fast float %227, %224
  %229 = fadd fast float %227, %225
  %230 = fadd fast float %227, %226
  %231 = call float @dx.op.unary.f32(i32 7, float %228)  ; Saturate(value)
  %232 = call float @dx.op.unary.f32(i32 7, float %229)  ; Saturate(value)
  %233 = call float @dx.op.unary.f32(i32 7, float %230)  ; Saturate(value)
  %234 = fmul fast float %122, 2.000000e+00
  %235 = fmul fast float %234, %231
  %236 = fmul fast float %234, %232
  %237 = fmul fast float %234, %233
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 0, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 1, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 2, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 3, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  ; Upper 20 bits order positive depths; low bits carry RGB, target identity and occlusion.
  ; MIN blending selects the nearest fragment without relying on transparent draw order.
  %goo_identity_cb = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %4, i32 19)
  %goo_identity_value = extractvalue %dx.types.CBufRet.f32 %goo_identity_cb, 3
  %goo_identity = fptoui float %goo_identity_value to i32
  %goo_depth_bits = bitcast float %31 to i32
  %goo_depth_prefix = and i32 %goo_depth_bits, -4096
  %goo_in_range = fcmp fast ogt float %31, 0.000000e+00
  %goo_r_sat = call float @dx.op.unary.f32(i32 7, float %224)
  %goo_r_scaled = fmul fast float %goo_r_sat, 2.550000e+02
  %goo_r_round = fadd fast float %goo_r_scaled, 5.000000e-01
  %goo_r_byte = fptoui float %goo_r_round to i32
  %goo_r_id_shifted = lshr i32 %goo_identity, 0
  %goo_r_id_nibble = and i32 %goo_r_id_shifted, 15
  %goo_r_id_bits = shl i32 %goo_r_id_nibble, 8
  %goo_r_payload = or i32 %goo_r_id_bits, %goo_r_byte
  %goo_r_bits = or i32 %goo_depth_prefix, %goo_r_payload
  %goo_r_packed = bitcast i32 %goo_r_bits to float
  %goo_r_encoded = select i1 %goo_in_range, float %goo_r_packed, float 4.096000e+03
  %goo_g_sat = call float @dx.op.unary.f32(i32 7, float %225)
  %goo_g_scaled = fmul fast float %goo_g_sat, 2.550000e+02
  %goo_g_round = fadd fast float %goo_g_scaled, 5.000000e-01
  %goo_g_byte = fptoui float %goo_g_round to i32
  %goo_g_id_shifted = lshr i32 %goo_identity, 4
  %goo_g_id_nibble = and i32 %goo_g_id_shifted, 15
  %goo_g_id_bits = shl i32 %goo_g_id_nibble, 8
  %goo_g_payload = or i32 %goo_g_id_bits, %goo_g_byte
  %goo_g_bits = or i32 %goo_depth_prefix, %goo_g_payload
  %goo_g_packed = bitcast i32 %goo_g_bits to float
  %goo_g_encoded = select i1 %goo_in_range, float %goo_g_packed, float 4.096000e+03
  %goo_b_sat = call float @dx.op.unary.f32(i32 7, float %226)
  %goo_b_scaled = fmul fast float %goo_b_sat, 2.550000e+02
  %goo_b_round = fadd fast float %goo_b_scaled, 5.000000e-01
  %goo_b_byte = fptoui float %goo_b_round to i32
  %goo_b_id_shifted = lshr i32 %goo_identity, 8
  %goo_b_id_nibble = and i32 %goo_b_id_shifted, 15
  %goo_b_id_bits = shl i32 %goo_b_id_nibble, 8
  %goo_b_payload = or i32 %goo_b_id_bits, %goo_b_byte
  %goo_b_bits = or i32 %goo_depth_prefix, %goo_b_payload
  %goo_b_packed = bitcast i32 %goo_b_bits to float
  %goo_b_encoded = select i1 %goo_in_range, float %goo_b_packed, float 4.096000e+03
  %goo_depth_tolerance = fadd fast float %76, 0x3F847AE140000000
  %goo_occluded = fcmp ogt float %31, %goo_depth_tolerance
  %goo_occlusion_bit = zext i1 %goo_occluded to i32
  %goo_a_id_shifted = lshr i32 %goo_identity, 12
  %goo_a_id_bits = shl i32 %goo_a_id_shifted, 1
  %goo_a_identity_occlusion = or i32 %goo_a_id_bits, %goo_occlusion_bit
  ; Bit 11 requests component depth edges in the shared composite.
  %goo_a_payload = or i32 %goo_a_identity_occlusion, 2048
  %goo_a_bits = or i32 %goo_depth_prefix, %goo_a_payload
  %goo_a_packed = bitcast i32 %goo_a_bits to float
  %goo_a_encoded = select i1 %goo_in_range, float %goo_a_packed, float 4.096000e+03
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 0, float %goo_r_encoded)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 1, float %goo_g_encoded)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 2, float %goo_b_encoded)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 3, float %goo_a_encoded)
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
!dx.viewIdState = !{!19}
!dx.entryPoints = !{!20}

!0 = !{!"dxcoob 1.7.2212.40 (e043f4a12)"}
!1 = !{i32 1, i32 0}
!2 = !{i32 1, i32 7}
!3 = !{!"ps", i32 6, i32 0}
!4 = !{!5, !9, !12, !15}
!5 = !{!6, !8}
!6 = !{i32 0, [0 x %"class.Texture2D<vector<float, 4> >"]* undef, !"", i32 2, i32 0, i32 -1, i32 2, i32 0, !7}
!7 = !{i32 0, i32 9}
!8 = !{i32 1, %"class.Texture2D<vector<float, 4> >"* undef, !"", i32 0, i32 0, i32 1, i32 2, i32 0, !7}
!9 = !{!10}
!10 = !{i32 0, [0 x %"class.RWBuffer<unsigned int>"]* undef, !"", i32 31, i32 0, i32 -1, i32 10, i1 false, i1 false, i1 false, !11}
!11 = !{i32 0, i32 5}
!12 = !{!13, !14}
!13 = !{i32 0, %hostlayout.global_viewport* undef, !"", i32 0, i32 0, i32 1, i32 1788, null}
!14 = !{i32 1, %hostlayout.c_per_object* undef, !"", i32 0, i32 1, i32 1, i32 336, null}
!15 = !{!16, !17, !18}
!16 = !{i32 0, [0 x %struct.SamplerState]* undef, !"", i32 2, i32 0, i32 -1, i32 0, null}
!17 = !{i32 1, %struct.SamplerState* undef, !"", i32 31, i32 0, i32 1, i32 0, null}
!18 = !{i32 2, %struct.SamplerState* undef, !"", i32 0, i32 0, i32 1, i32 0, null}
!19 = !{[17 x i32] [i32 15, i32 8, i32 7, i32 7, i32 0, i32 0, i32 7, i32 7, i32 7, i32 0, i32 7, i32 7, i32 0, i32 0, i32 0, i32 0, i32 7]}
!20 = !{void ()* @ps_main, !"ps_main", !21, !4, !36}
!21 = !{!22, !33, null}
!22 = !{!23, !26, !29, !30}
!23 = !{i32 0, !"SV_Position", i8 9, i8 3, !24, i8 4, i32 1, i8 4, i32 0, i8 0, !25}
!24 = !{i32 0}
!25 = !{i32 3, i32 3}
!26 = !{i32 1, !"TEXCOORD", i8 9, i8 0, !27, i8 2, i32 1, i8 3, i32 1, i8 0, !28}
!27 = !{i32 15}
!28 = !{i32 3, i32 7}
!29 = !{i32 2, !"CUSTOM", i8 9, i8 0, !24, i8 2, i32 1, i8 2, i32 2, i8 0, !25}
!30 = !{i32 3, !"CUSTOM", i8 9, i8 0, !31, i8 2, i32 1, i8 3, i32 3, i8 0, !32}
!31 = !{i32 1}
!32 = !{i32 3, i32 4}
!33 = !{!34, !37}
!34 = !{i32 0, !"SV_Target", i8 9, i8 16, !24, i8 0, i32 1, i8 4, i32 0, i8 0, !35}
!35 = !{i32 3, i32 15}
!36 = !{i32 0, i64 557056}

!37 = !{i32 1, !"SV_Target", i8 9, i8 16, !38, i8 0, i32 1, i8 4, i32 1, i8 0, !35}
!38 = !{i32 1}
