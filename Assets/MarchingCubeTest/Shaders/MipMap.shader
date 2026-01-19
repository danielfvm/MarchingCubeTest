Shader "GenerateMesh/MipMap"
{
    CGINCLUDE
    #include "UnityCG.cginc"

    Texture2D<float> _PrevData;

    uint _VoxelAmount;
    uint2 _TargetSize;
    uint2 dim;

    struct v2f
    {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

    float2 sample(int3 pos)
    {
        uint index = pos.x + pos.y * _VoxelAmount + pos.z * _VoxelAmount  * _VoxelAmount;
        uint2 uv = uint2(index % dim.x, index / dim.y);

        uint value = _PrevData[uv] * 0xFFFFFF;
        float weight = float(value >> 8) / 0xFFFF;
        float color = (value & 0xFF) >> 1;

        return float2(weight, color);
    }

    float sample2(int3 pos)
    {
        uint index = pos.x + pos.y * _VoxelAmount + pos.z * _VoxelAmount  * _VoxelAmount;
        uint2 uv = uint2(index % dim.x, index / dim.y);
        return _PrevData[uv];
    }

    v2f vert (appdata_base v)
    {
        v2f o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.uv = v.texcoord;
        return o;
    }

    float compute(int3 grid);

    float frag (v2f IN) : SV_Target
    {
        _PrevData.GetDimensions(dim.x, dim.y);

        uint2 uv = IN.uv * _TargetSize;
        uint voxelIndex = uv.x + uv.y * _TargetSize.x;

        // to also compute the border
        int3 gridPos = uint3(
            voxelIndex % 20, 
            (voxelIndex / 20) % 20, 
            (voxelIndex / 20) / 20
        ) * 2;

        return compute(gridPos);
    }
    ENDCG

    SubShader
    {
        Pass
        {
            Name "MipMap"
            ZTest Always

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			float compute(int3 grid)
            {
                return sample2(grid); // makes this a bit unecassary
                /*float2 data = sample(grid + int3(0,0,0));
                float weight = (
                    data.r + 
                    sample(grid + int3(0,0,1)).r +
                    sample(grid + int3(0,1,0)).r + 
                    sample(grid + int3(0,1,1)).r + 
                    sample(grid + int3(1,0,0)).r + 
                    sample(grid + int3(1,0,1)).r + 
                    sample(grid + int3(1,1,0)).r + 
                    sample(grid + int3(1,1,1)).r
                ) / 8.0;

                uint color = uint(data.g);
                uint result = ((color << 1) & 0xFF) | (uint(saturate(weight) * 0xFFFF) << 8);

                return float(result) / 0xFFFFFF;*/
            } 
            ENDCG
        }
    }
}
