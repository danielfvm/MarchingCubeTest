Shader "VRCVolume/Paint"
{
    CGINCLUDE

    #include "UnityCG.cginc"
    #include "Volume.cginc"

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

    // Uniforms
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

    ENDCG

    SubShader
    {
        Pass
        {
            Name "Paint"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

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

                if (penWeight > 0.25)
                    weight = max(weight, penWeight);
                if (penWeight > 0.25)
                    color = _SphereColor;

                // weight: 0 = Air, 1 = Solid
				return EncodeVoxel(weight, color);
			}

            ENDCG
        }

        Pass
        {
            Name "Erase"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

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

                weight = min(weight, 1.0 - penWeight);

                // weight: 0 = Air, 1 = Solid
				return EncodeVoxel(weight, color);
			}

            ENDCG
        }

        Pass
        {
            Name "Smooth"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            float getWeight(int3 gridPos)
            {
                gridPos -= _ChunkPos * _VoxelDimension;
                uint idx = gridPos.x + gridPos.y * _VoxelDimension.x + gridPos.z * _VoxelDimension.x * _VoxelDimension.y;
                uint2 uv = uint2(idx % _TargetSize.x, idx / _TargetSize.x);
                uint data = _DataTex[uv];

				return DecodeVoxel(_DataTex[uv]).x;
            }

			uint frag (v2f IN) : SV_Target
			{
                uint2 uv = IN.uv * _TargetSize;
                uint voxelIndex = uv.x + uv.y * _TargetSize.x;

                // Prev data
                uint data = _DataTex[uv];
                float weight = float(data >> 8) / float(0xFFFF);
                uint color = data & 0xFF;

                int3 localPos = int3(
                    voxelIndex % _VoxelDimension.x, 
                    (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
                    (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
                );

                int3 gridPos = localPos + _ChunkPos * _VoxelDimension;

                float k = 3.0;
                float penWeight = clamp((_SphereRadius - sdCapsule(gridPos, _SphereFrom, _SphereTo)) / k + 0.5, 0, 1.0);

                if (penWeight > 0.25)
                { 
                    float w = 0.0;
                    float totalWeight = 0.0;

                    int kernel[3] = {1, 2, 1};

                    for (int x = -1; x <= 1; x++)
                    for (int y = -1; y <= 1; y++)
                    for (int z = -1; z <= 1; z++)
                    {
                        int3 samplePos = localPos + int3(x,y,z);

                        // check bounds
                        if (all(samplePos >= 0) && all(samplePos < _VoxelDimension))
                        {
                            float weight = kernel[x+1] * kernel[y+1] * kernel[z+1];
                            w += getWeight(samplePos + _ChunkPos * _VoxelDimension) * weight;
                            totalWeight += weight;
                        }
                    }

                    // normalize using only valid samples
                    if (totalWeight > 0.0)
                        w /= totalWeight;
                    weight = w;
                }

                // weight: 0 = Air, 1 = Solid
				return EncodeVoxel(weight, color);
			}

            ENDCG
        }
    }
}
