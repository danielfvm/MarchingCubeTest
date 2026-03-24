Shader "VRCVolume/Generate"
{
    Properties
    {
        _LUT_Tex ("Look up texture", 2D) = "white" {}
    }

    CGINCLUDE    
    #include "UnityCG.cginc" 

    sampler2D _LUT_Tex;
    // float4 _LUT_Tex_ST;

    // Uniforms
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

    void encode(int3 gridPos, inout float weight, inout uint color);

    uint frag (v2f IN) : SV_Target 
    { 
        uint2 uv = IN.uv * _TargetSize;
        uint voxelIndex = uv.x + uv.y * _TargetSize.x;
        
        int3 gridPos = int3(
            voxelIndex % _VoxelDimension.x, 
            (voxelIndex / _VoxelDimension.x) % _VoxelDimension.y, 
            (voxelIndex / _VoxelDimension.x) / _VoxelDimension.y
        ) + _ChunkPos * _VoxelDimension;

        float weight = 0;
        uint color = 0;

        encode(gridPos, weight, color);

        return uint(saturate(weight) * 0xFFFF) << 8 | color; 
    }

    ENDCG
    
    SubShader
    {
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            #include "../../krajsy/NoiseFunctions.cginc"

            // (-1, 1) -> (0, 1)
            float NOOToZO(float value)
            {
                return value * .5 + .5;
            }

            // (0, 1) -> (-1, 1)
            float ZOToNOO(float value)
            {
                return value * 2 - 1;
            }

            // (-1, 1) -> (a, b)
            float NOOToAB(float value, float a, float b)
            {
                return ((value + 1) * (a-b)) / 2 + b;
            }

            float sigmoid(float value, float transitionSmoothness, float offset)
            {
                return 1 / (1 + exp((offset-value)/transitionSmoothness));
            }

            static const float worldScale = 0.5;
            // static const float worldScale = 2;
            static const float heightOffset = -100.0;
            static const float seaLevel = 0.0;

            void krajsyTerrain(int3 gridPos, inout float weight, inout uint color)
            {
                // gridPos.y -= heightOffset;
                gridPos /= worldScale;

                float continentalness = NOOToZO(noise(gridPos.xz * 0.003 + float2(100, 50)));

                float weirdnessMask = saturate(ZOToNOO(gnoise(gridPos.xz * .01)));
                weirdnessMask = pow(weirdnessMask, 2) * sign(weirdnessMask);

                float weirdnessValue = gnoise(gridPos * .1) * 70;

                float density = -gridPos.y + heightOffset;
                density += tex2D(_LUT_Tex, float2(continentalness, 15/16. + .5/16)).r * 200;
                // density += weirdnessMask * weirdnessValue;

                // density = weirdnessValue;

                float densityOffset = 0;
                float densityTransition = 1;

                weight = sigmoid(density, densityTransition, densityOffset);
                // weight = 1 / (1 + exp((densityOffset - density)/densityTransition));

                color = gridPos.y < seaLevel ? 0 : 1;
                // color = gridPos.y < -22 * y - 10 ? 0 : 1;
            }

			void encode(int3 gridPos, inout float weight, inout uint color)
            { 
                krajsyTerrain(gridPos, weight, color);
                return;

                float y = gnoise(gridPos * 0.1);
                float k = (gnoise(gridPos * 0.05) * 4.0 + 0.1); // mountain heights

                weight = clamp(y - gridPos.y * 0.1 * k - 2.0, 0, 1);

                //weight = clamp(-gridPos.y / 10.0 + (sin(gridPos.x * 0.1) + sin(gridPos.z * 0.1)) * 0.5 - 2.0, 0, 1);
                color = gridPos.y < -22 * y - 10 ? 0 : 1;
                //weight = 1.0 - distance(gridPos, 0) * 0.01;
            }

            ENDCG
        }
    }
}
