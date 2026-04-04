uint4 EncodeVertex(float3 position, float3 normal, uint color)
{
    uint3 qp = uint3(saturate(position) * 0x3FF);
    uint3 qn = uint3((normalize(normal) * 0.5 + 0.5) * 0x3FF);

    return asuint(float4(
        (qp.x | (qp.y << 10)) / float(0xFFFFF), 
        (qp.z | (qn.x << 10)) / float(0xFFFFF), 
        (qn.y | (qn.z << 10)) / float(0xFFFFF), 
        float(color) / float(0xFFFFF)
    ));
}

void DecodeVertex(float4 encoded, out float3 position, out float3 normal, out uint color)
{
    uint3 d = uint3(
        encoded.x * float(0xFFFFF) + 0.5,
        encoded.y * float(0xFFFFF) + 0.5,
        encoded.z * float(0xFFFFF) + 0.5
    );

    uint qp_x = d.x & 0x3FF;
    uint qp_y = (d.x >> 10) & 0x3FF;
    uint qp_z = d.y & 0x3FF;

    uint qn_x = (d.y >> 10) & 0x3FF;
    uint qn_y = d.z & 0x3FF;
    uint qn_z = (d.z >> 10) & 0x3FF;

    float3 p = (float3(qp_x, qp_y, qp_z)) * 64 / 62  / 0x3FF - 0.5;

    position = p; // TODO: Make this flexible!!!!
    normal   = float3(qn_x, qn_y, qn_z) / float(0x3FF) * 2.0 - 1.0;
    color = uint(encoded.w * float(0xFFFFF) + 0.5);
}


uint EncodeZOrder(uint2 coord)
{
    uint index = 0;

    // Interleave bits: X goes to even positions, Y goes to odd positions
    for (uint i = 0; i < 4; i++)
    {
        index |= ((coord.x >> i) & 1) << (2 * i);
        index |= ((coord.y >> i) & 1) << (2 * i + 1);
    }

    return index;
}

float2 DecodeVoxel(uint data)
{
    return float2(float(data >> 8) / 0xFFFF, data & 0xFF);
}

uint EncodeVoxel(float weight, uint color)
{
    return uint(saturate(weight) * 0xFFFF) << 8 | color; 
}


#ifdef ImplSample

float2 sample(int3 pos)
{
    #ifdef _CHUNKED_ON
    int3 p = clamp((pos * 2) / _VoxelDimension, 0, 1);

    pos -= (p * 2 - 1) * _VoxelDimension / 2;

    int index = pos.x + pos.y * _VoxelDimension.x + pos.z * _VoxelDimension.x * _VoxelDimension.y;
    int2 uv = int2(index % _DataSize.x, index / _DataSize.x);
    uint idx = p.x + p.y * 2 + p.z * 4;
    uint data = _DataTex[uv + uint2(idx % 2, idx / 2) * _DataSize];
    #else
    pos = clamp(pos, 0, _VoxelDimension - 1);
    uint index = pos.x + pos.y * _VoxelDimension.x + pos.z * _VoxelDimension.x * _VoxelDimension.y;
    uint2 uv = uint2(index % _DataSize.x, index / _DataSize.y);
    uint data = _DataTex[uv];
    #endif

    return DecodeVoxel(data); 
}

float sampleWeight(float3 pos)
{
    float w0 = sample(pos).r;
    float wX = lerp(w0, sample(pos + int3(1,0,0)).r, pos.x % 1.0);
    float wY = lerp(wX, sample(pos + int3(0,1,0)).r, pos.y % 1.0);
    float wZ = lerp(wY, sample(pos + int3(0,0,1)).r, pos.z % 1.0);

    return wZ; 
}

float3 sampleHighQualityNormal(float3 pos)
{
    float3 grad;
    grad.x = sampleWeight(pos + int3(1,0,0)).r - sampleWeight(pos + int3(-1,0,0)).r;
    grad.y = sampleWeight(pos + int3(0,1,0)).r - sampleWeight(pos + int3(0,-1,0)).r;
    grad.z = sampleWeight(pos + int3(0,0,1)).r - sampleWeight(pos + int3(0,0,-1)).r;
    return normalize(grad);
}

float3 sampleSimpleNormal(float3 pos)
{
    float w = sample(pos).r;
    return normalize(float3(
        sample(pos + int3(1,0,0)).r - w,
        sample(pos + int3(0,1,0)).r - w,
        sample(pos + int3(0,0,1)).r - w
    ));
}
#endif