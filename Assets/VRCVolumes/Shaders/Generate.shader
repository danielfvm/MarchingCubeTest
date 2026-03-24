Shader "VRCVolume/Generate"
{
    CGINCLUDE    
    #include "UnityCG.cginc" 

    // Uniforms
    int3 _VoxelDimension;
    int3 _ChunkPos;
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

    void encode(int3 gridPos, inout float weight, inout uint color);

    uint frag (v2f IN) : SV_Target 
    { 
        uint2 uv = IN.uv * _TargetSize;
        uint voxelIndex = uv.x + uv.y * _TargetSize.x;
        
        int3 gridPos = int3(
            voxelIndex % _VoxelDimension.x, 
            (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
            (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
        ) + _ChunkPos * _VoxelDimension;

        float weight = 0;
        uint color = 0;

        encode(gridPos, weight, color);

        return uint(saturate(weight) * 0xFFFF) << 8 | color; 
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

            #include "../../krajsy/NoiseFunctions.cginc"

			void encode(int3 gridPos, inout float weight, inout uint color)
            { 
                float y = gnoise(gridPos * 0.1);
                float k = (gnoise(gridPos * 0.05) * 4.0 + 0.1); // mountain heights

                weight = clamp(y - gridPos.y * 0.1 * k - 2.0, 0, 1);

                //weight = clamp(-gridPos.y / 10.0 + (sin(gridPos.x * 0.1) + sin(gridPos.z * 0.1)) * 0.5 - 2.0, 0, 1);
                color = gridPos.y < -22 * y - 10 ? 0 : 1;
                //weight = 1.0 - distance(gridPos, 0) * 0.01;
            }

            ENDCG
        }
    }
}
