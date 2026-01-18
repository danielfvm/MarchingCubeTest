Shader "GenerateMesh/Draw"
{
    CGINCLUDE
    #include "UnityCG.cginc"

    Texture2D<float> _PrevData;

    float3 _PositionFrom;
    float3 _PositionCenter;
    float3 _PositionTo;
    
    uint3 _Chunk;
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
        pos = clamp(pos + 2 - _Chunk * _VoxelAmount, 0, _VoxelAmount + 3);

        uint index = pos.x + pos.y * (_VoxelAmount + 4)  + pos.z * (_VoxelAmount + 4)  * (_VoxelAmount + 4);
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

    // https://iquilezles.org/articles/distfunctions/
    float sdCapsule(float3 p, float3 a, float3 b)
    {
        float3 pa = p - a;
        float3 ba = b - a;

        float h = saturate(dot(pa, ba) / dot(ba, ba));

        return length(pa - ba * h);
    }

    float sdBezier(float3 pos, float3 A, float3 B, float3 C)
    {
        float3 a = B - A;
        float3 b = A - 2.0 * B + C;
        float3 c = a * 2.0;
        float3 d = A - pos;

        float kk = 1.0 / dot(b, b);
        float kx = kk * dot(a, b);
        float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
        float kz = kk * dot(d, a);

        float res = 0.0;

        float p  = ky - kx * kx;
        float p3 = p * p * p;
        float q  = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
        float h  = q * q + 4.0 * p3;

        if (h >= 0.0)
        {
            h = sqrt(h);

            float2 x  = (float2(h, -h) - q) * 0.5;
            float2 uv = sign(x) * pow(abs(x), 1.0 / 3.0);

            float t = saturate(uv.x + uv.y - kx);

            float3 qpos = d + (c + b * t) * t;
            res = dot(qpos, qpos);
        }
        else
        {
            float z = sqrt(-p);
            float v = acos(q / (2.0 * p * z)) / 3.0;

            float m = cos(v);
            float n = sin(v) * 1.732050808; // sqrt(3)

            float3 t = saturate(float3(m + m, -n - m, n - m) * z - kx);

            float3 q1 = d + (c + b * t.x) * t.x;
            float3 q2 = d + (c + b * t.y) * t.y;

            res = min(dot(q1, q1), dot(q2, q2));
            // third root cannot be the closest
        }

        return sqrt(res);
    }

    float compute(int3 grid);

    float frag (v2f IN) : SV_Target
    {
        _PrevData.GetDimensions(dim.x, dim.y);

        uint2 uv = IN.uv * _TargetSize;
        uint voxelIndex = uv.x + uv.y * _TargetSize.x;

        // to also compute the border
        _VoxelAmount += 4;
        int3 gridPos = uint3(
            voxelIndex % _VoxelAmount, 
            (voxelIndex / _VoxelAmount) % _VoxelAmount, 
            (voxelIndex / _VoxelAmount) / _VoxelAmount
        );
        gridPos -= 2;
        _VoxelAmount -= 4;

        return /*floor(*/compute(gridPos + _Chunk * _VoxelAmount);// * 64) / 64.0; // Quantize to store multiple weights in one pixel might work but reduces quality, also requires to build mesh per color
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

			float compute(int3 gridPos)
            {
                float weight = sample(gridPos);

                #ifdef SHADER_API_MOBILE
                float p = 1.0 - sdCapsule(gridPos, _PositionFrom, _PositionTo) * 0.2;
                #else
                float p = 1.0 - sdBezier(gridPos, _PositionFrom, _PositionCenter, _PositionTo) * 0.2;
                #endif

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

			float compute(int3 gridPos)
            {
                float weight = sample(gridPos);

                #ifdef SHADER_API_MOBILE
                float p = 1.0 - sdCapsule(gridPos, _PositionFrom, _PositionTo) * 0.2;
                #else
                float p = 1.0 - sdBezier(gridPos, _PositionFrom, _PositionCenter, _PositionTo) * 0.2;
                #endif

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
