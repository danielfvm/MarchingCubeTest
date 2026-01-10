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
        // Position
        /*uint p = data.x;
        uint3 qp = uint3(p & 1023u, (p >> 10) & 1023u, (p >> 20) & 1023u);
        position = float3(qp) / 1023.0;

        // Normal
        uint n = data.y;
        uint3 qn = uint3(n & 1023u, (n >> 10) & 1023u, (n >> 20) & 1023u);
        normal = float3(qn) / 1023.0;
        normal = normal * 2.0 - 1.0;
        normal = normalize(normal);*/

        // Step 1: Convert floats back to uint
    // Step 1: Convert float [0,1] back to uint16
    uint r = uint(encoded.r * 65535.0 + 0.5);
    uint g = uint(encoded.g * 65535.0 + 0.5);
    uint b = uint(encoded.b * 65535.0 + 0.5);

    uint qp_x = r & 0xFF;
    uint qp_y = (r >> 8) & 0xFF;
    uint qp_z = g & 0xFF;

    uint qn_x = (g >> 8) & 0xFF;
    uint qn_y = b & 0xFF;
    uint qn_z = (b >> 8) & 0xFF;

    position = float3(qp_x, qp_y, qp_z) / 255.0;
    normal   = float3(qn_x, qn_y, qn_z) / 255.0 * 2.0 - 1.0;
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
