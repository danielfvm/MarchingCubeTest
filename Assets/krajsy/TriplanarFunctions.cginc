
fixed4 TriplanarSample(sampler2D _texture, float3 _weights, float3 _tiling, float3 _pos, float3 _worldNormal)
{
	float3 newNormal = 0;
	newNormal = pow(abs(_worldNormal.xyz), _weights.xyz);
	_worldNormal = normalize(newNormal);

	float3 minDot = 0;
	minDot.x = dot(_worldNormal, float3(1,0,0));
	minDot.y = dot(_worldNormal, float3(0,1,0));
	minDot.z = dot(_worldNormal, float3(0,0,1));
	minDot = min(minDot, 0.01);

	fixed4 result = 0;
	result += tex2D(_texture, _pos.zy * _tiling) * minDot.x;
	result += tex2D(_texture, _pos.xz * _tiling) * minDot.y;
	result += tex2D(_texture, _pos.xy * _tiling) * minDot.z;

	result /= (minDot.x + minDot.y + minDot.z);

	return result; // / ((_weights.x + _weights.y + _weights.z)/3.0);
}

float3 projectOnPlane(float3 vec, float3 normal)
{
    return vec - normal * dot(vec, normal);
}

#define mod(x, y) (x - y * floor(x / y))

float2 GetTriplanarSampleUV(float2 _tiling, float2 _offset, float3 _pos, float3 _worldNormal)
{
	// _worldNormal = normalize(_worldNormal);

	fixed4 result = 1;
	float3 normalUp = normalize(projectOnPlane(normalize(float3(0.0, 1.0, 0.01)), _worldNormal));
	float3 normalRight = normalize(cross(_worldNormal, normalUp));

	float3 posOnPlane = projectOnPlane(_pos, _worldNormal);
	float dist = length(posOnPlane);

	float xAngle = acos(dot(normalize(posOnPlane), normalRight));
	float xDist = dist * sin(1.570796 - xAngle);

	float yAngle = acos(dot(normalize(posOnPlane), normalUp));
	float yDist = dist * sin(1.570796 - yAngle);

	float2 localUv = float2(xDist, yDist);

	// result = tex2D(_texture, localUv * _tiling + _offset);

	return localUv * _tiling + _offset;
}

fixed4 TriplanarSampleTest(sampler2D _texture, float2 _tiling, float2 _offset, float3 _pos, float3 _worldNormal)
{
	return tex2D(_texture, GetTriplanarSampleUV(_tiling, _offset, _pos, _worldNormal));
}
