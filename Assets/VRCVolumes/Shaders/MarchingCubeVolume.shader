Shader "VRCVolume/MarchingCubeVolume"
{
    CGINCLUDE

    #include "UnityCG.cginc"
    #include "MarchingCubeTables.cginc"

    // Uniforms
    Texture2D<uint> _DataTex;
    Texture2D<uint4> _TriangleTex;
    Texture2D<float> _ActiveTex;
    bool _Collider;
    int3 _VoxelDimension;
    uint2 _TargetSize;
    uint2 _DataSize;
    uint _MaxLod;

    struct v2f
    {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

    v2f vert (appdata_base v)
    {
        v2f o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.uv = v.texcoord;

        return o;
    }

    ENDCG

    SubShader
    {
        // 1. We generate the triangles used in the mesh
        Pass
        {
            Name "Generate"

            CGPROGRAM
            #pragma shader_feature _CHUNKED_ON
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            uint EncodeZOrder(uint2 coord)
            {
                uint index = 0;

                // Interleave bits: X goes to even positions, Y goes to odd positions
                for (uint i = 0; i < 4; i++)
                {
                    index |= ((coord.x >> i) & 1) << (2 * i);
                    index |= ((coord.y >> i) & 1) << (2 * i + 1);
                }

                return index;
            }
            
            float2 sample(int3 pos)
            {
                #if _CHUNKED_ON
                int3 p = clamp((pos * 2) / _VoxelDimension, 0, 1);

                pos -= (p * 2 - 1) * _VoxelDimension / 2;

                int index = pos.x + pos.y * _VoxelDimension.x + pos.z * _VoxelDimension.x * _VoxelDimension.y;
                int2 uv = int2(index % _DataSize.x, index / _DataSize.x);
                uint idx = p.x + p.y * 2 + p.z * 4;
                uint data = _DataTex[uv + uint2(idx % 2, idx / 2) * _DataSize];
                #else
                pos = clamp(pos, 0, _VoxelDimension - 1);
                uint index = pos.x + pos.y * _VoxelDimension.x + pos.z * _VoxelDimension.x * _VoxelDimension.y;
                uint2 uv = uint2(index % _DataSize.x, index / _DataSize.y);
                uint data = _DataTex[uv];
                #endif

                return float2(float(data >> 8) / 0xFFFF, data & 0xFF);
            }

            float sampleWeight(float3 pos)
            {
                float w0 = sample(pos).r;
                float wX = lerp(w0, sample(pos + int3(1,0,0)).r, pos.x % 1.0);
                float wY = lerp(wX, sample(pos + int3(0,1,0)).r, pos.y % 1.0);
                float wZ = lerp(wY, sample(pos + int3(0,0,1)).r, pos.z % 1.0);

                return wZ; 
            }

            float3 sampleHighQualityNormal(float3 pos)
            {
                float3 grad;
                grad.x = sampleWeight(pos + int3(1,0,0)).r - sampleWeight(pos + int3(-1,0,0)).r;
                grad.y = sampleWeight(pos + int3(0,1,0)).r - sampleWeight(pos + int3(0,-1,0)).r;
                grad.z = sampleWeight(pos + int3(0,0,1)).r - sampleWeight(pos + int3(0,0,-1)).r;
                return normalize(grad);
            }

            float3 sampleSimpleNormal(float3 pos)
            {
                float w = sample(pos).r;
                return normalize(float3(
                    sample(pos + int3(1,0,0)).r - w,
                    sample(pos + int3(0,1,0)).r - w,
                    sample(pos + int3(0,0,1)).r - w
                ));
            }

            uint4 EncodeVertex(float3 position, float3 normal, uint color)
            {
                uint3 qp = uint3(saturate(position) * 0x3FF);
                uint3 qn = uint3((normalize(normal) * 0.5 + 0.5) * 0x3FF);

                return asuint(float4(
                    (qp.x | (qp.y << 10)) / float(0xFFFFF), 
                    (qp.z | (qn.x << 10)) / float(0xFFFFF), 
                    (qn.y | (qn.z << 10)) / float(0xFFFFF), 
                    float(color) / float(0xFFFFF)
                ));
            }

			uint4 frag (v2f IN) : SV_Target
            {
                uint2 uv = IN.uv * _TargetSize; // TODO: Change with dynamic code

                uint voxelIndex = (uv.x >> 2) + (uv.y >> 2) * (_TargetSize.x >> 2);
                uint subIndex = EncodeZOrder(uv % 4);
                uint triIndex = subIndex / 3;
                uint vertIndex = subIndex % 3;
                
                // the subIndex is from 0..16 but we only need 5 Triangles * 3 Vertices = 15 Vertices
                // per cube in total, so at least one Pixel always stays empty.
                uint mask = triIndex != 5 ? 1 : 0;

                int3 gridPos = int3(
                    voxelIndex % _VoxelDimension.x, 
                    (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
                    (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
                );

                int i;
                float2 cubeData[8];
                [unroll] for (i = 0; i < 8; i++)
                    cubeData[i] = sample(gridPos + CornerPositions[i]);
                
                // Determine cube configuration based on corner weights
                uint cubeIndex = 0;
                [unroll] for (i = 0; i < 8; i++)
                    cubeIndex |= ((cubeData[i].r > 0.5) ? 1u : 0u) << i;

                // Skip if the cube is entirely inside or outside the surface
                mask *= (cubeIndex != 0 && cubeIndex != 0xFF) ? 1 : 0;

                vertIndex ^= int(vertIndex < 2);

                int triTableIndex = getTri(cubeIndex, triIndex * 3 + vertIndex);
                mask *= triTableIndex != -1 ? 1 : 0;

                int cornerA = EdgeToCornersA[triTableIndex];
                int cornerB = EdgeToCornersB[triTableIndex];

                float w1 = cubeData[cornerA].r;
                float w2 = cubeData[cornerB].r;

                float t = (0.5 - w1) / (w2 - w1);
                float3 offset = lerp(CornerPositions[cornerA], CornerPositions[cornerB], t); // should be saturated

                float3 vertex = gridPos + offset;

                #ifdef SHADER_API_MOBILE
                float3 n = sampleSimpleNormal(vertex);
                #else
                float3 n = sampleHighQualityNormal(vertex);
                #endif

                uint color = w1 > w2 ? cubeData[cornerA].g : cubeData[cornerB].g;
                
                if (_Collider)
                    return asuint(float4(vertex / _VoxelDimension - 0.5, 1.0)) * mask;
                else
                    return EncodeVertex(vertex / _VoxelDimension, -n, color) * mask;
            } 
            ENDCG
        }

        // 2. We generate a mask by marking all the active triangles with 1 everything else 0.
        Pass
        {
            Name "Active"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			float frag (v2f IN) : SV_Target
			{
				return any(_TriangleTex[IN.uv * _TargetSize] > 0.0) ? 1 : 0;
			}

            ENDCG
        }

        // 3. We compact the texture using the previously generated data + mask.
        Pass
        {
            Name "Compact"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			inline uint UVToIndex(uint2 uv)
			{
				return uv.x + uv.y * _TargetSize.x;
			}

			inline float CountActiveTexels(int3 uv, int2 offset)
			{
				return (float)(1 << (uv.z + uv.z)) * _ActiveTex.Load(uv, offset);
			}

			int2 ActiveTexelIndexToUV(float index)
			{
				float maxLod = _MaxLod;
				int3 uv = int3(0, 0, maxLod);
				if (index >= CountActiveTexels(uv, int2(0, 0)))
					return -1;
					
				float activeTexelSumInPreviousLods = 0;
				while (uv.z >= 1)
				{
					uv += int3(uv.xy, -1);
					float count00 = CountActiveTexels(uv, int2(0, 0));
					float count01 = CountActiveTexels(uv, int2(1, 0));
					float count10 = CountActiveTexels(uv, int2(0, 1));
					bool in00 = index < (activeTexelSumInPreviousLods + count00);
					bool in01 = index < (activeTexelSumInPreviousLods + count00 + count01);
					bool in10 = index < (activeTexelSumInPreviousLods + count00 + count01 + count10);
					if (in00)
					{
						uv.xy += int2(0, 0);
					}
					else if (in01)
					{
						uv.xy += int2(1, 0);
						activeTexelSumInPreviousLods += count00;
					}
					else if (in10)
					{
						uv.xy += int2(0, 1);
						activeTexelSumInPreviousLods += count00 + count01;
					}
					else
					{
						uv.xy += int2(1, 1);
						activeTexelSumInPreviousLods += count00 + count01 + count10;
					}
				}
				return uv.xy;
			}

			uint4 frag (v2f IN) : SV_Target
			{
				if (all(IN.uv * _TargetSize.x >= _TargetSize.x - 1))
					return CountActiveTexels(int3(0, 0, _MaxLod), 0);

				int2 uv = ActiveTexelIndexToUV(UVToIndex(IN.uv * _TargetSize));
				if (uv.x == -1)
					return 0;

				return _TriangleTex[uv];
			}

            ENDCG
        }
    }
}
