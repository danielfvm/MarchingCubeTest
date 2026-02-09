using UnityEngine;
using VolumetricPens;
using VRC.SDKBase;

public static class DataBlockExt
{
    private static MarchingCubeSystem GetSystem(this DataBlock block) => (MarchingCubeSystem)((object[])(object)block)[0];
    public static RenderTexture[] GetData(this DataBlock block) => (RenderTexture[])((object[])(object)block)[1];

    public static void GenerateLod(this DataBlock block)
    {
        LodSystem lod = block.GetSystem().lod;
        RenderTexture[] datas = block.GetData();

        for (int i = 1; i < datas.Length; i++)
        {
            lod.matMipMapLod.SetInteger("_VoxelAmount", 40);
            lod.matMipMapLod.SetTexture("_PrevData", datas[i - 1]);
            lod.matMipMapLod.SetVector("_TargetSize", new Vector2(datas[i].width, datas[i].height));
            VRCGraphics.Blit(null, datas[i], lod.matMipMapLod);
        }
    }

    public static void Cleanup(this DataBlock block)
    {
        foreach (RenderTexture data in block.GetData())
            data.Release();
    }
}
