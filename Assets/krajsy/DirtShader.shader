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

        [Space(10)]
        _DirtSurfaceY ("Dirt Surface Y", float) = 50
        _DirtBottomY ("Dirt Bottom Y", float) = 0

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

        sampler2D _MainTex;

        sampler2D _DirtTex_1;
        sampler2D _DirtTex_2;

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

        float _ViewDistance;

        float _DebugFloat;
        bool _DebugBool;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        // UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        // UNITY_INSTANCING_BUFFER_END(Props)

        float noiseStack(float2 pos, int octaves)
        {
            float output = 0;
            float amplitude = .5;

            static float2x2 rot = { cos(0.5), sin(0.5), -sin(0.5), cos(0.50) };

            for (int i = 0; i < octaves; i++)
            {
                output += noise(pos) * amplitude;
                pos = mul(rot, pos) * 2.0 + float2(100,100);
                amplitude *= .5;
            }

            output *= 1. / (1. - pow(.5, octaves));

            return output;
        }

        fixed4 AntiTile(sampler2D tex1, sampler2D tex2, fixed4 tint1, fixed4 tint2, float2 uv, float3 worldPos)
        {
            float2x2 rot = { cos(.5), sin(.5), -sin(.5), cos(.5) };

            fixed4 col1 = tex2D(tex1, uv) * tint1;
            fixed4 col2 = tex2D(tex2, mul(rot, uv)) * tint2;

            // float value = smoothstep(.3,.7, noise(worldPos.xz)*.5+.5);
            float value = noise(worldPos.xz)*.5+.5;

            return lerp(col1, col2, value);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 col = 0;

            float3 worldPos = IN.worldPos;

            fixed4 Dirt = AntiTile(_DirtTex_1, _DirtTex_2, _DirtColor_1, _DirtColor_2, IN.uv_DirtTex_1, worldPos / 30);

            col = Dirt;

            // col = lerp(Sand, Dirt, saturate(beachiness));
            // col = lerp(col, Stone, saturate(mountaininess));

            // col = lerp(Stone, col, pow(smoothstep(0, 1, dot(o.Normal, float3(0,1,0))), 2));
            // col = lerp(col, Snow, saturate(mountaininess - _SnowHeight - snowNoise) * pow(smoothstep(0, _SnowAngle, dot(o.Normal, float3(0,1,0))), _SnowExp));

            // col = sandNoise;

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
