using UnityEngine;
using VolumetricPens;
using VRC.SDKBase;

public static class DataBlockExt
{
    private static MarchingCubeSystem GetSystem(this DataBlock block) => (MarchingCubeSystem)((object[])(object)block)[0];
    public static RenderTexture[] GetData(this DataBlock block) => (RenderTexture[])((object[])(object)block)[1];

    public static void GenerateLod(this DataBlock block)
    {
        MarchingCubeSystem system = block.GetSystem();
        LodSystem lod = system.lod;
        RenderTexture[] datas = block.GetData();
        int voxelAmount = system.VoxelAmount;

        for (int i = 1; i < datas.Length; i++)
        {
            lod.matMipMapLod.SetInteger("_VoxelAmount", voxelAmount);
            lod.matMipMapLod.SetTexture("_PrevData", datas[i - 1]);
            lod.matMipMapLod.SetVector("_TargetSize", new Vector2(datas[i].width, datas[i].height));
            VRCGraphics.Blit(null, datas[i], lod.matMipMapLod);

            voxelAmount >>= 1;
        }
    }

    public static void Cleanup(this DataBlock block)
    {
        foreach (RenderTexture data in block.GetData())
            data.Release();
    }
}
