Shader "PacketAsset/Packer"
{
    CGINCLUDE
    
    #include "UnityCG.cginc"

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
    };

    sampler2D _AlbedoTex;
    sampler2D _NormalTex;
    sampler2D _OcclusionTex;
    sampler2D _DisplacementTex;
    sampler2D _RoughnessTex;

    int _Count;
    int _Index;
    
    v2f vert (appdata v)
    {
        v2f o;
        v.vertex.x /= float(_Count);
        v.vertex.x += 1.0 / float(_Count) * _Index;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;
        return o;
    }

    ENDCG

    SubShader
    {
        Pass
        {
            Name "AlbedoDisplacement"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            fixed4 frag (v2f i) : SV_Target
            {
                return float4(tex2D(_AlbedoTex, i.uv).rgb, tex2D(_DisplacementTex, i.uv).r);
            }
            ENDCG
        }

        Pass
        {
            Name "NormalOcclusionRoughness"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            fixed4 frag (v2f i) : SV_Target
            {
                return float4(tex2D(_NormalTex, i.uv).rg, tex2D(_OcclusionTex, i.uv).r, tex2D(_RoughnessTex, i.uv).r);
            }
            ENDCG
        }
    }
}
