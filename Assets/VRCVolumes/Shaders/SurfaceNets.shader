Shader "VRCVolume/SurfaceNets"
{
    Properties
    {
        _Voxelness ("Voxelness", Range(0, 1)) = 0
    }

    CGINCLUDE

    // Uniforms
    Texture2D<uint> _DataTex;
    Texture2D<uint4> _TriangleTex;
    Texture2D<float> _ActiveTex;
    Texture2D<uint> _IndexLookup;

    uint2 _TargetSize;
    int3 _VoxelDimension;
    uint2 _DataSize;
    uint _MaxLod;

    float _Voxelness;

    #include "MarchingCubeTables.cginc"
    #include "UnityCG.cginc"

    #define ImplSample
    #include "Volume.cginc"

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
            Name "Vertices"

            CGPROGRAM
            
            #pragma shader_feature _CHUNKED_ON 
            #pragma shader_feature _VOXEL_ON
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
                uint2 uv = IN.uv * _TargetSize;
                uint voxelIndex = uv.x + uv.y * _TargetSize.x;

                _VoxelDimension += 2;
                int3 gridPos = int3(
                    voxelIndex % _VoxelDimension.x, 
                    (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
                    (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
                );
                _VoxelDimension -= 2;

                float2 v[2][2][2];
                int x, y, z;
                [unroll] for (x = 0; x <= 1; x++)
                    [unroll] for (y = 0; y <= 1; y++)
                        [unroll] for (z = 0; z <= 1; z++)
                        {
                            v[x][y][z] = sample(gridPos + uint3(x, y, z));
                            v[x][y][z].x = (v[x][y][z].x - 0.5) * 2.0;
                        }

                float3 vertex = 0;
                float iso = 0.0;
                uint surface_edge_count = 0;

                [unroll] for (x = 0; x <= 1; x++)
                    [unroll] for (y = 0; y <= 1; y++)
                        if ((v[x][y][0].x < iso) != (v[x][y][1].x < iso))
                        {
                            vertex += gridPos + float3(x, y, abs(v[x][y][0].x) / (abs(v[x][y][0].x) + abs(v[x][y][1].x)));
                            surface_edge_count ++;
                        }

                [unroll] for (x = 0; x <= 1; x++)
                    [unroll] for (z = 0; z <= 1; z++)
                        if ((v[x][0][z].x < iso) != (v[x][1][z].x < iso))
                        {
                            vertex += gridPos + float3(x, abs(v[x][0][z].x) / (abs(v[x][0][z].x) + abs(v[x][1][z].x)), z);
                            surface_edge_count ++;
                        } 

                [unroll] for (y = 0; y <= 1; y++)
                    [unroll] for (z = 0; z <= 1; z++)
                        if ((v[0][y][z].x < iso) != (v[1][y][z].x < iso))
                        {
                            vertex += gridPos + float3(abs(v[0][y][z].x) / (abs(v[0][y][z].x) + abs(v[1][y][z].x)), y, z);
                            surface_edge_count ++;
                        }

                if (surface_edge_count == 0)
                    return 0;

                vertex /= float(surface_edge_count);
                vertex = lerp(vertex, gridPos, _Voxelness);


                #ifdef SHADER_API_MOBILE
                float3 normal = sampleSimpleNormal(vertex);
                #else
                float3 normal = sampleHighQualityNormal(vertex);
                #endif

                // Sample color by surface
                uint color = v[uint(normal.x * 0.9 + 1)][uint(normal.y * 0.9 + 1)][uint(normal.z * 0.9 + 1)].y;
                
                return EncodeVertex(vertex / (_VoxelDimension + 2), -normal, color);
            } 
            ENDCG
        }

        Pass
        {
            Name "Indices"

            CGPROGRAM
            #pragma shader_feature _CHUNKED_ON
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            uint4 swap(uint4 data, bool swap)
            {
                return swap ? data : data.wzyx;
            }

            static const uint3 lookup[3] = {
                uint3(1, 0, 0),
                uint3(0, 0, 1),
                uint3(0, 1, 0) 
            };

            static const uint4 offset[3] = {
                uint4(0, 0, 0, 0),
                uint4(1, 0, 0, 1),
                uint4(1, 1, 0, 0)
            };

            uint2 dim;

            uint getIndex(int3 pos)
            {
                _VoxelDimension += 2;
                uint idx = pos.x + pos.y * _VoxelDimension.x + pos.z * _VoxelDimension.x * _VoxelDimension.y;
                uint2 uv = uint2(idx % dim.x, idx / dim.x);
                _VoxelDimension -= 2;

                return _IndexLookup[uv];
            }

            uint4 frag (v2f IN) : SV_Target
            {
                _IndexLookup.GetDimensions(dim.x, dim.y);

                uint2 uv = IN.uv * (_TargetSize >> 1);
                uint voxelIndex = uv.x + uv.y * (_TargetSize.x >> 1);

                _VoxelDimension += 2;
                int3 gridPos = int3(
                    voxelIndex % _VoxelDimension.x, 
                    (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
                    (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
                ) + 2;
                _VoxelDimension -= 2;
                
                uint2 localUV = IN.uv * _TargetSize - uv * 2;
                uint localIndex = localUV.x + localUV.y * 2;
                float iso = 0.5;

                bool solid1 = sample(gridPos).x > iso;
                bool solid2 = sample(gridPos + lookup[localIndex]).x > iso;
                bool face = solid1 != solid2 && localIndex < 3 && all(gridPos <= _VoxelDimension + 1);

                uint a = localIndex;
                uint b = (localIndex + 1) % 3;
                uint c = (localIndex + 2) % 3; 
 
                return uint(face) * swap(uint4(
                    getIndex(gridPos - uint3(offset[a].x, offset[b].x, offset[c].x)),
                    getIndex(gridPos - uint3(offset[a].y, offset[b].y, offset[c].y)),
                    getIndex(gridPos - uint3(offset[a].z, offset[b].z, offset[c].z)),
                    getIndex(gridPos - uint3(offset[a].w, offset[b].w, offset[c].w))
                ), solid1);
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

        Pass
        {
            Name "Lookup"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"
            
			Texture2D<float> _ActiveTexelMap;

            // TODO: Maybe can combine with compact?
			inline uint CountActiveTexels(int3 uv, int2 offset)
			{
				return (uint)((1 << (uv.z + uv.z)) * _ActiveTexelMap.Load(uv, offset));
			}

			static const uint2 zOrder[3] = {
				uint2(0, 0),
				uint2(1, 0),
				uint2(0, 1)
			};

			uint frag (v2f IN) : SV_Target
			{
                uint2 dim;
                _ActiveTexelMap.GetDimensions(dim.x, dim.y);
                uint3 uv = uint3(IN.uv * dim, 0);
                uint index = 0;

                if (!any(_ActiveTexelMap.Load(uv, 0)))
                    return 0;

                // The extra <= 12 condition is to prevents shader to crash
                while (uv.z < _MaxLod  && uv.z <= 10) {
					uint subIndex = (uv.x & 0x1) | ((uv.y & 0x1) << 1);
					[unroll(3)] for (uint j = 0; j < subIndex; j++)
						index += CountActiveTexels(uint3(uv.xy & ~0x1, uv.z), zOrder[j]);

					uv.xy /= 2;
					uv.z ++; 
				}

				return index;
			}

            ENDCG
        }


        Pass
        {
            Name "Collider"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			float4 frag (v2f IN) : SV_Target
			{
                float4 data = asfloat(_TriangleTex[IN.uv * _TargetSize]);

                float3 vertex;
                float3 normal;
                uint color;

                DecodeVertex(data, vertex, normal, color);

				return float4(vertex, 1.0);
			}

            ENDCG
        }
    }
}
