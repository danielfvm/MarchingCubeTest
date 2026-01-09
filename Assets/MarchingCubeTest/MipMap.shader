Shader "GenerateMesh/MipMap"
{
    CGINCLUDE
    #include "UnityCG.cginc"

    sampler2D _DataTex;
    sampler2D _MainTex;
    int _Level;

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
        float3 ts = float3(1.0 / 1024.0, 1.0 / 2048.0, 0.0);
        pos -= ts / 2.0;
        uint o1 = UnpackFloat4ToUInt(tex2D(_MainTex, pos + ts.zz));
        uint o2 = UnpackFloat4ToUInt(tex2D(_MainTex, pos + ts.xz));
        uint o3 = UnpackFloat4ToUInt(tex2D(_MainTex, pos + ts.xy));
        uint o4 = UnpackFloat4ToUInt(tex2D(_MainTex, pos + ts.zy));
        uint sum = o1 + o2 + o3 + o4; 

        return PackUIntToFloat4(sum);
    }

    float4 frag(v2f i) : SV_Target
    {
        float mipSize = exp2(-_Level);

        if (_Level == 0)
            return PackUIntToFloat4(any(tex2D(_DataTex, (i.uv - float2(0, 0.5)) * float2(1.0, 2.0)).rgb > 0));

        if (i.uv.y > mipSize)
            return tex2D(_MainTex, i.uv);

        if (i.uv.x > mipSize || i.uv.y < mipSize - mipSize / 2.0)
            return 0;

        return sample(i.uv * 2.0);
    }

    ENDCG

    SubShader
    {
        Pass
        {
            Cull Off ZWrite Off ZTest Always
            Name "Step"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0

            ENDCG
        }
    }
}
