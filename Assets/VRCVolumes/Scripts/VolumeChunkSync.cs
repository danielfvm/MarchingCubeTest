
using System;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRCVolumes;

public class VolumeChunkSync : UdonSharpBehaviour
{
    [Header("Regerences")]
    public Material material;
    public VolumeAreaManager manager;
    public int blockSize = 8;

    #region Local Fields
    private RenderTexture[] texMipMap;
    private RenderTexture texDifference, texActive, texCompact, texFinal, texTemp;
    private Texture2D texDeserialize;
    private int passDifference, passMipMap, passActive, passCompact, passFinal, passCopy, passDeserialize;
    private int gridSize;
    private DataList queue;
    private Color[] readback, writeback;
    #endregion

    private void Start()
    {
        passDifference = material.FindPass("Difference");
        passMipMap = material.FindPass("MipMap");
        passActive = material.FindPass("Active");
        passCompact = material.FindPass("Compact");
        passFinal = material.FindPass("Final");
        passCopy = material.FindPass("Copy");
        passDeserialize = material.FindPass("Deserialize");
        gridSize = manager.GridSize / blockSize;

        var texDim = manager.TextureDimensionInt;

        texActive = new RenderTexture(texDim.x * 2, texDim.y * 2, 0, RenderTextureFormat.RFloat);
        texActive.useMipMap = true; // We want to generate mipmaps for the sparse texture algorithm
        texActive.filterMode = FilterMode.Point;
        texActive.Create();

        texTemp = new RenderTexture(texDim.x, texDim.y, 0, RenderTextureFormat.RFloat);
        texTemp.filterMode = FilterMode.Point;
        texTemp.Create();

        queue = new DataList();
        readback = new Color[texDim.x * texDim.y * 4]; // Might need to be larger
    
        // TODO: init texSerialize

        writeback = new Color[texDeserialize.width * texDeserialize.height];
    }

    public void Deserialize(VolumeData volume, Color[] data)
    {
        // TODO: Maybe there is an optimization possible by using SetPixels(x, y, blockWidth, blockHeight, colors);
        Array.Copy(data, writeback, data.Length);
        texDeserialize.SetPixels(data);
        texDeserialize.Apply();

        // Sadly need to make a copy here in order to allow for doing: volumeData = volumeData + texDeserialize
        material.SetTexture("_SrcTex", volume.GetData());
        material.SetVector("_TargetSize", new Vector2(texTemp.width, texTemp.height));
        VRCGraphics.Blit(null, texTemp, material, passCopy);

        material.SetTexture("_SrcTex", texDeserialize);
        material.SetTexture("_OriginalTex", texTemp);
        VRCGraphics.Blit(null, volume.GetData(), material, passDeserialize);
    }

    public void Serialize(VolumeData volume, VolumeChunkSyncCallback callback, RenderTexture reference = null)
    {
        int lodLevels = Mathf.CeilToInt(Mathf.Log(gridSize, 2));
        var texData = volume.GetData();

        // Compute the difference between chunk data and reference (e.g. from terrain generation)
        // if reference null then this would be equivalent to empty chunk
        material.SetTexture("_SrcTex", texData);
        if (reference != null)
        {
            material.SetTexture("_RefTex", reference);
            VRCGraphics.Blit(null, texDifference, material, passDifference);
            material.SetTexture("_SrcTex", texDifference);
        }

        // Now we compute the lods, we need this in order to determine if a block has changes or none by
        // decreasing the block size by half (e.g. 8x8x8 -> 4x4x4 -> 2x2x2 -> 1x1x1).
        // In every step we check if there was a change. Further optimization could be to check if the
        // block is fully equal.
        for (int i = 0; i < lodLevels; i++)
        {
            material.SetInteger("_Level", i);
            VRCGraphics.Blit(null, texMipMap[i % 2], material, passMipMap);
            material.SetTexture("_SrcTex", texMipMap[(i + 1) % 2]);
        }

        // Computes active texels, automatically generates MipMaps of it
        material.SetTexture("_Target", texMipMap[lodLevels % 2]);
        VRCGraphics.Blit(null, texActive, material, passActive);

        // Computes sparse texture
        material.SetTexture("_TriangleTex", texDifference);
        material.SetTexture("_ActiveTex", texActive);
        VRCGraphics.Blit(null, texCompact, material, passCompact);

        // TODO: Might need to compute lookup table texture with extra step

        // Encodes the computed data for sending.
        // # Lookup table
        // Starts with a lookup table with the size of block count. This lookup table contains the index
        // to the encoded data or 0(?). This allows for fast loading of the data with the downside of 
        // more data that has to be send.
        // # Data
        // After the table only edited blocks are appended and can be indexed via the lookup table. 
        material.SetTexture("_DateTex", texData);
        material.SetTexture("_ActiveTex", texCompact);
        VRCGraphics.Blit(null, texFinal, material, passFinal);

        queue.Add(new DataToken(new object[]
        {
            volume,
            callback,
        }));
    }

    public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
    {
        if (!queue.TryGetValue(0, out DataToken buildInfo))
        {
            Debug.LogError($"[{name}][VolumeChunkSync][ERR]: Expected queue element.");
            return;
        }

        var volume = (VolumeData)((object[])buildInfo.Reference)[0];
        var callback = (VolumeChunkSyncCallback)((object[])buildInfo.Reference)[0];
        queue.RemoveAt(0);

        if (request.hasError)
        {
            Debug.LogError($"[{name}][VolumeChunkSync][ERR]: Gpu Readback has error.");
            return;
        }

        if (!request.TryGetData(readback))
        {
            Debug.LogError($"[{name}][VolumeChunkSync][ERR]: Gpu Readback failed to get data.");
            return;
        }

        callback.OnChunkSyncData(volume, readback);
    }
}
