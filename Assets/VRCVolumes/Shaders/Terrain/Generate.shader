Shader "VRCVolume/Generate"
{
    Properties
    {
        _LUT_Tex ("Look up texture", 2D) = "white" {}
    }

    CGINCLUDE    
    #include "UnityCG.cginc" 
    #include "../Volume.cginc"

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

        return EncodeVoxel(weight, color); 
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

            #include "../../../krajsy/NoiseFunctions.cginc"

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

            #define SampleArray(a, s) (lerp(a[floor(s * (a.Length - 1))], a[ceil(s * (a.Length - 1))], frac(s * (a.Length - 1))))

            static const float worldScale = 0.2;
            // static const float worldScale = 2;
            static const float heightOffset = -100.0;
            static const float seaLevel = 0.0;

            // static const float continentalnessLUT[10] = {0, 0, 0, 0, 0, 1, 1, 1, 1, 1};
            float continentalnessLUT[24];

            void krajsyTerrain(int3 gridPos, inout float weight, inout uint color)
            {
                // gridPos.y -= heightOffset;
                gridPos /= worldScale;

                float continentalness = NOOToZO(noise(gridPos.xz * 0.003));

                float weirdnessMask = saturate(ZOToNOO(gnoise(gridPos.xz * .01)));
                weirdnessMask = pow(weirdnessMask, 2) * sign(weirdnessMask);

                float weirdnessValue = gnoise(gridPos * .1) * 70;

                
                float density = -gridPos.y + heightOffset;
                // density += tex2D(_LUT_Tex, float2(continentalness, 15/16. + .5/16)).r * 200;
                density += SampleArray(continentalnessLUT, continentalness) * 200;
                // density += weirdnessMask * weirdnessValue;

                float densityOffset = 0;
                float densityTransition = 2;

                weight = sigmoid(density, densityTransition, densityOffset);
                // weight = 1 / (1 + exp((densityOffset - density)/densityTransition));

                color = gridPos.y < seaLevel ? 0 : 1;
                // color = gridPos.y < -22 * y - 10 ? 0 : 1;
            }

			void encode(int3 gridPos, inout float weight, inout uint color)
            {
                // krajsyTerrain(gridPos, weight, color); return;

                float r = gnoise(gridPos);
                float r2 = gnoise(gridPos * 0.1 + 1);
                float y = gnoise(gridPos * 0.1);

                y += gnoise(float3(gridPos.x, 0, gridPos.z) * 0.02 + 1) * 10 - 5;

                float k = (gnoise(gridPos * 0.05) * 4.0 + 0.1); // mountain heights

                weight = clamp(y - gridPos.y * 0.1 * k - 2.0, 0, 1);

                //weight = clamp(-gridPos.y / 10.0 + (sin(gridPos.x * 0.1) + sin(gridPos.z * 0.1)) * 0.5 - 2.0, 0, 1);
                color = 1;

                if (gridPos.y < -13 + y * 10 && r > (gridPos.y - (-15 + y * 10)) / 2.0)
                    color = 2;
                if (r2 < 0.2)
                    color = 0;
                if (gridPos.y < -15 + y * 10)
                    color = 2;
                
                if (gridPos.y < -20 + y * 10 && r > (gridPos.y - (-25 + y * 10)) / 5.0)
                    color = 0;

                if (gridPos.y < -25 + y * 10 &&r > (gridPos.y - (-30 + y * 10)) / 5.0)
                    color = 3;
                if (gridPos.y < -30 + y * 10)
                    color = 3;

                //weight = 1.0 - distance(gridPos, 0) * 0.01;
            }

            ENDCG
        }
    }
    CustomEditor "WorldLUTGenerator"
}
