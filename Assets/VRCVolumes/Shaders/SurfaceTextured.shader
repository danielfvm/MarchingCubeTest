Shader "VRCVolume/SurfaceTextured"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
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
        Cull Back
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert
        #pragma target 3.0

        #include "UnityCG.cginc"
        #include "Volume.cginc"
        #include "../../krajsy/TriplanarFunctions.cginc"
        #include "../../krajsy/NoiseFunctions.cginc"

        sampler2D _DirtTex_1;
        sampler2D _DirtTex_2;
        float4 _DirtTex_1_ST;
        float4 _DirtTex_2_ST;

        struct Input
        {
            float3 normal : NORMAL;
            float2 texcoord;
            float3 worldPos;
            float color;
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

        void vert (inout appdata_full v, out Input o) 
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);

            float3 normal;
            uint colorIdx;
            DecodeVertex(v.color, v.vertex.xyz, normal, colorIdx);

            o.color = colorIdx;
            o.texcoord = v.texcoord;
            o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
            o.normal = UnityObjectToWorldNormal(normal);
        }

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 col = 0;

            float3 worldPos = IN.worldPos;

            _TriWeights.xyz *= _TriWeights.w;

            float3 roundedNormal = normalize(round(IN.normal * _NormalRounding) / _NormalRounding);

            fixed4 Dirt = TriplanarSampleTest(_DirtTex_1, _DirtTex_1_ST.xy, _DirtTex_1_ST.zw, worldPos, roundedNormal) * _DirtColor_1;
            fixed4 Grass = TriplanarSampleTest(_DirtTex_2, _DirtTex_2_ST.xy, _DirtTex_2_ST.zw, worldPos, roundedNormal) * _DirtColor_2;

            col = lerp(Dirt, Grass, saturate(IN.color)) * _Color;

            o.Albedo = col.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Normal = IN.normal;
            o.Smoothness = _Glossiness;
            o.Occlusion = 1;
            o.Alpha = col.a;
        }
        ENDCG


        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            Cull Back

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            
            #include "UnityCG.cginc"
            #include "Volume.cginc"

            struct v2f
            {
                V2F_SHADOW_CASTER;
            };

            // Custom deformation logic
            v2f vert(appdata_full v)
            {
                v2f o;

                float3 normal;
                float3 position;
                uint color;

                DecodeVertex(v.color, position, normal, color);
                
                TRANSFER_SHADOW_CASTER(o);
                o.pos = UnityObjectToClipPos(float4(position, 0));

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
