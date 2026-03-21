Shader "VRCVolume/SurfaceNets"
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

            static const uint Edges[12][2] = {
                { 0, 1 }, { 1, 2 }, { 2, 3 }, { 3, 0 },
                { 4, 5 }, { 5, 6 }, { 7, 8 }, { 8, 4 },
                { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 },
            };

            static const float3 Axis[3] = {
                float3(1, 0, 0),
                float3(0, 1, 0),
                float3(0, 0, 1),
            };

			uint4 frag (v2f IN) : SV_Target
            {
                uint2 uv = IN.uv * _TargetSize; // TODO: Change with dynamic code

                uint voxelIndex = (uv.x >> 1) + (uv.y >> 1) * _TargetSize.x;
                uint subIndex = (uv.x & 0x1) | ((uv.y & 0x1) << 1);

                int3 gridPos = int3(
                    voxelIndex % _VoxelDimension.x, 
                    (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
                    (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
                );

                uint i;
                float2 cubeData[8];

                [unroll] for (i = 0; i < 8; i++) {
                    cubeData[i] = sample(gridPos + CornerPositions[i]);
                }

                uint surfaceEdgeCount = 0;

                float3 total = 0;

                float v1 = sample(gridPos).r;
                for (i = 0; i < 3; i++) {
                    float v2 = sample(gridPos + Axis[i]).r;

                    if (v1 < 0.5 && v2 >= 0.5)
                        surfaceEdgeCount ++;
                    else if (v1 >= 0.5 && v2 < 0.5)
                        surfaceEdgeCount ++;
                }

                /* [unroll] for (i = 0; i < 4; i++) {
                    {
                        float3 position_a = gridPos + CornerPositions[i % 4];
                        float sample_a = cubeData[i % 4];
                        float3 position_b = gridPos + CornerPositions[(i + 1) % 4];
                        float sample_b = cubeData[(i + 1) % 4];

                        if (sample_a * sample_b <= 0)
                            surfaceEdgeCount += 1; 
                        
                        total += lerp(position_a, position_b, abs(sample_a) / (abs(sample_a) + abs(sample_b)));
                    }

                    {
                        float3 position_a = gridPos + CornerPositions[4 + (i % 4)];
                        float sample_a = cubeData[4 + (i % 4)];
                        float3 position_b = gridPos + CornerPositions[4 + ((i + 1) % 4)];
                        float sample_b = cubeData[4 + ((i + 1) % 4)];

                        if (sample_a * sample_b <= 0)
                            surfaceEdgeCount += 1; 
                        
                        total += lerp(position_a, position_b, abs(sample_a) / (abs(sample_a) + abs(sample_b)));
                    }

                    {
                        float3 position_a = gridPos + CornerPositions[i % 4];
                        float sample_a = cubeData[i % 4];
                        float3 position_b = gridPos + CornerPositions[4 + ((i + 1) % 4)];
                        float sample_b = cubeData[4 + ((i + 1) % 4)];

                        if (sample_a * sample_b <= 0)
                            surfaceEdgeCount += 1; 
                        
                        total += lerp(position_a, position_b, abs(sample_a) / (abs(sample_a) + abs(sample_b)));
                    }
                } */

                uint color = 1;
                float3 vertex = gridPos; //total / surfaceEdgeCount;
                uint mask = surfaceEdgeCount != 0;
                float3 n = 1;

                return EncodeVertex(vertex / _VoxelDimension, -n, color) * mask;

/*
                if (_Collider)
                    return asuint(float4(vertex / _VoxelDimension - 0.5, 1.0)) * mask;
                else
                    return EncodeVertex(vertex / _VoxelDimension, -n, color) * mask;*/
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
