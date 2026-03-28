Shader "VRCVolume/VolumeSync"
{
    CGINCLUDE
    // TODO: Check for texture type
    Texture2D<uint> _SrcTex;
    Texture2D<uint> _RefTex;
    Texture2D<uint> _OriginalTex;
    uint2 _TargetSize;

    #include "UnityCG.cginc" 

    struct v2f
    {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

    v2f vert (appdata_base v)
    {
        v2f o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.uv = v.texcoord;

        return o;
    }
    ENDCG
    
    SubShader
    {
        ///// The following Passes are used for Serialization /////

        Pass
        {
            Name "Difference"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }

        Pass
        {
            Name "MipMap"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }

        Pass
        {
            Name "Active"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }

        Pass
        {
            Name "Compact"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }

        Pass
        {
            Name "Final"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }

        ///// The following Passes are used for Deserialization /////

        Pass
        {
            Name "Copy"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return _SrcTex[IN.uv * _TargetSize]; 
            }

            ENDCG
        }

        Pass
        {
            Name "Deserialize"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target 
            { 
                return 0; 
            }

            ENDCG
        }
    }
}
