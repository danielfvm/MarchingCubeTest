Shader "Custom/MarchingCubeSurface"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0

        _NormalRounding ("Normal Rounding", float) = 1
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
            float2 uv_MainTex;
            float3 normal : NORMAL;
            float2 texcoord;
            float3 worldPos;
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

        float3 projectOnPlane(float3 vec, float3 normal)
        {
            return vec - normal * dot(vec, normal);
        }

        #define mod(x, y) (x - y * floor(x / y))

        fixed4 TriplanarSampleTest(sampler2D _texture, float2 _tiling, float2 _offset, float3 _pos, float3 _worldNormal)
        {
            _worldNormal = normalize(_worldNormal);

            fixed4 result = 1;
            float3 normalUp = normalize(projectOnPlane(normalize(float3(0.0, 1.0, 0.01)), _worldNormal));
            // float3 normalRight = normalize(projectOnPlane(normalize(float3(1.0, 0.0, 0.01)), _worldNormal));
            float3 normalRight = normalize(cross(_worldNormal, normalUp));

            // result = tex2D(_texture, _pos.zy * _tiling);

            // result.rgb = normalUp;
            float3 posOnPlane = projectOnPlane(_pos, _worldNormal);
            float dist = length(posOnPlane);

            float RadToDeg = 180/3.141592;
            float degToRad = 3.141592/180;

            float xAngle = acos(dot(normalize(posOnPlane), normalRight));
            float xDist = dist * sin(90 * degToRad - xAngle)/sin(90 * degToRad);

            float yAngle = acos(dot(normalize(posOnPlane), normalUp));
            float yDist = dist * sin(90 * degToRad - yAngle)/sin(90 * degToRad);

            float2 localUv = mod(float2(xDist, yDist), 1.);

            result = tex2D(_texture, localUv * _tiling + _offset);

            // return fixed4(localUv.xy, 0, 1);
            // return mod(xDist, .3)/.3;
            // return (mod(xDist, .5) > .25 ? fixed4(1,0,0,0) : fixed4(0,1,0,0));
            // return (mod(yDist, .5) > .25 ? fixed4(1,0,0,0) : fixed4(0,1,0,0));

            return result; // / ((_weights.x + _weights.y + _weights.z)/3.0);
        }

        float _NormalRounding;

        float4 _MainTex_ST;

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // fixed4 c = tex2D (_MainTex, IN.texcoord) * _Color;

            float3 roundedNormal = round(IN.normal * _NormalRounding) / _NormalRounding;
            fixed4 c = TriplanarSampleTest(_MainTex, _MainTex_ST.xy, _MainTex_ST.zw, IN.worldPos, roundedNormal) * _Color;

            o.Albedo = c.rgb;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
            o.Normal = IN.normal;
            o.Alpha = c.a;
        }
        ENDCG

        Pass
        {
            Name "BlockView"
            Tags { "RenderType"="Opaque" }

            ZWrite On
            ZTest LEqual
            Cull Front

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #include "UnityLightingCommon.cginc"

            fixed4 _Color;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD0;
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
                o.normal = normal;

                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                fixed3 color = _Color.rgb * (_LightColor0.rgb * 0.1); // add ambient
                return fixed4(color, 1);
            }
            ENDCG
        }

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
