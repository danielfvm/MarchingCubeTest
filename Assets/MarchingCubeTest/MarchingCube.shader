Shader "GenerateMesh/MarchingCube"
{
    SubShader
    {
        Pass
        {
            ZTest Always
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"
            #include "MarchingCubeTables.cginc"

            Texture2D<float2> _DataTex;
            float _MyTime;

            uint2 _TargetSize;
            uint _VoxelAmount;
            uint _Lod;
            uint2 dim;

            struct v2f
			{
				float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
			};

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
                float weight = 1 - distance(pos, _VoxelAmount / 2) * (/*sin(_MyTime)*/ 0.1 * 0.1 + 0.015);
                return float2(saturate(weight), 1);
             
                //int index = pos.x + pos.y * _VoxelAmount + pos.z * _VoxelAmount * _VoxelAmount;
                //return _DataTex[uint2(index % dim.x, index / dim.x)];
            }
 
            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                return o;
            }

            // GPT claims mod bad on Quest
            static const uint VertIndexLUT[16] = {
                0,1,2,  // 0,1,2
                0,1,2,  // 3,4,5
                0,1,2,  // 6,7,8
                0,1,2,  // 9,10,11
                0,1,2,  // 12,13,14
                0       // 15 (unused)
            };


			float4 frag (v2f IN) : SV_Target
            {
                _DataTex.GetDimensions(dim.x, dim.y);

                uint2 uv = IN.uv * 1024; // TODO: Change with dynamic code

                uint voxelIndex = (uv.x >> 2) + (uv.y >> 2) * (1024 >> 2);
                uint subIndex = EncodeZOrder(uv % 4); //(uv.x % 4) + (uv.y % 4) * 4;
                uint triIndex = subIndex / 3;
                uint vertIndex = VertIndexLUT[subIndex]; //subIndex % 3;
                
                // the subIndex is from 0..16 but we only need 5 Triangles * 3 Vertices = 15 Vertices
                // per cube in total, so at least one Pixel always stays empty.
                float mask = triIndex != 5 ? 1.0 : 0.0;

                int subAmount = _VoxelAmount;// - _Lod;
                int3 gridPos = uint3(
                    voxelIndex % subAmount, 
                    (voxelIndex / subAmount) % subAmount, 
                    (voxelIndex / subAmount) / subAmount
                ) * _Lod;

                mask *= all(gridPos < subAmount) ? 1.0 : 0.0;

                int i;
                float2 cubeData[8];
                [unroll] for (i = 0; i < 8; i++)
                    cubeData[i] = sample(gridPos + CornerPositions[i] /* * _Lod*/);
                
                // Determine cube configuration based on corner weights
                uint cubeIndex = 0;
                [unroll] for (i = 0; i < 8; i++)
                    cubeIndex |= ((cubeData[i].r > 0.5) ? 1u : 0u) << i;

                // Skip if the cube is entirely inside or outside the surface
                mask *= (cubeIndex != 0 && cubeIndex != 0xFF) ? 1.0 : 0.0;

                int triTableIndex = getTri(cubeIndex, triIndex * 3);// TriTable[cubeIndex][triIndex * 3];
                mask *= triTableIndex != -1 ? 1.0 : 0.0;

               // float3 vertices[3];
                    
                // Loop not needed if normal is not needed
               // [unroll] for (int i = 0; i < 3; i++)
               // {
                  //  triTableIndex = TriTable[cubeIndex][triIndex * 3 + i];
                 // vertIndex ^= 1;
                 if (vertIndex == 0)
                    vertIndex = 1;
                else if (vertIndex == 1)
                    vertIndex = 0;
                 triTableIndex = getTri(cubeIndex, triIndex * 3 + vertIndex);//TriTable[cubeIndex][triIndex * 3 + vertIndex];
                
                mask *= triTableIndex != -1 ? 1.0 : 0.0;

                int cornerA = EdgeToCornersA[triTableIndex];
                int cornerB = EdgeToCornersB[triTableIndex];

                float w1 = cubeData[cornerA].r;
                float w2 = cubeData[cornerB].r;

                //float t = saturate((0.5 - w1) / max(abs(w2 - w1), 1e-5));
                float t = (0.5 - w1) / (w2 - w1);
                float3 vertex = lerp(CornerPositions[cornerA], CornerPositions[cornerB], t) /** _Lod*/; // should be saturated

                //vertices[i] = (gridPos + vertex) / _VoxelAmount;
              //  }

               // float3 v1 = vertices[1] - vertices[0];
               // float3 v2 = vertices[2] - vertices[0];
               // float3 n = normalize(cross(v1, v2));
               // float color = 1.0;// sample(gridPos + n).r * 32.0;

                // Alpha value of vertex can be used to select color, alternatively empty.

                // Swap face direction
                

                return float4((gridPos + vertex) / _VoxelAmount, 1.0) * mask;
                //return float4(vertices[vertIndex], color);
            } 
            ENDCG
        }
    }
}
