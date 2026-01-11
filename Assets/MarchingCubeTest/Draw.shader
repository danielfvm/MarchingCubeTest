Shader "GenerateMesh/Draw"
{
    CGINCLUDE
    #include "UnityCG.cginc"

    Texture2D<float> _PrevData;
    
    uint _VoxelAmount;
    uint2 dim;

    struct v2f
    {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

    float sample(uint3 pos)
    {
        uint index = pos.x + pos.y * _VoxelAmount + pos.z * _VoxelAmount * _VoxelAmount;
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
            Name "Paint"
            ZTest Always
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            float3 _Position;

			float compute(int3 gridPos)
            {
                float weight = sample(gridPos);
                float d = distance(gridPos, _Position);
                float p = max(1.0 - d * 0.2, 0) * 1.0;

                return saturate(max(weight, p));
            } 
            ENDCG
        }

        Pass
        {
            Name "Erase"
            ZTest Always
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            float3 _Position;

			float compute(int3 gridPos)
            {
                float weight = sample(gridPos);
                float d = distance(gridPos, _Position);
                float p = max(1.0 - d * 0.2, 0) * 1.0;

                return saturate(min(weight, 1.0 - p));
            } 
            ENDCG
        }

        Pass
        {
            Name "Reset"
            ZTest Always
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

			float compute(int3 grid)
            {
                return 0;
            } 
            ENDCG
        }
    }
}
