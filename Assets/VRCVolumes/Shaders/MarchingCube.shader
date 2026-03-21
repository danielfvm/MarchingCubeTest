Shader "VRCVolume/MarchingCube"
{
    CGINCLUDE

    // Uniforms
    Texture2D<uint> _DataTex;
    Texture2D<uint4> _TriangleTex;
    Texture2D<float> _ActiveTex;
    bool _Collider;
    int3 _VoxelDimension;
    uint2 _TargetSize;
    uint2 _DataSize;
    uint _MaxLod;

    #include "MarchingCubeTables.cginc"
    #include "UnityCG.cginc"
    #include "Volume.cginc"

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
