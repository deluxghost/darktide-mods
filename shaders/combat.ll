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
%hostlayout.c_per_object = type { i32, <2 x i32>, <2 x i32>, [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], [4 x <4 x float>], <4 x float>, float, float, float }
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
  %9 = call float @dx.op.loadInput.f32(i32 4, i32 4, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %10 = call float @dx.op.loadInput.f32(i32 4, i32 4, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %11 = call float @dx.op.loadInput.f32(i32 4, i32 3, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %12 = call float @dx.op.loadInput.f32(i32 4, i32 3, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %13 = call float @dx.op.loadInput.f32(i32 4, i32 2, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %14 = call float @dx.op.loadInput.f32(i32 4, i32 2, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %15 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %16 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %17 = call float @dx.op.loadInput.f32(i32 4, i32 1, i32 0, i8 2, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %18 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 0, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %19 = call float @dx.op.loadInput.f32(i32 4, i32 0, i32 0, i8 1, i32 undef)  ; LoadInput(inputSigId,rowIndex,colIndex,gsVertexAxis)
  %20 = fptoui float %18 to i32
  %21 = fptoui float %19 to i32
  %22 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 10)  ; CBufferLoadLegacy(handle,regIndex)
  %23 = extractvalue %dx.types.CBufRet.f32 %22, 3
  %24 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 11)  ; CBufferLoadLegacy(handle,regIndex)
  %25 = extractvalue %dx.types.CBufRet.f32 %24, 3
  %26 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 12)  ; CBufferLoadLegacy(handle,regIndex)
  %27 = extractvalue %dx.types.CBufRet.f32 %26, 3
  %28 = fsub fast float %23, %15
  %29 = fsub fast float %25, %16
  %30 = fsub fast float %27, %17
  %31 = extractvalue %dx.types.CBufRet.f32 %22, 1
  %32 = extractvalue %dx.types.CBufRet.f32 %24, 1
  %33 = extractvalue %dx.types.CBufRet.f32 %26, 1
  %34 = fsub fast float -0.000000e+00, %28
  %35 = fsub fast float -0.000000e+00, %29
  %36 = fsub fast float -0.000000e+00, %30
  %37 = call float @dx.op.dot3.f32(i32 55, float %34, float %35, float %36, float %31, float %32, float %33)  ; Dot3(ax,ay,az,bx,by,bz)
  %38 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 92)  ; CBufferLoadLegacy(handle,regIndex)
  %39 = extractvalue %dx.types.CBufRet.f32 %38, 2
  %40 = extractvalue %dx.types.CBufRet.f32 %38, 3
  %41 = fdiv fast float %18, %39
  %42 = fdiv fast float %19, %40
  %43 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %44 = extractvalue %dx.types.CBufRet.i32 %43, 0
  %45 = add i32 %44, 0
  %46 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 3, i32 0, i32 %45, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %47 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 0)  ; CBufferLoadLegacy(handle,regIndex)
  %48 = extractvalue %dx.types.CBufRet.i32 %47, 1
  %49 = add i32 %48, 0
  %50 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %49, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %51 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %52 = extractvalue %dx.types.CBufRet.i32 %51, 0
  %53 = add i32 %52, 0
  %54 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 0, i32 0, i32 %53, i1 true)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %55 = call %dx.types.CBufRet.i32 @dx.op.cbufferLoadLegacy.i32(i32 59, %dx.types.Handle %6, i32 1)  ; CBufferLoadLegacy(handle,regIndex)
  %56 = extractvalue %dx.types.CBufRet.i32 %55, 1
  %57 = lshr i32 %56, 16
  %58 = and i32 %56, 65535
  %59 = extractvalue %dx.types.CBufRet.i32 %55, 0
  %60 = add i32 %59, 1
  %61 = add i32 %60, 0
  %62 = call %dx.types.Handle @dx.op.createHandle(i32 57, i8 1, i32 0, i32 %61, i1 false)  ; CreateHandle(resourceClass,rangeId,index,nonUniformIndex)
  %63 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %41, float %42, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %64 = extractvalue %dx.types.ResRet.f32 %63, 0
  %65 = bitcast float %64 to i32
  %66 = and i32 %65, 2147483647
  %67 = bitcast i32 %66 to float
  %68 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %2, %dx.types.Handle %4, float %41, float %42, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %69 = extractvalue %dx.types.ResRet.f32 %68, 0
  %70 = bitcast float %69 to i32
  %71 = and i32 %70, 2147483647
  %72 = bitcast i32 %71 to float
  %73 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %6, i32 19)  ; CBufferLoadLegacy(handle,regIndex)
  %74 = extractvalue %dx.types.CBufRet.f32 %73, 0
  %75 = fcmp fast ogt float %72, %67
  %76 = select i1 %75, float 1.000000e+00, float %74
  %77 = fsub fast float %67, %72
  %78 = call float @dx.op.unary.f32(i32 7, float %77)  ; Saturate(value)
  %79 = extractvalue %dx.types.CBufRet.f32 %73, 1
  %80 = fsub fast float %76, %78
  %81 = fmul fast float %80, %79
  %82 = fadd fast float %79, 1.000000e+00
  %83 = call float @dx.op.unary.f32(i32 7, float %82)  ; Saturate(value)
  %84 = fadd fast float %78, -1.000000e+00
  %85 = fadd fast float %84, %81
  %86 = fmul fast float %85, %83
  %87 = fadd fast float %86, 1.000000e+00
  %88 = call float @dx.op.unary.f32(i32 27, float %13)  ; Round_ni(value)
  %89 = call float @dx.op.unary.f32(i32 27, float %14)  ; Round_ni(value)
  %90 = fsub fast float %13, %88
  %91 = fsub fast float %14, %89
  %92 = fadd fast float %88, 1.000000e+00
  %93 = fadd fast float %89, 1.000000e+00
  %94 = fmul fast float %88, 0x3F8CD85680000000
  %95 = fmul fast float %89, 0x3F8CD85680000000
  %96 = fmul fast float %92, 0x3F8CD85680000000
  %97 = fmul fast float %93, 0x3F8CD85680000000
  %98 = call float @dx.op.unary.f32(i32 27, float %94)  ; Round_ni(value)
  %99 = call float @dx.op.unary.f32(i32 27, float %95)  ; Round_ni(value)
  %100 = call float @dx.op.unary.f32(i32 27, float %96)  ; Round_ni(value)
  %101 = call float @dx.op.unary.f32(i32 27, float %97)  ; Round_ni(value)
  %102 = fmul fast float %98, 7.100000e+01
  %103 = fmul fast float %99, 7.100000e+01
  %104 = fmul fast float %100, 7.100000e+01
  %105 = fmul fast float %101, 7.100000e+01
  %106 = fsub fast float %88, %102
  %107 = fsub fast float %89, %103
  %108 = fsub fast float %92, %104
  %109 = fsub fast float %93, %105
  %110 = fadd fast float %106, 2.600000e+01
  %111 = fadd fast float %107, 1.610000e+02
  %112 = fadd fast float %108, 2.600000e+01
  %113 = fadd fast float %109, 1.610000e+02
  %114 = fmul fast float %110, %110
  %115 = fmul fast float %111, %111
  %116 = fmul fast float %112, %112
  %117 = fmul fast float %113, %113
  %118 = fmul fast float %114, 0x3F5139C900000000
  %119 = fmul fast float %118, %115
  %120 = fmul fast float %115, 0x3F5139C900000000
  %121 = fmul fast float %120, %116
  %122 = fmul fast float %118, %117
  %123 = fmul fast float %116, 0x3F5139C900000000
  %124 = fmul fast float %123, %117
  %125 = call float @dx.op.unary.f32(i32 22, float %119)  ; Frc(value)
  %126 = call float @dx.op.unary.f32(i32 22, float %121)  ; Frc(value)
  %127 = call float @dx.op.unary.f32(i32 22, float %122)  ; Frc(value)
  %128 = call float @dx.op.unary.f32(i32 22, float %124)  ; Frc(value)
  %129 = fmul fast float %90, %90
  %130 = fmul fast float %91, %91
  %131 = fmul fast float %129, %90
  %132 = fmul fast float %130, %91
  %133 = fmul fast float %90, 6.000000e+00
  %134 = fmul fast float %91, 6.000000e+00
  %135 = fadd fast float %133, -1.500000e+01
  %136 = fadd fast float %134, -1.500000e+01
  %137 = fmul fast float %135, %90
  %138 = fmul fast float %136, %91
  %139 = fadd fast float %137, 1.000000e+01
  %140 = fadd fast float %138, 1.000000e+01
  %141 = fmul fast float %131, %139
  %142 = fmul fast float %132, %140
  %143 = fsub fast float 1.000000e+00, %141
  %144 = fsub fast float 1.000000e+00, %142
  %145 = fmul fast float %144, %143
  %146 = fmul fast float %144, %141
  %147 = fmul fast float %143, %142
  %148 = fmul fast float %142, %141
  %149 = call float @dx.op.dot4.f32(i32 56, float %125, float %126, float %127, float %128, float %145, float %146, float %147, float %148)  ; Dot4(ax,ay,az,aw,bx,by,bz,bw)
  %150 = fadd fast float %149, 0x3FC3333340000000
  %151 = fadd fast float %67, -2.000000e+03
  %152 = call float @dx.op.unary.f32(i32 28, float %151)  ; Round_pi(value)
  %153 = call float @dx.op.unary.f32(i32 7, float %152)  ; Saturate(value)
  %154 = fsub fast float 1.000000e+00, %153
  %155 = extractvalue %dx.types.CBufRet.f32 %73, 2
  %156 = fmul fast float %155, 0x3FB99999A0000000
  %157 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 106)  ; CBufferLoadLegacy(handle,regIndex)
  %158 = extractvalue %dx.types.CBufRet.f32 %157, 0
  %159 = fadd fast float %37, 0xBFB99999A0000000
  %160 = fsub fast float %159, %158
  %161 = fmul fast float %160, 0x3FB9DBCC60000000
  %162 = call float @dx.op.unary.f32(i32 7, float %161)  ; Saturate(value)
  %163 = fsub fast float 0x3F589374C0000000, %156
  %164 = fmul fast float %163, %162
  %165 = fadd fast float %164, %156
  %166 = fsub fast float %41, %165
  %167 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %166, float %42, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %168 = extractvalue %dx.types.ResRet.f32 %167, 0
  %169 = bitcast float %168 to i32
  %170 = and i32 %169, 2147483647
  %171 = bitcast i32 %170 to float
  %172 = fsub fast float %171, %67
  %173 = fadd fast float %165, %41
  %174 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %173, float %42, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %175 = extractvalue %dx.types.ResRet.f32 %174, 0
  %176 = bitcast float %175 to i32
  %177 = and i32 %176, 2147483647
  %178 = bitcast i32 %177 to float
  %179 = fsub fast float %178, %67
  %180 = call float @dx.op.binary.f32(i32 35, float %179, float %172)  ; FMax(a,b)
  %181 = fsub fast float %42, %165
  %182 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %41, float %181, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %183 = extractvalue %dx.types.ResRet.f32 %182, 0
  %184 = bitcast float %183 to i32
  %185 = and i32 %184, 2147483647
  %186 = bitcast i32 %185 to float
  %187 = fsub fast float %186, %67
  %188 = fadd fast float %165, %42
  %189 = call %dx.types.ResRet.f32 @dx.op.sampleLevel.f32(i32 62, %dx.types.Handle %1, %dx.types.Handle %3, float %41, float %188, float undef, float undef, i32 0, i32 0, i32 undef, float 0.000000e+00)  ; SampleLevel(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,LOD)
  %190 = extractvalue %dx.types.ResRet.f32 %189, 0
  %191 = bitcast float %190 to i32
  %192 = and i32 %191, 2147483647
  %193 = bitcast i32 %192 to float
  %194 = fsub fast float %193, %67
  %195 = call float @dx.op.binary.f32(i32 35, float %194, float %187)  ; FMax(a,b)
  %196 = call float @dx.op.binary.f32(i32 35, float %195, float %180)  ; FMax(a,b)
  %197 = fmul fast float %196, 0x3FF5555560000000
  %198 = call float @dx.op.unary.f32(i32 7, float %197)  ; Saturate(value)
  %199 = fmul fast float %198, 2.000000e+00
  %200 = fsub fast float 3.000000e+00, %199
  %201 = fmul fast float %198, %198
  %202 = fmul fast float %201, %200
  %203 = fmul fast float %150, %87
  %204 = fmul fast float %203, %154
  %205 = fmul fast float %204, %202
  %206 = call float @dx.op.unary.f32(i32 7, float %205)  ; Saturate(value)
  %207 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %54, %dx.types.Handle %5, float %11, float %12, float undef, float undef, i32 0, i32 0, i32 undef, float undef)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %208 = extractvalue %dx.types.ResRet.f32 %207, 0
  %209 = fmul fast float %208, 3.200000e+01
  %210 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %50, %dx.types.Handle %46, float %11, float %12, float undef, float undef, i32 0, i32 0, i32 undef, float %209)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %211 = extractvalue %dx.types.ResRet.f32 %210, 0
  %212 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 91)  ; CBufferLoadLegacy(handle,regIndex)
  %213 = extractvalue %dx.types.CBufRet.f32 %212, 2
  %214 = fptoui float %213 to i32
  %215 = lshr i32 %214, 3
  %216 = xor i32 %214, %20
  %217 = xor i32 %215, %21
  %218 = or i32 %217, %216
  %219 = and i32 %218, 7
  %220 = icmp eq i32 %219, 0
  %221 = sext i1 %220 to i32
  %222 = call i32 @dx.op.quadOp.i32(i32 123, i32 %221, i8 0)  ; QuadOp(value,op)
  %223 = call i32 @dx.op.quadOp.i32(i32 123, i32 %221, i8 1)  ; QuadOp(value,op)
  %224 = call i32 @dx.op.quadOp.i32(i32 123, i32 %221, i8 2)  ; QuadOp(value,op)
  %225 = or i32 %222, %223
  %226 = or i32 %225, %224
  %227 = or i32 %226, %221
  %228 = trunc i32 %227 to i1
  br i1 %228, label %229, label %244

; <label>:229                                     ; preds = %0
  %230 = call float @dx.op.calculateLOD.f32(i32 81, %dx.types.Handle %50, %dx.types.Handle %46, float %11, float %12, float undef, i1 false)  ; CalculateLOD(handle,sampler,coord0,coord1,coord2,clamped)
  %231 = fmul fast float %230, 8.000000e+00
  %232 = fptoui float %231 to i32
  %233 = call float @dx.op.unary.f32(i32 22, float %11)  ; Frc(value)
  %234 = call float @dx.op.unary.f32(i32 22, float %12)  ; Frc(value)
  %235 = uitofp i32 %57 to float
  %236 = uitofp i32 %58 to float
  %237 = fmul fast float %233, %235
  %238 = fmul fast float %234, %236
  %239 = fptoui float %237 to i32
  %240 = fptoui float %238 to i32
  %241 = mul i32 %240, %57
  %242 = add i32 %241, %239
  %243 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %62, i32 6, i32 %242, i32 undef, i32 undef, i32 %232)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  br label %244

; <label>:244                                     ; preds = %229, %0
  %245 = fmul fast float %206, 0x3FDCCCCCE0000000
  %246 = fmul fast float %245, %211
  %247 = fmul fast float %206, 0x3FF0CCCCC0000000
  %248 = fmul fast float %247, %211
  %249 = fmul fast float %196, 1.000000e+01
  %250 = call float @dx.op.unary.f32(i32 7, float %249)  ; Saturate(value)
  %251 = fmul fast float %250, 2.000000e+00
  %252 = fsub fast float 3.000000e+00, %251
  %253 = fmul fast float %250, %250
  %254 = fmul fast float %253, %252
  %255 = fsub fast float %254, %202
  %256 = fmul fast float %255, %154
  %257 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %54, %dx.types.Handle %5, float %9, float %10, float undef, float undef, i32 0, i32 0, i32 undef, float undef)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %258 = extractvalue %dx.types.ResRet.f32 %257, 0
  %259 = fmul fast float %258, 3.200000e+01
  %260 = call %dx.types.ResRet.f32 @dx.op.sample.f32(i32 60, %dx.types.Handle %50, %dx.types.Handle %46, float %9, float %10, float undef, float undef, i32 0, i32 0, i32 undef, float %259)  ; Sample(srv,sampler,coord0,coord1,coord2,coord3,offset0,offset1,offset2,clamp)
  %261 = extractvalue %dx.types.ResRet.f32 %260, 0
  %262 = call %dx.types.CBufRet.f32 @dx.op.cbufferLoadLegacy.f32(i32 59, %dx.types.Handle %7, i32 91)  ; CBufferLoadLegacy(handle,regIndex)
  %263 = extractvalue %dx.types.CBufRet.f32 %262, 2
  %264 = fptoui float %263 to i32
  %265 = lshr i32 %264, 3
  %266 = xor i32 %264, %20
  %267 = xor i32 %265, %21
  %268 = or i32 %267, %266
  %269 = and i32 %268, 7
  %270 = icmp eq i32 %269, 0
  %271 = sext i1 %270 to i32
  %272 = call i32 @dx.op.quadOp.i32(i32 123, i32 %271, i8 0)  ; QuadOp(value,op)
  %273 = call i32 @dx.op.quadOp.i32(i32 123, i32 %271, i8 1)  ; QuadOp(value,op)
  %274 = call i32 @dx.op.quadOp.i32(i32 123, i32 %271, i8 2)  ; QuadOp(value,op)
  %275 = or i32 %272, %273
  %276 = or i32 %275, %274
  %277 = or i32 %276, %271
  %278 = trunc i32 %277 to i1
  br i1 %278, label %279, label %294

; <label>:279                                     ; preds = %244
  %280 = call float @dx.op.calculateLOD.f32(i32 81, %dx.types.Handle %50, %dx.types.Handle %46, float %9, float %10, float undef, i1 false)  ; CalculateLOD(handle,sampler,coord0,coord1,coord2,clamped)
  %281 = fmul fast float %280, 8.000000e+00
  %282 = fptoui float %281 to i32
  %283 = call float @dx.op.unary.f32(i32 22, float %9)  ; Frc(value)
  %284 = call float @dx.op.unary.f32(i32 22, float %10)  ; Frc(value)
  %285 = uitofp i32 %57 to float
  %286 = uitofp i32 %58 to float
  %287 = fmul fast float %283, %285
  %288 = fmul fast float %284, %286
  %289 = fptoui float %287 to i32
  %290 = fptoui float %288 to i32
  %291 = mul i32 %290, %57
  %292 = add i32 %291, %289
  %293 = call i32 @dx.op.atomicBinOp.i32(i32 78, %dx.types.Handle %62, i32 6, i32 %292, i32 undef, i32 undef, i32 %282)  ; AtomicBinOp(handle,atomicOp,offset0,offset1,offset2,newValue)
  br label %294

; <label>:294                                     ; preds = %279, %244
  %295 = fmul fast float %8, 0x3FCCCCCCE0000000
  %296 = fmul fast float %295, %256
  %297 = fmul fast float %296, %261
  %298 = fmul fast float %8, 0x3FDCCCCCE0000000
  %299 = fmul fast float %298, %256
  %300 = fmul fast float %299, %261
  %301 = fmul fast float %8, 0x3FE0CCCCC0000000
  %302 = fmul fast float %301, %256
  %303 = fmul fast float %302, %261
  %304 = fadd fast float %297, 0.000000e+00
  %305 = fadd fast float %300, 0.000000e+00
  %306 = fadd fast float %303, 0.000000e+00
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 0, float %304)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 1, float %305)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 2, float %306)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  call void @dx.op.storeOutput.f32(i32 5, i32 0, i32 0, i8 3, float 0.000000e+00)  ; StoreOutput(outputSigId,rowIndex,colIndex,value)
  %goo_r = fmul fast float %211, 0x3FDCCCCCE0000000
  %goo_gb = fmul fast float %211, 0x3FF0CCCCC0000000
  %goo_a = call float @dx.op.unary.f32(i32 7, float %204)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 0, float %goo_r)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 1, float %goo_gb)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 2, float %goo_gb)
  call void @dx.op.storeOutput.f32(i32 5, i32 1, i32 0, i8 3, float %goo_a)
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
declare float @dx.op.dot4.f32(i32, float, float, float, float, float, float, float, float) #0

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
!15 = !{i32 1, %hostlayout.c_per_object* undef, !"", i32 0, i32 1, i32 1, i32 316, null}
!16 = !{!17, !18, !19, !20}
!17 = !{i32 0, [0 x %struct.SamplerState]* undef, !"", i32 2, i32 0, i32 -1, i32 0, null}
!18 = !{i32 1, %struct.SamplerState* undef, !"", i32 31, i32 0, i32 1, i32 0, null}
!19 = !{i32 2, %struct.SamplerState* undef, !"", i32 0, i32 0, i32 1, i32 0, null}
!20 = !{i32 3, %struct.SamplerState* undef, !"", i32 0, i32 1, i32 1, i32 0, null}
!21 = !{[21 x i32] [i32 19, i32 8, i32 7, i32 7, i32 0, i32 0, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 7, i32 0, i32 0, i32 0, i32 0, i32 0]}
!22 = !{void ()* @ps_main, !"ps_main", !23, !4, !44}
!23 = !{!24, !41, null}
!24 = !{!25, !28, !31, !32, !34, !36, !39}
!25 = !{i32 0, !"SV_Position", i8 9, i8 3, !26, i8 4, i32 1, i8 4, i32 0, i8 0, !27}
!26 = !{i32 0}
!27 = !{i32 3, i32 3}
!28 = !{i32 1, !"TEXCOORD", i8 9, i8 0, !29, i8 2, i32 1, i8 3, i32 1, i8 0, !30}
!29 = !{i32 15}
!30 = !{i32 3, i32 7}
!31 = !{i32 2, !"CUSTOM", i8 9, i8 0, !26, i8 2, i32 1, i8 2, i32 2, i8 0, !27}
!32 = !{i32 3, !"CUSTOM", i8 9, i8 0, !33, i8 2, i32 1, i8 2, i32 2, i8 2, !27}
!33 = !{i32 1}
!34 = !{i32 4, !"CUSTOM", i8 9, i8 0, !35, i8 2, i32 1, i8 2, i32 3, i8 0, !27}
!35 = !{i32 2}
!36 = !{i32 5, !"CUSTOM", i8 9, i8 0, !37, i8 2, i32 1, i8 1, i32 1, i8 3, !38}
!37 = !{i32 3}
!38 = !{i32 3, i32 1}
!39 = !{i32 6, !"CUSTOM", i8 9, i8 0, !40, i8 2, i32 1, i8 3, i32 4, i8 0, null}
!40 = !{i32 4}
!41 = !{!42, !45}
!42 = !{i32 0, !"SV_Target", i8 9, i8 16, !26, i8 0, i32 1, i8 4, i32 0, i8 0, !43}
!43 = !{i32 3, i32 15}
!44 = !{i32 0, i64 557056}


!45 = !{i32 1, !"SV_Target", i8 9, i8 16, !46, i8 0, i32 1, i8 4, i32 1, i8 0, !43}
!46 = !{i32 1}
