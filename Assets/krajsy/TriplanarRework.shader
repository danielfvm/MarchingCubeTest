// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "krajsy/TriplanarRework"
{
    Properties
    {
        // _Color ("Color", Color) = (1,1,1,1)
        // _MainTex ("Albedo (RGB)", 2D) = "white" {}
        // _Glossiness ("Smoothness", Range(0,1)) = 0.5
        // _Metallic ("Metallic", Range(0,1)) = 0.0

        _ColorTint ("Color Tint", Color) = (1,1,1,1)
        _Color("Color", 2D) = "white" {}
        _ColorHueShift ("Color Hue Shift", Range(0,1)) = 0

        _ColorEmission ("Color Emission", float) = 0

		_Normal("Normal", 2D) = "white" {}
        _NormalStrength("Normal Strength", float) = 1
		_Metalness("Metalness", 2D) = "white" {}
        _MetalnessStrength("Metalness Strength", float) = 1
		_Roughness("Roughness", 2D) = "white" {}
        _RoughnessStrength("Roughness Strength", float) = 1
		_Ambientocclusion("Ambient occlusion", 2D) = "white" {}
        _AmbientocclusionStrength("Ambient occlusion Strength", float) = 1

		_Tiling("Tiling", Float) = 1
        _TriWeights("Tri Weights", Vector) = (1,1,1,1)

        [Space(20)]

        _ColorTwoTint ("Color Two Tint", Color) = (1,1,1,1)
        _ColorTwo ("Color Two", 2D) = "white" {}
        _ColorTwoHueShift ("Color Two Hue Shift", Range(0,1)) = 0

        _ColorTwoEmission ("Color Two Emission", float) = 0

        _NormalTwo("Normal Two", 2D) = "white" {}
        _NormalStrengthTwo("Normal Strength Two", float) = 1
        _MetalnessTwo("Metalness Two", 2D) = "white" {}
        _MetalnessStrengthTwo("Metalness Strength Two", float) = 1
        _RoughnessTwo("Roughness Two", 2D) = "white" {}
        _RoughnessStrengthTwo("Roughness Strength Two", float) = 1
        _AmbientocclusionTwo("Ambient occlusion Two", 2D) = "white" {}
        _AmbientocclusionStrengthTwo("Ambient occlusion Strength Two", float) = 1

        _TilingTwo("Tiling Two", Float) = 1
        _TriWeightsTwo("Tri Weights Two", Vector) = (1,1,1,1)

        _ColorTwoAngle ("Color Two Angle", Float) = 1
        //_ColorTwoProminence ("Color Two Prominence", Float) = 1

        _ColorTwoFalloff ("Color Two Falloff", Float) = 5.5

        [Space(10)]

        _NearClipDistance ("Near Clip Distance", Float) = 0.1
        _NearClipDistanceMultiplier ("Near Clip Distance Multiplier", Float) = 1
        _NearClipFadeSpeed ("Near Clip Fade Speed", Float) = 500

        _TestValue ("Test Value", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        fixed4 _ColorTint;
        sampler2D _Color;
        fixed _ColorHueShift;

        fixed _ColorEmission;

        sampler2D _Normal;
        fixed _NormalStrength;
        sampler2D _Metalness;
        fixed _MetalnessStrength;
        sampler2D _Roughness;
        fixed _RoughnessStrength;
        sampler2D _Ambientocclusion;
        fixed _AmbientocclusionStrength;

        fixed _Tiling;
        fixed4 _TriWeights;

        //--------------------------------------

        fixed4 _ColorTwoTint;
        sampler2D _ColorTwo;
        fixed _ColorTwoHueShift;

        fixed _ColorTwoEmission;

        sampler2D _NormalTwo;
        fixed _NormalStrengthTwo;
        sampler2D _MetalnessTwo;
        fixed _MetalnessStrengthTwo;
        sampler2D _RoughnessTwo;
        fixed _RoughnessStrengthTwo;
        sampler2D _AmbientocclusionTwo;
        fixed _AmbientocclusionStrengthTwo;

        fixed _TilingTwo;
        fixed4 _TriWeightsTwo;

        fixed _ColorTwoAngle;
        //fixed _ColorTwoProminence;

        fixed _ColorTwoFalloff;

        fixed _NearClipDistance;
        fixed _NearClipDistanceMultiplier;
        fixed _NearClipFadeSpeed;

        float _TestValue;

        struct Input
        {
            float2 uv_Color;
            float3 worldPos : TEXCOORD0;
        };

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        float3 RGBToHSV(float3 c)
        {
            float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            float4 p = lerp( float4( c.bg, K.wz ), float4( c.gb, K.xy ), step( c.b, c.g ) );
            float4 q = lerp( float4( p.xyw, c.r ), float4( c.r, p.yzx ), step( p.x, c.r ) );
            float d = q.x - min( q.w, q.y );
            float e = 1.0e-10;
            return float3( abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
        }

        float3 HSVToRGB(float3 c)
        {
            //c.x = frac(c.x);
            float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
            float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
            return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
        }

        float rand(float3 p)
        {
            return frac(sin(dot(p, float3(12.9898, 78.233, 45.164))) * 43758.5453);
        }

        fixed4 TriplanarSample(sampler2D _texture, float3 _weights, float3 _tiling, float3 _localPos, float3 _worldNormal)
        {
            float3 newNormal = 0;
            newNormal = pow(abs(_worldNormal.xyz), _weights.xyz);
            _worldNormal = normalize(newNormal);

            float3 minDot = 0;
            minDot.x = dot(_worldNormal, float3(1,0,0));
            minDot.y = dot(_worldNormal, float3(0,1,0));
            minDot.z = dot(_worldNormal, float3(0,0,1));
            minDot = min(minDot, 0.01);

            fixed4 result = 0;
            result += tex2D (_texture, _localPos.zy * _tiling) * minDot.x;
            result += tex2D (_texture, _localPos.xz * _tiling) * minDot.y;
            result += tex2D (_texture, _localPos.xy * _tiling) * minDot.z;

            result /= (minDot.x + minDot.y + minDot.z);

            return result; // / ((_weights.x + _weights.y + _weights.z)/3.0);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            //fixed4 color = tex2D (_Color, IN.uv_Color) * _ColorTint;
            
            float2 uv = IN.uv_Color;

            float3 worldPos = IN.worldPos;
            float3 baseWorldPos = mul (unity_ObjectToWorld, float4(0,0,0,1)).xyz;
            float3 localPos = worldPos - baseWorldPos;

            //color.rgb = IN.worldPos - baseWorldPos;
            //color.rgb = o.Normal;

            float cameraDist = length(_WorldSpaceCameraPos - worldPos);

            float3 custWorldPos = IN.uv_Color.xyx;

            _NearClipDistance *= _NearClipDistanceMultiplier;

            if (rand(worldPos) < 1-pow(cameraDist/_NearClipDistance, (_NearClipFadeSpeed*_NearClipDistance)))
            {
                discard;
            }

            _TriWeights.xyz *= _TriWeights.w;
            _TriWeightsTwo.xyz *= _TriWeightsTwo.w;

            fixed4 color = TriplanarSample(_Color, _TriWeights.xyz, _Tiling, localPos, o.Normal);
            fixed4 normalMap = TriplanarSample(_Normal, _TriWeights.xyz, _Tiling, localPos, o.Normal);
            fixed4 metalnessMap = TriplanarSample(_Metalness, _TriWeights.xyz, _Tiling, localPos, o.Normal);
            fixed4 roughnessMap = TriplanarSample(_Roughness, _TriWeights.xyz, _Tiling, localPos, o.Normal);
            fixed4 ambientocclusionMap = TriplanarSample(_Ambientocclusion, _TriWeights.xyz, _Tiling, localPos, o.Normal);

            fixed4 colorTwo = TriplanarSample(_ColorTwo, _TriWeightsTwo.xyz, _TilingTwo, localPos, o.Normal);
            fixed4 normalMapTwo = TriplanarSample(_NormalTwo, _TriWeightsTwo.xyz, _TilingTwo, localPos, o.Normal);
            fixed4 metalnessMapTwo = TriplanarSample(_MetalnessTwo, _TriWeightsTwo.xyz, _TilingTwo, localPos, o.Normal);
            fixed4 roughnessMapTwo = TriplanarSample(_RoughnessTwo, _TriWeightsTwo.xyz, _TilingTwo, localPos, o.Normal);
            fixed4 ambientocclusionMapTwo = TriplanarSample(_AmbientocclusionTwo, _TriWeightsTwo.xyz, _TilingTwo, localPos, o.Normal);

            float colorBlend = 
                    pow((dot(o.Normal,
                            float3(0,1,0))*.5+.5) * _ColorTwoAngle,
                        _ColorTwoFalloff);

            colorBlend = clamp(colorBlend, 0, 1);

            color.rgb = HSVToRGB(RGBToHSV(color.rgb) + float3(1,0,0)*_ColorHueShift)*_ColorTint;
            colorTwo.rgb = HSVToRGB(RGBToHSV(colorTwo.rgb) + float3(1,0,0)*_ColorTwoHueShift)*_ColorTwoTint;

            o.Albedo = lerp(color, colorTwo, colorBlend).rgb;
            
            // o.Emission = lerp(pow(color*_ColorTint, 1./_ColorEmission), 
            //                 pow(colorTwo*_ColorTwoTint, 1./_ColorTwoEmission), colorBlend);
            o.Emission = clamp(lerp(pow(color, 1./_ColorEmission), 
                            pow(colorTwo, 1./_ColorTwoEmission), colorBlend), 0.001, 1.);
            //o.Normal = normalMap.rgb * _NormalStrength;
            o.Metallic = lerp(metalnessMap * _MetalnessStrength, 
                            metalnessMapTwo * _MetalnessStrengthTwo, colorBlend);
            o.Smoothness = lerp(roughnessMap * _RoughnessStrength, 
                            roughnessMapTwo * _RoughnessStrengthTwo, colorBlend);
            o.Occlusion = lerp(ambientocclusionMap * _AmbientocclusionStrength, 
                            ambientocclusionMapTwo * _AmbientocclusionStrengthTwo, colorBlend);
            o.Alpha = color.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
