Shader "GenerateMesh/MipMap2"
{
    CGINCLUDE
    #include "UnityCustomRenderTexture.cginc"

    sampler2D _DataTex;

    // Pack a uint into a float4 (each channel 0..1 representing 0..255)
    float4 PackUIntToFloat4(uint value)
    {
        float4 result;

        result.r = (value & 0xFF) / 255.0;         // lowest byte
        result.g = ((value >> 8) & 0xFF) / 255.0;  // 2nd byte
        result.b = ((value >> 16) & 0xFF) / 255.0; // 3rd byte
        result.a = 1.0; // highest byte

        return result;
    }

    // Unpack a float4 back into a uint
    uint UnpackFloat4ToUInt(float4 packed)
    {
        uint r = (uint)(packed.x * 255.0 + 0.); // add 0.5 for proper rounding
        uint g = (uint)(packed.y * 255.0 + 0.);
        uint b = (uint)(packed.z * 255.0 + 0.);

        return r | (g << 8) | (b << 16);
    }

    float4 sample(float2 pos)
    {
        float3 ts = float3(1.0 / _CustomRenderTextureInfo.xy, 0.0);
        pos -= ts / 2.0;
        uint o1 = UnpackFloat4ToUInt(tex2D(_SelfTexture2D, pos + ts.zz));
        uint o2 = UnpackFloat4ToUInt(tex2D(_SelfTexture2D, pos + ts.xz));
        uint o3 = UnpackFloat4ToUInt(tex2D(_SelfTexture2D, pos + ts.xy));
        uint o4 = UnpackFloat4ToUInt(tex2D(_SelfTexture2D, pos + ts.zy));
        uint sum = o1 + o2 + o3 + o4; 

        return PackUIntToFloat4(sum);
    }

    float4 frag(v2f_customrendertexture i) : SV_Target
    {
        if (i.primitiveID == 0)
            return PackUIntToFloat4(any(tex2D(_DataTex, i.localTexcoord.xy).rgb > 0));

        return sample(i.globalTexcoord.xy * 2.0);
    }

    ENDCG

    SubShader
    {
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Step"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 5.0

            ENDCG
        }
    }
}
