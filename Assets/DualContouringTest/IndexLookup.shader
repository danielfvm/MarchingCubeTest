Shader "VolumetricPen/IndexLookup"
{
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"

			Texture2D<float> _ActiveTexelMap;

            uint2 _TargetSize;
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
                while (uv.z < _MaxLod  && uv.z <= 12) {
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
    }
}