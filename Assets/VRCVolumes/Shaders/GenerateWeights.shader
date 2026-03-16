Shader "VRCVolume/GenerateWeights"
{
    CGINCLUDE

    #include "UnityCG.cginc"

    // Uniforms
    Texture2D<uint> _DataTex;
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

    ENDCG

    SubShader
    {
        Pass
        {
            Name "Line"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            float3 _SphereFrom, _SphereTo;
            float _SphereRadius;
            uint _SphereColor;

            float sdCapsule(float3 p, float3 a, float3 b)
            {
                float3 pa = p - a;
                float3 ba = b - a;

                float h = saturate(dot(pa, ba) / dot(ba, ba));

                return length(pa - ba * h);
            }

			uint frag (v2f IN) : SV_Target
			{
                uint2 uv = IN.uv * _TargetSize;
                uint voxelIndex = uv.x + uv.y * _TargetSize.x;

                // Prev data
                uint data = _DataTex[uv];
                float weight = float(data >> 8) / float(0xFFFF);
                uint color = data & 0xFF;

                int3 gridPos = int3(
                    voxelIndex % _VoxelDimension.x, 
                    (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
                    (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
                ) + _ChunkPos * _VoxelDimension;

                float k = 3.0;
                float penWeight = clamp((_SphereRadius - sdCapsule(gridPos, _SphereFrom, _SphereTo)) / k + 0.5, 0, 1.0);

                weight = max(weight, penWeight);
                if (penWeight > 0.5)
                    color = _SphereColor;

                // weight: 0 = Air, 1 = Solid
				return uint(weight * 0xFFFF) << 8 | color;
			}

            ENDCG
        }
    }
}
