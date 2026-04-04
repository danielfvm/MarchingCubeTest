Shader "VRCVolume/Surface"
{
    Properties
    {
        _ColorPalette ("Color Palette", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        [Toggle(_SMOOTH_SHADING_ON)] _SmoothShading ("Smooth Shading", Float) = 1
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull Back
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows vertex:vert
        #pragma shader_feature _SMOOTH_SHADING_ON
        #pragma target 3.0

        #include "../Volume.cginc"

        sampler2D _MainTex;
        sampler2D _ColorPalette;
        float4 _ColorPalette_TexelSize;

        struct Input
        {
            float2 uv_MainTex;
            float3 normal : NORMAL;
            float2 texcoord;
            float3 worldPos;
            nointerpolation float4 color;
        };

        void vert (inout appdata_full v, out Input o) 
        {
            UNITY_INITIALIZE_OUTPUT(Input, o);

            float3 normal;
            uint colorIdx;
            DecodeVertex(v.color, v.vertex.xyz, normal, colorIdx);

            o.color = tex2Dlod(_ColorPalette, float4((colorIdx + 0.5) * _ColorPalette_TexelSize.x, 0.5, 0, 0));
            o.texcoord = v.texcoord;
            o.normal = UnityObjectToWorldNormal(normal);
        }

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = IN.color * _Color;

            #ifndef _SMOOTH_SHADING_ON
            float3 dpdx = ddx(IN.worldPos);
            float3 dpdy = ddy(IN.worldPos);
            
            IN.normal = -normalize(cross(dpdx, dpdy));
            #endif

            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Normal = IN.normal;
            o.Alpha = c.a;
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
