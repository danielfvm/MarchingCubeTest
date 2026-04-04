Shader "VRCVolume/SurfaceTextured"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Occlusion ("Occlusion", Range(0,1)) = 1.0
        
        [Space(40)]
        _DirtTex_1 ("Dirt Texture 1", 2D) = "green" {}
        _DirtColor_1 ("Dirt 1 Color", Color) = (1,1,1,1)
        [Normal] _DirtNormalTex_1 ("Dirt 1 Normal", 2D) = "bump" {}
        _DirtNormal_Strength_1 ("Normal Strength", Range(0,5)) = 1.0
        _DirtRoughnessTex_1 ("Dirt Roughness 1", 2D) = "white" {}
        _DirtOcclusionTex_1 ("Dirt Occlusion 1", 2D) = "white" {}
        _DirtOcclusion_Strength_1 ("Occlusion Strength", Range(0,1)) = 1.0

        [Space(40)]
        _DirtTex_2 ("Dirt Texture 2", 2D) = "green" {}
        _DirtColor_2 ("Dirt 2 Color", Color) = (1,1,1,1)
        [Normal] _DirtNormalTex_2 ("Dirt 2 Normal", 2D) = "bump" {}
        _DirtNormal_Strength_2 ("Normal Strength", Range(0,5)) = 1.0
        _DirtRoughnessTex_2 ("Dirt Roughness 2", 2D) = "white" {}
        _DirtOcclusionTex_2 ("Dirt Occlusion 2", 2D) = "white" {}
        _DirtOcclusion_Strength_2 ("Occlusion Strength", Range(0,1)) = 1.0

        [Space(20)]
        // _DirtSurfaceY ("Dirt Surface Y", float) = 50
        // _DirtBottomY ("Dirt Bottom Y", float) = 0

        [Space(10)]
        _WorldNoiseScale ("World Noise Scale", float) = 2
        _WorldNoiseInfluence ("World Noise Influence", Range(0,1)) = .5

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
        #pragma surface surf Standard fullforwardshadows vertex:vert worldnormal
        #pragma target 3.0

        #include "UnityCG.cginc"
        #include "../Volume.cginc"
        #include "../../../krajsy/TriplanarFunctions.cginc"
        #include "../../../krajsy/NoiseFunctions.cginc"

        #include "UnityStandardUtils.cginc"

        sampler2D _DirtTex_1;
        float4 _DirtTex_1_ST;
        fixed4 _DirtColor_1;
        sampler2D _DirtNormalTex_1;
        half _DirtNormal_Strength_1;
        sampler2D _DirtRoughnessTex_1;
        sampler2D _DirtOcclusionTex_1;
        half _DirtOcclusion_Strength_1;

        sampler2D _DirtTex_2;
        float4 _DirtTex_2_ST;
        fixed4 _DirtColor_2;
        sampler2D _DirtNormalTex_2;
        half _DirtNormal_Strength_2;
        sampler2D _DirtRoughnessTex_2;
        sampler2D _DirtOcclusionTex_2;
        half _DirtOcclusion_Strength_2;

        struct Input
        {
            float3 normal : NORMAL;
            float2 texcoord;
            float3 worldPos;
            float3 worldNormal;
            float color;
            INTERNAL_DATA
        };

        fixed4 _Color;
        half _Glossiness;
        half _Metallic;
        half _Occlusion;

        float _WorldNoiseScale;
        float _WorldNoiseInfluence;

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
            float3 outNormal = IN.normal;
            half outRoughness = 0;
            half outOcclusion = 0;

            float textureWeight = saturate(IN.color);

            float3 worldPos = IN.worldPos;
            // float3 worldNormal = WorldNormalVector(IN, float3(0,0,1));
            float4 objectOrigin = mul(unity_ObjectToWorld, float4(0.0,0.0,0.0,1.0) );
            float heightPoint = worldPos.y - objectOrigin.y;

            float3 roundedNormal = normalize(round(IN.normal * _NormalRounding) / _NormalRounding);

            float2 sampleUV = (GetTriplanarSampleUV(_DirtTex_1_ST.xy, _DirtTex_1_ST.zw, worldPos, roundedNormal));

            fixed4 Dirt = tex2D(_DirtTex_1, sampleUV);
            float3 DirtTangentNormal = UnpackNormal(tex2D(_DirtNormalTex_1, sampleUV));
            fixed4 DirtRoughness = tex2D(_DirtRoughnessTex_1, sampleUV);
            fixed4 DirtOcclusion = tex2D(_DirtOcclusionTex_1, sampleUV) * _DirtOcclusion_Strength_1 + (1 - _DirtOcclusion_Strength_1);

            fixed4 Grass = tex2D(_DirtTex_2, sampleUV);
            float3 GrassTangentNormal = UnpackNormal(tex2D(_DirtNormalTex_2, sampleUV));
            fixed4 GrassRoughness = tex2D(_DirtRoughnessTex_2, sampleUV);
            fixed4 GrassOcclusion = tex2D(_DirtOcclusionTex_2, sampleUV) * _DirtOcclusion_Strength_2 + (1 - _DirtOcclusion_Strength_2);

            DirtTangentNormal = normalize(float3(DirtTangentNormal.xy * _DirtNormal_Strength_1 * (1-textureWeight), DirtTangentNormal.z));
            GrassTangentNormal = normalize(float3(GrassTangentNormal.xy * _DirtNormal_Strength_2 * (textureWeight), GrassTangentNormal.z));

            col = lerp(Dirt, Grass, textureWeight) * _Color;
            outNormal = BlendNormals(outNormal, BlendNormals(DirtTangentNormal, GrassTangentNormal));
            outRoughness = lerp(DirtRoughness, GrassRoughness, textureWeight);
            outOcclusion = lerp(DirtOcclusion, GrassOcclusion, textureWeight);

            // col.rgb = outNormal;
            // if (_DebugBool) col.rgb = IN.normal;

            float simplexNoise = gnoise(worldPos / _WorldNoiseScale) * _WorldNoiseInfluence + (1-_WorldNoiseInfluence);
            col.rgb *= simplexNoise;

            o.Albedo = col.rgb;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Normal = outNormal;
            if (_DebugBool) o.Normal = IN.normal;
            o.Smoothness = outRoughness * _Glossiness;
            o.Occlusion = outOcclusion * _Occlusion;
            o.Alpha = 1;
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
            #include "../Volume.cginc"

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
