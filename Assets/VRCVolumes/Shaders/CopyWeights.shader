Shader "VRCVolume/CopyWeights"
{
    CGINCLUDE    
    struct v2f
    {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

    ENDCG
    
    SubShader
    {
        Pass
        {
            Name "CopySub"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc"

            // Uniforms
            Texture2D<uint> _DataTex;
            uint2 _TargetSize;
            uint _TextureIdx;

            v2f vert (appdata_base v)
            {
                v2f o;

                v.vertex.xy *= float2(0.5, 0.25);
                v.vertex.xy += float2(0.5, 0.25) * float2(_TextureIdx % 2, _TextureIdx / 2);

                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;

                return o;
            }

			uint frag (v2f IN) : SV_Target 
            { 
                return _DataTex[IN.uv * _TargetSize]; 
            }

            ENDCG
        }

        Pass
        {
            Name "Copy"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            
            #include "UnityCG.cginc" 

            Texture2D<uint> _DataTex;
            uint2 _TargetSize;

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;

                return o;
            }

			uint frag (v2f IN) : SV_Target 
            { 
                return _DataTex[IN.uv * _TargetSize]; 
            }

            ENDCG
        }

        Pass
        {
            Name "Clear"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "UnityCG.cginc" 

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;

                return o;
            }

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }
    }
}
