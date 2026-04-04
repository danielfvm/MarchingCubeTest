Shader "VRCVolume/VolumeSync"
{
    CGINCLUDE
    // TODO: Check for texture type
    Texture2D<uint> _SrcTex;
    Texture2D<uint> _RefTex;
    Texture2D<float> _ActiveTex;
    Texture2D<uint> _OriginalTex;
    Texture2D<uint> _CompactTex;
    uint2 _TargetSize;
    uint _MaxLod;

    #include "UnityCG.cginc" 
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
        ///// The following Passes are used for Serialization /////

        // Determines the differences between _RefTex and _SrcTex
        Pass
        {
            Name "Difference"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            {
                return _RefTex[IN.uv * _TargetSize] != _SrcTex[IN.uv * _TargetSize] ? 1 : 0;
            }

            ENDCG
        }

        // Takes _SrcTex as input and converts the chunk to the next smaller one
        Pass
        {
            Name "MipMap"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            int _VoxelDimension;

            uint sample(int3 pos)
            {
                uint index = pos.x + pos.y * _VoxelDimension * 2 + pos.z * _VoxelDimension * _VoxelDimension * 4;
                uint2 uv = uint2(index % (_TargetSize.x << 1), index / (_TargetSize.y << 1));
 
                return _SrcTex[uv] * all(pos < _VoxelDimension * 2); 
            }

			uint frag (v2f IN) : SV_Target 
            { 
                uint2 uv = IN.uv * _TargetSize;
                uint voxelIndex = uv.x + uv.y * _TargetSize.x;

                int3 gridPos = int3(
                    voxelIndex % _VoxelDimension, 
                    (voxelIndex / _VoxelDimension) % _VoxelDimension, 
                    (voxelIndex / _VoxelDimension) / _VoxelDimension
                ) * 2;

                int active = 0;
                [unroll] for (int x = 0; x <= 1; x++)
                [unroll] for (int y = 0; y <= 1; y++)
                [unroll] for (int z = 0; z <= 1; z++)
                    active += sample(gridPos + int3(x, y, z));

                return active != 0 ? asuint(1.0) : 0; 
            }

            ENDCG
        }

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

			uint frag (v2f IN) : SV_Target
			{
				int2 uv = ActiveTexelIndexToUV(UVToIndex(IN.uv * _TargetSize));
				if (uv.x == -1)
					return 0;

				return uv.x + uv.y * _TargetSize.x + 1;
			}

            ENDCG
        }

        Pass
        {
            Name "Final"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }

        ///// The following Passes are used for Deserialization /////

        Pass
        {
            Name "Copy"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return _SrcTex[IN.uv * _TargetSize]; 
            }

            ENDCG
        }

        Pass
        {
            Name "Deserialize"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }
    }
}
