Shader "Custom/MarchingCubeSurfaceLOD"
{
    Properties
    {
        _ColorPalette ("Color Palette", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        sampler2D _ColorPalette;
        float4 _ColorPalette_TexelSize;

        struct Input
        {
            float4 color;
        };

        void vert (inout appdata_full v, out Input o) {
            UNITY_INITIALIZE_OUTPUT(Input, o);

            uint colorIdx = uint(v.color.w * float(0xFF) + 0.5) - 1;

            o.color = tex2Dlod(_ColorPalette, float4((colorIdx + 0.5) * _ColorPalette_TexelSize.x, 0.5, 0, 0));
        }

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            o.Albedo = IN.color * _Color;
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
