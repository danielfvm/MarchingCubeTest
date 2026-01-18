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

    float sample(int3 pos)
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

        uint2 uv = IN.uv * dim;
        uint voxelIndex = uv.x + uv.y * dim.x;

        // to also compute the border
        int3 gridPos = uint3(
            voxelIndex % _VoxelAmount, 
            (voxelIndex / _VoxelAmount) % _VoxelAmount, 
            (voxelIndex / _VoxelAmount) / _VoxelAmount
        );

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
                return (
                    sample(grid + int3(0,0,0)) + 
                    sample(grid + int3(0,0,1)) +
                    sample(grid + int3(0,1,0)) + 
                    sample(grid + int3(0,1,1)) + 
                    sample(grid + int3(1,0,0)) + 
                    sample(grid + int3(1,0,1)) + 
                    sample(grid + int3(1,1,0)) + 
                    sample(grid + int3(1,1,1))
                ) / 8.0;
            } 
            ENDCG
        }
    }
}
