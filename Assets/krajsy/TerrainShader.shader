// This is just imported as a reference
Shader "krajsy/TerrainShader"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        _GrassTex_1 ("Grass Texture 1", 2D) = "green" {}
        _GrassColor_1 ("Grass 1 Color", Color) = (1,1,1,1)
        _GrassTex_2 ("Grass Texture 2", 2D) = "green" {}
        _GrassColor_2 ("Grass 2 Color", Color) = (1,1,1,1)
        // _SandTex_1 ("Sand Texture", 2D) = "yellow" {}
        _StoneTex_1 ("Stone Texture 1", 2D) = "gray" {}
        _StoneTex_2 ("Stone Texture 2", 2D) = "gray" {}
        // _SnowTex_1 ("Snow Texture", 2D) = "white" {}
        _SnowColor ("Snow Color", Color) = (1,1,1,1)
        _SandColor_1 ("Sand Color 1", Color) = (1,1,1,1)
        _SandColor_2 ("Sand Color 2", Color) = (1,1,1,1)

        [Space(10)]
        _BeachLevel ("Beach Level", float) = 0
        _BeachFade ("Beach Fade", float) = .5
        _BeachNoiseMul ("Beach Noise Multiply", float) = -1
        _BeachNoiseOffset ("Beach Noise Offset", float) = 0

        [Space(10)]
        _MountainLevel ("Mountain Level", float) = 50
        _MountainFade ("Mountain Fade", float) = .5
        _MountainNoiseMul ("Mountain Noise Multiply", float) = 1
        _MountainNoiseOffset ("Mountain Noise Offset", float) = 0

        [Space(10)]
        _SnowHeight ("Snow Height", float) = 10
        _SnowAngle ("Snow Angle", float) = .5
        _SnowExp ("Snow Exponent", float) = 12.5

        [Space(10)]
        _ViewDistance ("View Distance", float) = 1000

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

        sampler2D _GrassTex_1;
        sampler2D _GrassTex_2;
        // sampler2D _SandTex_1;
        sampler2D _StoneTex_1;
        sampler2D _StoneTex_2;
        // sampler2D _SnowTex_1;

        struct Input
        {
            float2 uv_MainTex;

            float2 uv_GrassTex_1;
            // float2 uv_SandTex_1;
            float2 uv_StoneTex_1;
            // float2 uv_StoneTex_2;
            // float2 uv_SnowTex_1;

            float3 worldPos;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        fixed4 _GrassColor_1;
        fixed4 _GrassColor_2;
        fixed4 _SnowColor;
        fixed4 _SandColor_1;
        fixed4 _SandColor_2;

        float _BeachLevel;
        float _BeachFade;
        float _BeachNoiseMul;
        float _BeachNoiseOffset;

        float _MountainLevel;
        float _MountainFade;
        float _MountainNoiseMul;
        float _MountainNoiseOffset;

        float _SnowHeight;
        float _SnowAngle;
        float _SnowExp;

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

        float3 SandTexture(float2 uv)
        {
            uv *= 10;
            float3 output = 0;

            float colorNoise = pow(noiseStack(uv, 3)*.5+.5, 4);

            output = lerp(_SandColor_2, _SandColor_1, colorNoise);

            output *= 1-pow(noiseStack(uv * 20, 2) *.5+.5, 4) *.5+.5;
            output *= 1-pow(noiseStack((uv + 1.12) * 20, 2) *.5+.5, 4) *.5+.5;
            output *= 1-pow(noiseStack((uv + 54.35) * 40, 2) *.5+.5, 4) *.5+.5;

            return output;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 col = 0;

            float3 worldPos = IN.worldPos;

            if (distance(_WorldSpaceCameraPos.xyz, worldPos.xyz)/_ViewDistance > 1)
            {
                discard;
            }

            fixed4 Grass = AntiTile(_GrassTex_1, _GrassTex_2, _GrassColor_1, _GrassColor_2, IN.uv_GrassTex_1, worldPos / 30);
            fixed4 Sand = 0;// AntiTile(_SandTex_1, IN.uv_SandTex_1, worldPos * .1);
            fixed4 Stone = AntiTile(_StoneTex_1, _StoneTex_2, 1, 1, IN.uv_StoneTex_1, worldPos / 20);
            // fixed4 Snow = AntiTile(_SnowTex_1, IN.uv_SnowTex_1, worldPos * .1);

            float distanceFadeAmount = pow(saturate(distance(worldPos, _WorldSpaceCameraPos) / 100), 2);

            // The *3 is a magic number, idk
            Sand.rgb = lerp(SandTexture(worldPos.xz * .1), _SandColor_2 *3, distanceFadeAmount);

            fixed4 Snow = (Sand.r + .3) * _SnowColor;

            float sandNoise = noiseStack(worldPos.xz * .01 + _BeachNoiseOffset, 2) *.5+.5;
            float mountainNoise = noiseStack(worldPos.xz * .01 + _MountainNoiseOffset, 2) *.5+.5;
            float snowNoise = noiseStack(worldPos.xz * .1 + _MountainNoiseOffset, 2) *.5+.5;

            float beachiness = (sandNoise * _BeachNoiseMul + worldPos.y - _BeachLevel) * _BeachFade;
            float mountaininess = (mountainNoise * _MountainNoiseMul + worldPos.y - _MountainLevel) * _MountainFade;

            col = lerp(Sand, Grass, saturate(beachiness));
            col = lerp(col, Stone, saturate(mountaininess));

            col = lerp(Stone, col, pow(smoothstep(0, 1, dot(o.Normal, float3(0,1,0))), 2));
            col = lerp(col, Snow, saturate(mountaininess - _SnowHeight - snowNoise) * pow(smoothstep(0, _SnowAngle, dot(o.Normal, float3(0,1,0))), _SnowExp));

            // col = sandNoise;

            col *= tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = col.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Alpha = col.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
