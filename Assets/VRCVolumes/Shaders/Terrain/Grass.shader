Shader "VoxelMesh/GrassFromArea"
{
    Properties
    {
        _MainTex ("Grass Texture", 2D) = "white" {}
        _Cutoff ("Alpha Cutoff", Range(0,1)) = 0.5
        _GrassHeight ("Grass Height", Range(0.1, 1)) = 0.3
        _GrassWidth ("Grass Width", Range(0.01, 0.3)) = 0.05
        _GrassDensityPerSquareMeter ("Grass Density per m²", Range(0, 1000)) = 100
        _WindSwayFrequency ("Wind Sway Frequency", Range(0, 5)) = 1.0
        _WindStrength ("Wind Strength", Range(0, 0.5)) = 0.1
        _MinHeight ("Grass Min Height", Float) = 1
        _MinYLevel ("Min Y Level", Float) = 0
        _CullDistance ("Grass Cull Distance", Float) = 50
        _SlopeThreshold ("Slope Threshold (Y Dot)", Range(0,1)) = 0.3
        _MaxBladesPerTriangle ("Max Blades Per Triangle", Range(1, 20)) = 6
        _GrassColor ("Grass Color", Color) = (0.3, 0.7, 0.3, 1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="AlphaTest" "LightMode"="ForwardBase" }
        AlphaToMask On
        Cull off
        LOD 200

        Pass
        {
            CGPROGRAM

            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma target 4.0

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            #include "../Volume.cginc"
            #include "../../../krajsy/NoiseFunctions.cginc"

            sampler2D _MainTex;
            sampler2D _GrassTintMap;
            float _Cutoff;
            float _GrassHeight;
            float _GrassWidth;
            float _GrassDensityPerSquareMeter;
            float _WindSwayFrequency;
            float _WindStrength;
            float _MinHeight;
            float _CullDistance;
            float _SlopeThreshold;
            float4 _GrassColor;
            int _MaxBladesPerTriangle;
            float _MinYLevel;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 color : COLOR;
            };

            struct v2g
            {
                float3 normal : NORMAL;
                float3 worldPos : TEXCOORD0;
                float color : TEXCOORD1;
            };

            struct g2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float fade : COLOR2;
                float4 diff : COLOR0;
                float3 ambient : COLOR1;
                SHADOW_COORDS(1) // put shadows data into TEXCOORD2
            };

            v2g vert (appdata v)
            {
                float3 normal;
                float3 position;
                uint color;

                DecodeVertex(v.color, position, normal, color);

                v2g o;
                o.normal = normalize(UnityObjectToWorldNormal(normal));
                o.worldPos = mul(unity_ObjectToWorld, float4(position, 1)).xyz;
                o.color = color;
 
                return o;
            }

            float Hash(float2 p)
            {
                return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
            }

            static const int MAX_BLADES = 3;

            [maxvertexcount(MAX_BLADES * 6)] // blades max * 6 vertices per quad
            void geom(triangle v2g input[3], inout TriangleStream<g2f> triStream)
            {
                // World-space triangle corners
                float3 A = input[0].worldPos;
                float3 B = input[1].worldPos;
                float3 C = input[2].worldPos;

                // Triangle normal and slope
                float3 edge1 = B - A;
                float3 edge2 = C - A;
                float3 triNormal = normalize(cross(edge1, edge2));

                // Skip steep triangles (slope too high)
                float slope = dot(triNormal, float3(0, 1, 0));
                if (slope < _SlopeThreshold) return;

                // Only render on grass
                if ((int)(input[0].color) != 1) return;

                // Camera distance culling
                float3 triCenter = (A + B + C) / 3.0;
                float dist = distance(triCenter, _WorldSpaceCameraPos);
                if (dist > _CullDistance) return;

                if (triCenter.y < _MinYLevel) return;

                // Estimate world-space triangle area
                float area = 0.5 * length(cross(edge1, edge2));

                // Compute how many blades to emit for this triangle
                //float vertexAlpha = (input[0].color.a + input[1].color.a + input[2].color.a) / 3.0;
                float expectedBlades = area * _GrassDensityPerSquareMeter;// * vertexAlpha;
                int bladeCount = min((int)(expectedBlades + 0.5), _MaxBladesPerTriangle);
                bladeCount = min(bladeCount, MAX_BLADES);
                if (bladeCount <= 0) return;

                // Grass orientation: up and right vectors
                float3 up = float3(0, 1, 0);

                float3 windDir = normalize(float3(gnoise(triCenter * 0.2) - 0.5, 0, gnoise((triCenter + 1) * 0.2) - 0.5));
                windDir.y = 0;

                float k = gnoise(triCenter * 2.0 + 1) * 1 - 0.3;
                _GrassHeight += k * 0.5;
                _GrassWidth += k * 0.25;

                if (_GrassHeight < 0.3)
                    return;

                for (int i = 0; i < bladeCount; i++)
                {
                    // Generate random barycentric coords inside triangle
                    float2 rand = float2(
                        Hash(triCenter.xz + i * 17.3),
                        Hash(triCenter.xz + i * 23.1 + 5.0)
                    );

                    if (rand.x + rand.y > 1.0) {
                        rand = 1.0 - rand;
                    }

                    // Convert to world-space position
                    float3 pos = rand.x * A + rand.y * B + (1.0 - rand.x - rand.y) * C;

                    // Ignore grass below minimum height
                    //if(pos.y < _MinHeight)
                    //    continue;

                    // Create a rotation angle per blade (based on blade index)
                    float randAngle = Hash(pos.xz + i * 11.123) * 6.2831853; // 0 to 2*PI

                    // Build rotation using sin/cos
                    float cosA = cos(randAngle);
                    float sinA = sin(randAngle);

                    // Basis vectors for rotation around Y (up)
                    float3 localRight = float3(cosA, 0, -sinA);
                    float3 localForward = float3(sinA, 0, cosA);

                    // Final rotated right vector
                    float3 right = localRight;

                    // Wind sway on top point
                    float sway = sin(_Time.y * _WindSwayFrequency + (1.0 + windDir.x * 0.3 + windDir.y * 0.3)) * _WindStrength;
                    float3 topPos = pos + up * _GrassHeight + windDir * sway;

                    // Compute grass quad corners
                    float3 v[4] = {
                        pos - right * _GrassWidth,
                        pos + right * _GrassWidth,
                        topPos + right * _GrassWidth,
                        topPos - right * _GrassWidth
                    };

                    float fade = saturate((_CullDistance - dist) * 0.5);

                    // the only difference from previous shader:
                    // in addition to the diffuse lighting from the main light,
                    // add illumination from ambient or light probes
                    // ShadeSH9 function from UnityCG.cginc evaluates it,
                    // using world space normal
                    float3 n = normalize(topPos - pos);
                    half nl = abs(dot(n, _WorldSpaceLightPos0.xyz));
                    float4 diff = nl * _LightColor0;
                    float3 ambient = ShadeSH9(half4(n,1));
                    
                    // Emit first triangle of quad
                    [unroll] for (int i = 0; i < 3; i++)
                    {
                        g2f o; 
                        o.uv = float2(i != 0, i == 2); 
                        o.fade = fade; 
                        o.diff = diff; 
                        o.ambient = ambient; 
                        o.pos = UnityWorldToClipPos(v[0]); 
                        TRANSFER_SHADOW(o); 
                        o.pos = UnityWorldToClipPos(v[i]); 
                        triStream.Append(o);
                    }

                    triStream.RestartStrip();
                    
                    // Emit second triangle of quad
                    [unroll] for (int i = 0; i < 3; i++)
                    {
                        g2f o; 
                        o.uv = float2(i == 0, i != 2); 
                        o.fade = fade; 
                        o.diff = diff; 
                        o.ambient = ambient; 
                        o.pos = UnityWorldToClipPos(v[0]); 
                        TRANSFER_SHADOW(o); 
                        o.pos = UnityWorldToClipPos(v[(i + 2) % 4]); 
                        triStream.Append(o);
                    }

                    triStream.RestartStrip();
                }
            }

            fixed4 frag(g2f i) : SV_Target
            {
                float4 tex = tex2D(_MainTex, i.uv);
                float grayscale = tex.r;

                float3 finalColor = _GrassColor.rgb * grayscale;

                fixed shadow = SHADOW_ATTENUATION(i);

                //return float4(finalColor * (i.diff * 0.95 + 0.05) * shadow, tex.a * i.fade * _GrassColor.a);
                
                fixed3 lighting = i.diff * shadow + i.ambient * i.diff;

                return float4(finalColor * (lighting * 0.95 + 0.05), tex.a * i.fade * _GrassColor.a);
            }

            ENDCG
        }
    }

    //FallBack "Diffuse"
}