Shader "Unlit/Test"
{
    Properties
    {
    }

    CGINCLUDE
    void DecodeVertex(float4 encoded, out float3 position, out float3 normal, out uint color)
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
        color = uint(encoded.w * float(0xFFFFF) + 0.5);
    }
    ENDCG

    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100

        Pass
        {
         //   AlphaToMask On
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma geometry geom

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR0;
            };

            struct v2g
            {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
                float3 color : TEXCOORD1;
            };

            struct g2f
            {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
                float3 color : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
            };

            v2g vert (appdata v)
            {
                v2g o;

                float3 normal;
                int colorIdx;
                DecodeVertex(v.color, v.vertex.xyz, normal, colorIdx);

                o.vertex = v.vertex;
                o.normal = normal;
                o.color = 1;


                return o;
            }

            [maxvertexcount(3)]
            void geom(point v2g input[1], inout TriangleStream<g2f> triStream)
            {
                g2f o;

                float4 vertex = input[0].vertex;
                float3 normal = input[0].normal;
                float3 color = input[0].color;
                
                for(int i = 0; i < 3; i++)
                {
                    float2 uv = float2(sin(i / 3.0 * 3.1415 * 2.0), -cos(i / 3.0 * 3.1415 * 2.0));

                    o.vertex = UnityObjectToClipPos(vertex) + float4(uv * 200.0 / _ScreenParams.xy, 0, 0);
                    o.normal = UnityObjectToWorldNormal(normal);
                    o.worldPos = vertex;
                    o.uv = uv;
                    o.color = color;
                    triStream.Append(o);
                }
                triStream.RestartStrip();
            }

            float3 SampleReflection(float3 dir)
            {
                dir = normalize(dir);

                float4 raw = UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, dir);
                return DecodeHDR(raw, unity_SpecCube0_HDR);
            }

            fixed4 frag (g2f i) : SV_Target
            {
                float a = 1.0 - pow(length(i.uv), 1.0) * 2.0;

                float3 viewDir = _WorldSpaceCameraPos - i.worldPos;
                float3 reflDir = reflect(-viewDir, i.normal);
                float3 c =  SampleReflection(reflDir); //dot(i.normal, 1.0) * 0.5 + 0.5;

                return float4(c,max(a * 0.05, 0));
            }
            ENDCG
        }
    }
}
