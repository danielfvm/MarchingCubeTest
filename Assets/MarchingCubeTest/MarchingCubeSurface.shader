Shader "Custom/MarchingCubeSurface"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }

    CGINCLUDE
    void DecodeVertex(float4 encoded, out float3 position, out float3 normal)
    {
        uint3 d = uint3(
            encoded.x * float(0xFFFFF) + 0.5,
            encoded.y * float(0xFFFFF) + 0.5,
            encoded.z * float(0xFFFFF) + 0.5
        );

        uint qp_x = d.x & 0x3FF;
        uint qp_y = (d.x >> 10) & 0x3FF;
        uint qp_z = d.y & 0x3FF;

        uint qn_x = (d.y >> 10) & 0x3FF;
        uint qn_y = d.z & 0x3FF;
        uint qn_z = (d.z >> 10) & 0x3FF;

        position = float3(qp_x, qp_y, qp_z) / float(0x3FF) - 0.5;
        normal   = float3(qn_x, qn_y, qn_z) / float(0x3FF) * 2.0 - 1.0;
    }

    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float3 normal : NORMAL;
            float2 texcoord;
        };

        void vert (inout appdata_full v, out Input o) {
            UNITY_INITIALIZE_OUTPUT(Input, o);

            float3 normal;
            DecodeVertex(v.color, v.vertex.xyz, normal);

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
            fixed4 c = tex2D (_MainTex, IN.texcoord) * _Color;
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

                DecodeVertex(v.color, position, normal);
                
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
