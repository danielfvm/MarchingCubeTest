Shader "GenerateMesh/Draw"
{
    CGINCLUDE
    #include "UnityCG.cginc"

    Texture2D<float> _PrevData;

    float3 _PositionFrom;
    float3 _PositionCenter;
    float3 _PositionTo;
    float _Radius;
    float _ColorIdx;

    uint3 _Chunk;
    uint _VoxelAmount;
    uint2 _TargetSize;
    uint2 dim;

    struct v2f
    {
        float4 pos : SV_POSITION;
        float2 uv : TEXCOORD0;
    };

    void sample(int3 pos, out float weight, out uint color)
    {
        pos = clamp(pos + 2 - _Chunk * _VoxelAmount, 0, _VoxelAmount + 3);

        uint index = pos.x + pos.y * (_VoxelAmount + 4) + pos.z * (_VoxelAmount + 4)  * (_VoxelAmount + 4);
        uint2 uv = uint2(index % dim.x, index / dim.y);
        uint value = _PrevData[uv] * 0xFFFFFF;

        weight = float(value >> 8) / 0xFFFF;
        color = (value & 0xFF) >> 1;
    }

    v2f vert (appdata_base v)
    {
        v2f o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.uv = v.texcoord;
        return o;
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

    // https://iquilezles.org/articles/distfunctions/
    float sdCapsule(float3 p, float3 a, float3 b)
    {
        float3 pa = p - a;
        float3 ba = b - a;

        float h = saturate(dot(pa, ba) / dot(ba, ba));

        return length(pa - ba * h);
    }

    float sphere(float3 gridPos)
    {
        float iso = 0.5;
        float k = 0.3;
        float adjustedRadius = _Radius - iso / k;

        #ifdef SHADER_API_MOBILE
        return 1.0 - (sdCapsule(gridPos, _PositionFrom, _PositionTo) - adjustedRadius) * k;
        #else
        return 1.0 - (sdBezier(gridPos, _PositionFrom, _PositionCenter, _PositionTo) - adjustedRadius) * k;
        #endif
    }

    void compute(int3 grid, inout float weight, inout uint color);

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

        gridPos += _Chunk * _VoxelAmount;

        float weight;
        uint color;

        sample(gridPos, weight, color);
        compute(gridPos, weight, color);

        uint result = ((color << 1) & 0xFF) | (uint(saturate(weight) * 0xFFFF) << 8);

        return float(result) / 0xFFFFFF;
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

			void compute(int3 grid, inout float weight, inout uint color)
            {
                float p = sphere(grid);
                color = p > 0.5 ? _ColorIdx : color;

                weight = saturate(max(weight, p));
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

			void compute(int3 grid, inout float weight, inout uint color)
            {
                float p = sphere(grid);

                weight = saturate(min(weight, 1.0 - p));

                // Experimental subtraction mode
                // p = max(p - .5, 0.0);
                // weight = saturate(weight - p);
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

			void compute(int3 grid, inout float weight, inout uint color)
            {
                weight = 0;
                color = 0;
            } 
            ENDCG
        }
    }
}
