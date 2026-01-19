Shader "Custom/Preview"
{
    Properties
    {
        _ColorPalette ("Color Palette", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _ColorIndex ("Color Index", Float) = 0
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

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        sampler2D _ColorPalette;
        float4 _ColorPalette_TexelSize;

        UNITY_INSTANCING_BUFFER_START(Props)
            UNITY_DEFINE_INSTANCED_PROP(uint, _ColorIndex)
        UNITY_INSTANCING_BUFFER_END(Props) 

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            uint colorIndex = UNITY_ACCESS_INSTANCED_PROP(Props, _ColorIndex);

            o.Albedo = _Color * tex2D(_ColorPalette, float2((colorIndex + 0.5) * _ColorPalette_TexelSize.x, 0.5));
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
