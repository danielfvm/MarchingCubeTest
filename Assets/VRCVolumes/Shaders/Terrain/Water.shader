Shader "VRCVolume/Water"
{
    Properties
    {
    }

    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc" 
            #include "../../../krajsy/NoiseFunctions.cginc"

            // Uniforms
            Texture2D<float4> _PrevTex;
            sampler2D _DepthTex;
            SamplerState sampler_Depth;

            uint2 _TargetSize;
            int2 _Delta;

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

            float4 frag (v2f IN) : SV_Target 
            {
                float depth01 = tex2D(_DepthTex, IN.uv);
                int2 uv = IN.uv * _TargetSize + _Delta;
                
                if (depth01 <= 0.0 && all(_Delta == 0))
                    return float4(0, 0, 0, 0);

                if (noise(uv * 0.1) < -0.99)
                    return float4(1, depth01, 0, 0);

                float n = _PrevTex[uv + int2(1, 0)].x + _PrevTex[uv + int2(0, 1)].x + _PrevTex[uv + int2(-1, 0)].x + _PrevTex[uv + int2(0, -1)].x;
                float sum = (_PrevTex[uv].x + n) / 4.5;

                return float4(
                    clamp(sum, 0, 1),
                    depth01,
                    0,
                    0
                );
            }

            ENDCG
        }
    }
}
