Shader "GenerateMesh/MarchingCubeLod"
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

            Texture2D<float> _Data;

            uint2 _TargetSize;
            uint _VoxelAmount;
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
            
            float sample(int3 pos)
            {
                pos = clamp(pos + 2, 0, _VoxelAmount + 3);
                
                uint index = pos.x + pos.y * (_VoxelAmount + 4) + pos.z * (_VoxelAmount + 4) * (_VoxelAmount + 4);
                uint2 uv = uint2(index % dim.x, index / dim.y);

                return _Data[uv];
            }

            /*float sample(int3 pos)
            {
                float weight = 1 - distance(pos, _VoxelAmount / 2) * (0.05 + 0.15);
                return saturate(weight);
            }*/

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                return o;
            }

            float4 EncodeVertex(float3 position, float3 normal)
            {
                uint3 qp = uint3(saturate(position) * 0x3FF);
                uint3 qn = uint3((normalize(normal) * 0.5 + 0.5) * 0x3FF);

                return float4(
                    (qp.x | (qp.y << 10)) / float(0xFFFFF), 
                    (qp.z | (qn.x << 10)) / float(0xFFFFF), 
                    (qn.y | (qn.z << 10)) / float(0xFFFFF), 
                    1.0
                );
            }

			float4 frag (v2f IN) : SV_Target
            {
                _Data.GetDimensions(dim.x, dim.y);

                uint2 uv = IN.uv * _TargetSize; // TODO: Change with dynamic code

                uint voxelIndex = (uv.x >> 2) + (uv.y >> 2) * (_TargetSize.x >> 2);
                uint subIndex = EncodeZOrder(uv % 4); //(uv.x % 4) + (uv.y % 4) * 4;
                uint triIndex = subIndex / 3;
                uint vertIndex = subIndex % 3;
                
                // the subIndex is from 0..16 but we only need 5 Triangles * 3 Vertices = 15 Vertices
                // per cube in total, so at least one Pixel always stays empty.
                float mask = triIndex != 5 ? 1.0 : 0.0;

                int3 gridPos = uint3(
                    voxelIndex % _VoxelAmount, 
                    (voxelIndex / _VoxelAmount) % _VoxelAmount, 
                    (voxelIndex / _VoxelAmount) / _VoxelAmount
                );

                mask *= all(gridPos < _VoxelAmount) ? 1.0 : 0.0;

                int i;
                float cubeData[8];
                [unroll] for (i = 0; i < 8; i++)
                    cubeData[i] = sample(gridPos + CornerPositions[i]);
                
                // Determine cube configuration based on corner weights
                uint cubeIndex = 0;
                [unroll] for (i = 0; i < 8; i++)
                    cubeIndex |= ((cubeData[i] > 0.5) ? 1u : 0u) << i;

                // Skip if the cube is entirely inside or outside the surface
                mask *= (cubeIndex != 0 && cubeIndex != 0xFF) ? 1.0 : 0.0;
 
                vertIndex ^= int(vertIndex < 2);

                int triTableIndex = getTri(cubeIndex, triIndex * 3 + /*i*/ vertIndex);
                mask *= triTableIndex != -1 ? 1.0 : 0.0;

                int cornerA = EdgeToCornersA[triTableIndex];
                int cornerB = EdgeToCornersB[triTableIndex];

                float w1 = cubeData[cornerA];
                float w2 = cubeData[cornerB];

                float t = (0.5 - w1) / (w2 - w1);
                float3 offset = lerp(CornerPositions[cornerA], CornerPositions[cornerB], t); // should be saturated

                float3 vertex = gridPos + offset;

                return float4(vertex / _VoxelAmount, 1.0) * mask;
            } 
            ENDCG
        }
    }
}
