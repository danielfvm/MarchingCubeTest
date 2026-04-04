Shader "VRCVolume/SurfaceTextured_SuperPackedMaps"
{
    Properties
    {
        [Header(General Settings)]
        [Space(5)]
        _Color ("Color", Color) = (1,1,1,1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _Occlusion ("Occlusion", Range(0,1)) = 1.0

        [Space(20)]
        [Header(Textures)]
        [Space(5)]
        _AlbedoDisplacementTex ("Albedo Displacement Texture", 2D) = "green" {}
        _NormalOcclusionRoughnessTex ("Normal Occlusion Roughness Texture", 2D) = "white" {}
        
        [Space(20)]
        [Header(Triplanar Settings)]
        [Space(5)]
        _WorldNoiseScale ("World Noise Scale", float) = 2
        _WorldNoiseInfluence ("World Noise Influence", Range(0,1)) = .5
        _NormalRounding ("Normal Rounding", float) = 1

        [Space(20)]
        [Header(Debug)]
        [Space(5)]
        [Toggle(DEBUG_DISPLAY_NORMALS_ON)] _Debug_DisplayNormals ("Debug Display Normals", int) = 0
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry-150" }
        Cull Back
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert
        #pragma multi_compile _ DEBUG_DISPLAY_NORMALS_ON
        #pragma target 3.0

        #include "UnityCG.cginc"
        #include "../Volume.cginc"
        #include "../../../krajsy/TriplanarFunctions.cginc"
        #include "../../../krajsy/NoiseFunctions.cginc"

        #include "UnityStandardUtils.cginc"

        float4 _AlbedoDisplacementTex_ST;
        sampler2D _AlbedoDisplacementTex;
        sampler2D _NormalOcclusionRoughnessTex;


        struct Input
        {
            float3 normal : NORMAL;
            float2 texcoord;
            float3 worldPos;
            float4 type;
        };

        // General Settings
        fixed4 _Color;
        half _Glossiness;
        half _Metallic;
        half _Occlusion;

        // Triplanar Settings
        float _WorldNoiseScale;
        float _WorldNoiseInfluence;
        float _NormalRounding;

        // Debug
        bool _Debug_DisplayNormals;

        void vert (inout appdata_full v, out Input o) 
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);

            float3 normal;
            uint colorIdx;
            DecodeVertex(v.color, v.vertex.xyz, normal, colorIdx);

            float4 worldPos = mul(unity_ObjectToWorld, v.vertex);

            // This prevents floating point precision errors between chunks causing gaps
            worldPos.xyz = round(worldPos.xyz * 500.0) / 500.0;

            o.type = float4(colorIdx == 0, colorIdx == 1, colorIdx == 2, colorIdx == 3);
            o.texcoord = v.texcoord;
            o.normal = UnityObjectToWorldNormal(normal);
            o.worldPos = worldPos.xyz;
            v.vertex.xyz = mul(unity_WorldToObject, worldPos);
        }

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Setup input values
            float3 worldPos = IN.worldPos;
            float3 worldNormal = IN.normal;
            // float4 objectPos = IN.objectPos;

            // Setup output values
            fixed3 outAlbedo = 0;
            float3 outNormal = worldNormal;
            half outRoughness = 0;
            half outOcclusion = 1;

            // Texture interpolaion value
            //float textureWeight = saturate(IN.color - 0.75 + outNormal.y);

            // Round the world normal to get smoothed sample direction
            float3 roundedNormal = normalize(round(worldNormal * _NormalRounding) / _NormalRounding);

            // Get the sample coordinates just once for all textures
            float2 sampleUV = frac(GetTriplanarSampleUV(1, 0, worldPos, roundedNormal));

            uint idx0 = IN.type.x ? 0 : (IN.type.y ? 1 : (IN.type.z ? 2 : 3));
            uint idx1 = IN.type.w ? 3 : (IN.type.z ? 2 : (IN.type.y ? 1 : 0));

            float2 scale = float2(_AlbedoDisplacementTex_ST.y / _AlbedoDisplacementTex_ST.x, 1.0);
            fixed4 albedoDisplacement0 = tex2D(_AlbedoDisplacementTex, (sampleUV + idx0) / scale);
            fixed4 normalOcclusionRoughness0 = tex2D(_NormalOcclusionRoughnessTex, (sampleUV + idx0) / scale);
            float3 normal0 = UnpackNormal(float4(normalOcclusionRoughness0.xy, 1 - length(normalOcclusionRoughness0.xy), 0));

            fixed4 albedoDisplacement1 = tex2D(_AlbedoDisplacementTex, (sampleUV + idx1) / scale);
            fixed4 normalOcclusionRoughness1 = tex2D(_NormalOcclusionRoughnessTex, (sampleUV + idx1) / scale);
            float3 normal1 = UnpackNormal(float4(normalOcclusionRoughness1.xy, 1 - length(normalOcclusionRoughness1.xy), 0));
            
            outAlbedo = lerp(albedoDisplacement0.rgb, albedoDisplacement1.rgb, IN.type[idx1]);
         //   outNormal = BlendNormals(outNormal, BlendNormals(normal0, normal1));
            outOcclusion = lerp(normalOcclusionRoughness0.z, normalOcclusionRoughness1.z, IN.type[idx1]);
            outRoughness = lerp(normalOcclusionRoughness0.w, normalOcclusionRoughness1.w, IN.type[idx1]);

            /*
            // Sample the textures
            fixed4 Dirt = tex2D(_DirtTex_1, sampleUV);
            float3 DirtTangentNormal = UnpackNormal(tex2D(_DirtNormalTex_1, sampleUV));
            float3 DirtAoDisRough = tex2D(_Dirt_AO_Dis_Rough_Tex_1, sampleUV) * float3(_DirtOcclusion_Strength_1, 1, 1) + float3(1 - _DirtOcclusion_Strength_1, 0, 0);

            fixed4 Grass = tex2D(_DirtTex_2, sampleUV);
            float3 GrassTangentNormal = UnpackNormal(tex2D(_DirtNormalTex_2, sampleUV));
            float3 GrassAoDisRough = tex2D(_Dirt_AO_Dis_Rough_Tex_2, sampleUV) * float3(_DirtOcclusion_Strength_2, 1, 1) + float3(1 - _DirtOcclusion_Strength_2, 0, 0);

            // Set normal map strengths
            DirtTangentNormal = normalize(float3(DirtTangentNormal.xy * _DirtNormal_Strength_1 * (1-textureWeight), DirtTangentNormal.z));
            GrassTangentNormal = normalize(float3(GrassTangentNormal.xy * _DirtNormal_Strength_2 * (textureWeight), GrassTangentNormal.z));

            // Apply textures to outputs
            outColor = lerp(Dirt, Grass, textureWeight) * _Color;
            outNormal = BlendNormals(outNormal, BlendNormals(DirtTangentNormal, GrassTangentNormal));
            outRoughness = lerp(DirtAoDisRough.z, GrassAoDisRough.z, textureWeight);
            outOcclusion = lerp(DirtAoDisRough.x, GrassAoDisRough.x, textureWeight);
            */

            // Apply world noise to give slightly more texture on a larger scale
            float simplexNoise = gnoise(worldPos / _WorldNoiseScale) * _WorldNoiseInfluence + (1-_WorldNoiseInfluence);
            outAlbedo.rgb *= simplexNoise;

            // Debug
            #ifdef DEBUG_DISPLAY_NORMALS_ON
            outAlbedo.rgb = outNormal;
            #endif

            o.Albedo = outAlbedo.rgb;
            o.Metallic = _Metallic;
            o.Normal = outNormal;
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
