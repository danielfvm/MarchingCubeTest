Shader "GenerateMesh/Write Active Texels"
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

            Texture2D<float4> _DataTex;
            
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
			
			float frag (v2f IN) : SV_Target
			{
                uint2 dim;
                _DataTex.GetDimensions(dim.x, dim.y);

				return any(_DataTex[IN.uv * dim] > 0) ? 1.0 : 0.0;
			}

            ENDCG
        }
    }
}
