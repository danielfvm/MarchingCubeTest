Shader "krajsy/DirtShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        _DirtTex_1 ("Dirt Texture 1", 2D) = "green" {}
        _DirtColor_1 ("Dirt 1 Color", Color) = (1,1,1,1)
        _DirtTex_2 ("Dirt Texture 2", 2D) = "green" {}
        _DirtColor_2 ("Dirt 2 Color", Color) = (1,1,1,1)

        _TriWeights("Tri Weights", Vector) = (1,1,1,1)

        [Space(10)]
        _DirtSurfaceY ("Dirt Surface Y", float) = 50
        _DirtBottomY ("Dirt Bottom Y", float) = 0

        _NormalRounding ("Normal Rounding", float) = 1

        [Space(10)]
        _DebugFloat ("Debug Float", float) = 0
        [Toggle] _DebugBool ("Debug Bool", int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry-150" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        #include "NoiseFunctions.cginc"
        #include "TriplanarFunctions.cginc"

        sampler2D _MainTex;

        sampler2D _DirtTex_1;
        sampler2D _DirtTex_2;
        float4 _DirtTex_1_ST;

        struct Input
        {
            float2 uv_MainTex;

            float2 uv_DirtTex_1;

            float3 worldPos;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        fixed4 _DirtColor_1;
        fixed4 _DirtColor_2;

        fixed4 _TriWeights;

        float _NormalRounding;

        float _DebugFloat;
        bool _DebugBool;

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 col = 0;

            float3 worldPos = IN.worldPos;

            _TriWeights.xyz *= _TriWeights.w;

            float3 roundedNormal = normalize(round(o.Normal * _NormalRounding) / _NormalRounding);

            fixed4 Dirt = TriplanarSampleTest(_DirtTex_1, _DirtTex_1_ST.xy, _DirtTex_1_ST.zw, worldPos, roundedNormal) * _DirtColor_1;

            col = Dirt * _Color;

            col *= tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = col.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Occlusion = 1;
            o.Alpha = col.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
