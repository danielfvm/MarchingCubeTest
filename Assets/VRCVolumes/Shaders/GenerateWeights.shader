Shader "VRCVolume/GenerateWeights"
{
    CGINCLUDE

    #include "UnityCG.cginc"

    // Uniforms
    uint3 _VoxelDimension;
    uint2 _TargetSize;

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
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			uint frag (v2f IN) : SV_Target
			{
                uint2 uv = IN.uv * _TargetSize;
                uint voxelIndex = uv.x + uv.y * _TargetSize.x;

                int3 gridPos = uint3(
                    voxelIndex % _VoxelDimension.x, 
                    (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
                    (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
                );

                float weight = clamp(1.0 - distance(gridPos, _VoxelDimension / 2.0) / _VoxelDimension * 1.1, 0, 1);
                uint color = 2; // An index of the color pallete texture, see MarchingCubeSurface.shader

                uint data = uint(weight * 0xFFFF) << 8 | color;

				return data;
			}

            ENDCG
        }
    }
}
