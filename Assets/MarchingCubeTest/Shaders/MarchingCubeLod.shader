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
            
            float2 sample(int3 pos) 
            {
                pos = clamp(pos + 1, 0, _VoxelAmount + 2);
                
                uint index = pos.x + pos.y * (_VoxelAmount + 2) + pos.z * (_VoxelAmount + 2) * (_VoxelAmount + 2);
                uint2 uv = uint2(index % dim.x, index / dim.y);
                
                uint value = _Data[uv] * 0xFFFFFF;

                float weight = float(value >> 8) / 0xFFFF;
                float color = (value >> 1) & 0xFF;

                return float2(weight, color);
            }

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                return o;
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
                float2 cubeData[8];
                [unroll] for (i = 0; i < 8; i++)
                    cubeData[i] = sample(gridPos + CornerPositions[i]);
                
                // Determine cube configuration based on corner weights
                uint cubeIndex = 0;
                [unroll] for (i = 0; i < 8; i++)
                    cubeIndex |= ((cubeData[i].r > 0.5) ? 1u : 0u) << i;

                // Skip if the cube is entirely inside or outside the surface
                mask *= (cubeIndex != 0 && cubeIndex != 0xFF) ? 1.0 : 0.0;
 
                vertIndex ^= int(vertIndex < 2);

                int triTableIndex = getTri(cubeIndex, triIndex * 3 + /*i*/ vertIndex);
                mask *= triTableIndex != -1 ? 1.0 : 0.0;

                int cornerA = EdgeToCornersA[triTableIndex];
                int cornerB = EdgeToCornersB[triTableIndex];

                float w1 = cubeData[cornerA].r;
                float w2 = cubeData[cornerB].r;

                float t = (0.5 - w1) / (w2 - w1);
                float3 offset = lerp(CornerPositions[cornerA], CornerPositions[cornerB], t); // should be saturated

                float3 vertex = gridPos + offset + 0.25;
                uint color = w1 > w2 ? cubeData[cornerA].g : cubeData[cornerB].g;
                
                return float4(vertex / _VoxelAmount - 0.5, (color + 1) / 255.0) * mask;
            } 
            ENDCG
        }
    }
}
