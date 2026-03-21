Shader "GenerateMesh/DualContouring/Compact Texels"
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

            Texture2D<int4> _DataTex;
			Texture2D<float> _ActiveTexelMap;
            uint2 _TargetSize;
            uint _MaxLod;
			bool _IsIndex;

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

    		Texture2D<uint> _IndexLookup;
			uint _Index;
			uint getIndex(uint idx)
            {
                uint2 dim;
                _IndexLookup.GetDimensions(dim.x, dim.y);
                uint2 uv = uint2(idx % dim.x, idx / dim.x);

                return _IndexLookup[uv];
            }

            #define WIDTH _TargetSize.x //((uint)_ActiveTexelMap_TexelSize.z)
			#define HEIGHT _TargetSize.y //((uint)_ActiveTexelMap_TexelSize.w)

			inline uint UVToIndex(uint2 uv)
			{
				return uv.x + uv.y * WIDTH;
			}

			inline float CountActiveTexels(int3 uv, int2 offset)
			{
				return (float)(1 << (uv.z + uv.z)) * _ActiveTexelMap.Load(uv, offset);
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

			int4 frag (v2f IN) : SV_Target
			{
				if (all(IN.uv * WIDTH >= WIDTH - 1))
				{
					return CountActiveTexels(int3(0, 0, _MaxLod), 0);
				}

				int2 uv = ActiveTexelIndexToUV(UVToIndex(IN.uv * _TargetSize));
				if (uv.x == -1)
					return 0;

				int4 data = _DataTex[uv];

				return data;
			}

            ENDCG
        }
    }
}
