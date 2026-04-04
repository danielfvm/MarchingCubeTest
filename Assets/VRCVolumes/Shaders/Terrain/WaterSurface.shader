Shader "Unlit/WaterSurface"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        [NoScaleOffset] _Cube ("Cubemap   (HDR)", Cube) = "grey" {}
        _FresnelPower ("Fresnel Power", Range(1, 8)) = 5
    }
    SubShader
    {
        ZWrite On
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "../../../krajsy/NoiseFunctions.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                uint vertexID : SV_VertexID;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 color : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
                float3 worldNormal : TEXCOORD4;
            };

            Texture2D<float4> _WaterState;

            sampler2D _CameraDepthTexture;
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            samplerCUBE _Cube;
            half4 _Cube_HDR;
            float _FresnelPower;

            float3 GetNormal(float3 worldPos, float epsilon)
            {
                // Current height
                float h = gnoise(worldPos.xz / 2.0 + _Time.x * 4.0);

                // Sample neighbors
                float hRight = gnoise((worldPos.xz + float2(epsilon, 0)) / 2.0 + _Time.x * 4.0);
                float hForward = gnoise((worldPos.xz + float2(0, epsilon)) / 2.0 + _Time.x * 4.0);

                // Compute gradient
                float dx = hRight - h;
                float dz = hForward - h;

                // Construct normal
                float3 normal = normalize(float3(-dx, 1.0, -dz));

                return normal;
            }

            v2f vert (appdata v)
            {
                uint2 dim;
                _WaterState.GetDimensions(dim.x, dim.y);

                uint vert = v.vertexID;// % (192 * 192);
                //uint top = v.vertexID / (192 * 192);

                uint2 uv = uint2(vert % dim.x, vert / dim.x);
                float4 state = _WaterState[uv];

                float4 worldPos = mul(unity_ObjectToWorld, v.vertex);

                v2f o;
                
                float waterSurfaceLevel = v.vertex.y - gnoise(worldPos.xz / 2 + _Time.x * 4) * 0.4 - 1 + state.x;

                v.normal = GetNormal(worldPos, 0.1);

                v.vertex.y = waterSurfaceLevel;

                float nearPlane = 0.0;
                float farPlane = 25.0;

                float depth01 = state.y;
                float depth = depth01 * (farPlane - nearPlane) + nearPlane - farPlane + 0.2;

                //if (top)
                //    v.vertex.y = min(waterSurfaceLevel, depth);
               // else
               //     v.vertex.y += 10;


                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.color = float3(state.x, 0, 0);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {

               // return float4(_Color.rgb, saturate(i.color.r) * _Color.a);

                // Normalize inputs
                float3 N = normalize(i.worldNormal);
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);

                // Reflection vector
                float3 R = reflect(-V, N);

                // Sample cubemap (skybox)
                half4 refl = texCUBE(_Cube, R);
                half3 reflection = DecodeHDR (refl, _Cube_HDR);

                // Fresnel
                float fresnel = pow(1.0 - saturate(dot(N, V)), _FresnelPower);

                // Final color
                float3 color = lerp(_Color.rgb, reflection, fresnel);

                return float4(color, saturate(i.color.r) * _Color.a);
            }
            ENDCG
        }
    }
}
