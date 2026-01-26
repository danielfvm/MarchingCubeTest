Shader "VolumetricPen/DualContouring"
{
    CGINCLUDE
    #include "UnityCG.cginc"

    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
    };

    Texture2D<uint> _Data;
    Texture2D<uint4> _IndexLookup; // TODO: try getting uint to work instead

    v2f vert (appdata_base v)
    {
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.texcoord;
        return o;
    }

    float sdBox( float3 p, float3 b )
    {
        float3 q = abs(p) - b;
        return length(max(q,0.0)) + min(max(q.x,max(q.y,q.z)),0.0);
    }

    float4x4 GetRotationMatrix(float x, float y, float z) 
    {
        // Pre-comute sin/cos values: (Idk if this helps lol)
        float sinX = sin(x); float cosX = cos(x);
        float sinY = sin(y); float cosY = cos(y);
        float sinZ = sin(z); float cosZ = cos(z);

        // Start with identity
        float4x4 rotation = float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);

        // 3D rotation
        float4x4 xRotation = float4x4(1,0,0,0, 0,cosX,sinX,0, 0,-sinX,cosX,0, 0,0,0,1);
        float4x4 yRotation = float4x4(cosY,0,-sinY,0, 0,1,0,0, sinY,0,cosY,0, 0,0,0,1);
        float4x4 zRotation = float4x4(cosZ,-sinZ,0,0, sinZ,cosZ,0,0, 0,0,1,0, 0,0,0,1);

        rotation = mul(zRotation, rotation); // Z
        rotation = mul(yRotation, rotation); // Y
        rotation = mul(xRotation, rotation); // X

        return rotation;
    }

    float4 ApplyRotation(float4 pos, float3 XYZRotation)
    {
        float4x4 rot4x4 = GetRotationMatrix(XYZRotation.x, XYZRotation.y, XYZRotation.z);
        return mul(rot4x4, pos);
    }

    float det(float3x3 mat)
    {
        float a = mat[0].x;
        float b = mat[0].y;
        float c = mat[0].z;

        float d = mat[1].x;
        float e = mat[1].y;
        float f = mat[1].z;

        float g = mat[2].x;
        float h = mat[2].y;
        float i = mat[2].z;

        return
            a * (e * i - f * h) -
            b * (d * i - f * g) +
            c * (d * h - e * g);
    }

    float getWeight(float3 coord)
    {
        //return sdBox(ApplyRotation(float4(coord - 30.0, 0.0), float3(30.0, 0.0, 45.0)).xyz, 5.0);
        //return sdBox(coord - 30.0, 5.0);

        return distance(coord, 32) * 0.08 - 2.0;
    }

    float3 getNormal(float3 coord)
    {
        float2 d = float2(0.01, 0);
        return normalize(float3(
            getWeight(coord + d.xyy) - getWeight(coord - d.xyy), 
            getWeight(coord + d.yxy) - getWeight(coord - d.yxy), 
            getWeight(coord + d.yyx) - getWeight(coord - d.yyx) 
        ));
    }

    ENDCG

    SubShader
    {
        Pass
        {
            Name "Vertices"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            void addEdge(float3 pos, inout float3x3 row, inout float mass, inout float3 mean, inout float3 atb)
            {
                float3 normal = getNormal(pos);
                row[0] += normal * normal.x;
                row[1] += normal * normal.y;
                row[2] += normal * normal.z;

                atb += normal * dot(pos, normal);
                mass += 1;
                mean += pos;
            }

            float adapt(float v0, float v1)
            {
                return (0.0 - v0) / (v1 - v0);
            }

            float4 frag (v2f IN) : SV_Target
            {
                uint2 _Dim;
                _Data.GetDimensions(_Dim.x, _Dim.y);

                _Dim = 512;

                uint2 uv = IN.uv * _Dim;
                uint index = uv.x + uv.y * _Dim.x;
                int3 gridPos = int3(index & 0x3F, (index >> 6) & 0x3F, (index >> 12) & 0x3F);
                float mass = 0;
                float3 mean = 0, atb = 0;

                float v[2][2][2];
                [unroll] for (int x = 0; x <= 1; x++)
                    [unroll] for (int y = 0; y <= 1; y++)
                        [unroll] for (int z = 0; z <= 1; z++)
                            v[x][y][z] = getWeight(gridPos + uint3(x, y, z));

                float3x3 row = 0;
                float iso = 0.0;

                [unroll] for (int x = 0; x <= 1; x++)
                    [unroll] for (int y = 0; y <= 1; y++)
                        if ((v[x][y][0] > iso) != (v[x][y][1] > iso))
                            addEdge(gridPos + float3(x, y, adapt(v[x][y][0], v[x][y][1])), row, mass, mean, atb);

                [unroll] for (int x = 0; x <= 1; x++)
                    [unroll] for (int z = 0; z <= 1; z++)
                        if ((v[x][0][z] > iso) != (v[x][1][z] > iso))
                            addEdge(gridPos + float3(x, adapt(v[x][0][z], v[x][1][z]), z), row, mass, mean, atb);

                [unroll] for (int y = 0; y <= 1; y++)
                    [unroll] for (int z = 0; z <= 1; z++)
                        if ((v[0][y][z] > iso) != (v[1][y][z] > iso))
                            addEdge(gridPos + float3(adapt(v[0][y][z], v[1][y][z]), y, z), row, mass, mean, atb);

                if (mass <= 1)
                    return 0;

                mean /= mass;

                float _det = det(row);
                if (abs(_det) < 1e-3)
                    return float4(mean / 64.0, 0.0);

                float3 c0 = cross(row[1], row[2]);
                float3 c1 = cross(row[2], row[0]);
                float3 c2 = cross(row[0], row[1]);

                float3 vertex = float3(dot(c0, atb), dot(c1, atb), dot(c2, atb)) / _det;

                //vertex = clamp(vertex, gridPos, gridPos + 1);

                if (any(vertex <= gridPos) || any(vertex >= gridPos + 1))
                    return float4(mean / 64.0, 0.0);//float4((vertex * 0.5 + mean * 0.5) / 64.0, 0.0);

                // TODO: Bounds check

                return float4(float3(vertex) / 64.0, 0.0);
            }
            ENDCG
        }

        Pass
        {
            Name "Indices"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            uint getIndex(uint3 pos)
            {
                uint2 dim;
                dim = 512; // _IndexLookup.GetDimensions(dim.x, dim.y); // TODO: Why does GetDimension not work?
                uint idx = pos.x | (pos.y << 6) | (pos.z << 12);
                uint2 uv = uint2(idx % dim.x, idx / dim.x);

                return _IndexLookup[uv].r;
            }
            
            uint4 swap(uint4 data, bool swap)
            {
                return swap ? data : data.wzyx;
            }

            static const uint3 lookup[3] = {
                uint3(1, 0, 0),
                uint3(0, 0, 1),
                uint3(0, 1, 0) 
            };

            static const uint4 offset[3] = {
                uint4(0, 0, 0, 0),
                uint4(1, 0, 0, 1),
                uint4(1, 1, 0, 0)
            };

            uint4 frag (v2f IN) : SV_Target
            {
                uint2 _Dim;
                _Data.GetDimensions(_Dim.x, _Dim.y);

                _Dim = 512;

                uint2 uv = IN.uv * _Dim;
                uint index = uv.x + uv.y * _Dim.x;
                int3 gridPos = int3(index & 0x3F, (index >> 6) & 0x3F, (index >> 12) & 0x3F);                
                
                uint2 localUV = IN.uv * 2.0 * _Dim - uv * 2;
                uint localIndex = localUV.x + localUV.y * 2;
                float iso = 0.0;

                bool solid1 = getWeight(gridPos) > iso;
                bool solid2 = getWeight(gridPos + lookup[localIndex]) > iso;
                bool face = solid1 != solid2 && localIndex < 3;

                uint a = localIndex;
                uint b = (localIndex + 1) % 3;
                uint c = (localIndex + 2) % 3;

                return swap(uint4(
                    getIndex(gridPos - uint3(offset[a].x, offset[b].x, offset[c].x)),
                    getIndex(gridPos - uint3(offset[a].y, offset[b].y, offset[c].y)),
                    getIndex(gridPos - uint3(offset[a].z, offset[b].z, offset[c].z)),
                    getIndex(gridPos - uint3(offset[a].w, offset[b].w, offset[c].w))
                ), solid2) * face;

                /*bool solid1 = getWeight(gridPos + uint3(0, 0, 0)) > iso;
                [forcecase] switch(localIndex) {
                    case 0:
                        if (gridPos.x > 0 || gridPos.y > 0) {
                            bool solid2 = getWeight(gridPos + uint3(0, 0, 1)) > iso;

                            if (solid1 != solid2) {
                                return swap(uint4(
                                    getIndex(gridPos - uint3(1, 1, 0)),
                                    getIndex(gridPos - uint3(0, 1, 0)),
                                    getIndex(gridPos - uint3(0, 0, 0)),
                                    getIndex(gridPos - uint3(1, 0, 0))
                                ), solid2);
                            }
                        }
                        break;
                    case 1:
                        if (gridPos.x > 0 || gridPos.z > 0) {
                            bool solid2 = getWeight(gridPos + uint3(0, 1, 0)) > iso;

                            if (solid1 != solid2) {
                                return swap(uint4(
                                    getIndex(gridPos - uint3(1, 0, 1)),
                                    getIndex(gridPos - uint3(0, 0, 1)),
                                    getIndex(gridPos - uint3(0, 0, 0)),
                                    getIndex(gridPos - uint3(1, 0, 0))
                                ), solid1); // for some reason solid1 here
                            }
                        }
                        break;
                    case 2:
                        if (gridPos.y > 0 || gridPos.z > 0) {
                            bool solid2 = getWeight(gridPos + uint3(1, 0, 0)) > iso;

                            if (solid1 != solid2) {
                                return swap(uint4(
                                    getIndex(gridPos - uint3(0, 1, 1)),
                                    getIndex(gridPos - uint3(0, 0, 1)),
                                    getIndex(gridPos - uint3(0, 0, 0)),
                                    getIndex(gridPos - uint3(0, 1, 0))
                                ), solid2);
                            }
                        }
                        break;
                    default:
                        return 0;
                }

                return 0;*/
            }
            ENDCG
        }
    }
}
