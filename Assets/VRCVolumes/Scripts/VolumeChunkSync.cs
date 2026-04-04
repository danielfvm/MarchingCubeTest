
using System;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;
using VRCVolumes;

public class VolumeChunkSync : UdonSharpBehaviour
{
    [Header("References")]
    public Material material;
    public int blockSize = 8;

    #region Local Fields
    public RenderTexture[] texMipMap;
    public RenderTexture texDifference, texCompact, texFinal, texTemp;
    private Texture2D texDeserialize;
    private int passDifference, passMipMap, passCompact, passFinal, passCopy, passDeserialize;
    private int gridSize;
    private DataList queue;
    private Color[] readback, writeback;
    private int lodLevels;
    #endregion

    public void Setup(int gridSize, Vector2Int dataTexDim)
    {
        Cleanup();

        this.gridSize = gridSize;

        // Find passes
        passDifference = material.FindPass("Difference");
        passMipMap = material.FindPass("MipMap");
        passCompact = material.FindPass("Compact");
        passFinal = material.FindPass("Final");
        passCopy = material.FindPass("Copy");
        passDeserialize = material.FindPass("Deserialize");

        // Create all required textures
        texTemp = new RenderTexture(dataTexDim.x, dataTexDim.y, 0, RenderTextureFormat.RFloat);
        texTemp.filterMode = FilterMode.Point;
        texTemp.Create();

        texDifference = new RenderTexture(dataTexDim.x, dataTexDim.y, 0, RenderTextureFormat.RFloat);
        texDifference.filterMode = FilterMode.Point;
        texDifference.Create();

        texDeserialize = new Texture2D(dataTexDim.x, dataTexDim.y, TextureFormat.RFloat, 0, true);

        lodLevels = Mathf.CeilToInt(Mathf.Log(gridSize / blockSize, 2));
        texMipMap = new RenderTexture[lodLevels];

        int voxelDimension = gridSize;
        for (int i = 0; i < lodLevels; i++)
        {
            voxelDimension /= 2;

            int texDim = Mathf.CeilToInt(Mathf.Pow(voxelDimension, 3f / 2f));
            texDim = Mathf.CeilToInt(Mathf.Pow(2, Mathf.Ceil(Mathf.Log(texDim, 2))));

            texMipMap[i] = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.RFloat);
            texMipMap[i].filterMode = FilterMode.Point;
            texMipMap[i].useMipMap = i == lodLevels - 1;
            texMipMap[i].Create();
        }
 
        texCompact = new RenderTexture(texMipMap[texMipMap.Length - 1].width, texMipMap[texMipMap.Length - 1].height, 0, RenderTextureFormat.RFloat);
        texCompact.filterMode = FilterMode.Point;
        texCompact.Create();

        // TODO: Technically this might be too small if all blocks have been edited!
        texFinal = new RenderTexture(dataTexDim.x, dataTexDim.y, 0, RenderTextureFormat.RFloat);
        texFinal.filterMode = FilterMode.Point;
        texFinal.Create();

        // Setup queue and buffers
        queue = new DataList();
        readback = new Color[dataTexDim.x * dataTexDim.y * 4]; // Might need to be larger
        writeback = new Color[texDeserialize.width * texDeserialize.height];
    }

    private void Cleanup()
    {
        if (texDifference != null && texDifference.IsCreated())
            texDifference.Release();
        if (texCompact != null && texCompact.IsCreated())
            texCompact.Release();
        if (texFinal != null && texFinal.IsCreated())
            texFinal.Release();
        if (texTemp != null && texTemp.IsCreated())
            texTemp.Release();
        
        for (int i = 0; texMipMap != null && i < texMipMap.Length; i++)
            if (texMipMap[i].IsCreated())
                texMipMap[i].Release();
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

    public bool Serialize(VolumeData volume, VolumeChunkSyncCallback callback, RenderTexture reference)
    {
        if (!volume.IsDirty())
            return false;

        if (readback == null)
        {
            Debug.LogError($"[{name}][VolumeChunkSync][ERR]: Serialize() was called before Setup()");
            return false;
        }

        var texData = volume.GetData();

        // Compute the difference between chunk data and reference (e.g. from terrain generation)
        // if reference null then this would be equivalent to empty chunk
        material.SetTexture("_SrcTex", texData);
        material.SetTexture("_RefTex", reference);
        material.SetVector("_TargetSize", new Vector2(texDifference.width, texDifference.height));
        VRCGraphics.Blit(null, texDifference, material, passDifference);

        // Now we compute the lods, we need this in order to determine if a block has changes or none by
        // decreasing the block size by half (e.g. 8x8x8 -> 4x4x4 -> 2x2x2 -> 1x1x1).
        // In every step we check if there was a change. Further optimization could be to check if the
        // block is fully equal.
        int chunkGridSize = gridSize;
        material.SetTexture("_SrcTex", texDifference);
        for (int i = 0; i < lodLevels; i++)
        {
            chunkGridSize /= 2;

            RenderTexture target = texMipMap[i];
            material.SetInteger("_VoxelDimension", chunkGridSize);
            material.SetVector("_TargetSize", new Vector2(target.width, target.height));
            VRCGraphics.Blit(null, target, material, passMipMap);

            material.SetTexture("_SrcTex", target);
        }

        // All active pixel
        var texActive = texMipMap[lodLevels - 1];

        // Computes sparse texture
        material.SetTexture("_ActiveTex", texActive);
        material.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(texActive.width, 2)));
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
        material.SetTexture("_CompactTex", texCompact);
        material.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(texFinal.width, 2)));
        VRCGraphics.Blit(null, texFinal, material, passFinal);

        queue.Add(new DataToken(new object[]
        {
            volume,
            callback,
        }));

        // VRCAsyncGPUReadback.Request(texFinal, 0, (IUdonEventReceiver)this);
        VRCAsyncGPUReadback.Request(texActive, 5, (IUdonEventReceiver)this);

        return true;
    }

    public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
    {
        if (!queue.TryGetValue(0, out DataToken buildInfo))
        {
            Debug.LogError($"[{name}][VolumeChunkSync][ERR]: Expected queue element.");
            return;
        }

        var volume = (VolumeData)((object[])buildInfo.Reference)[0];
        var callback = (VolumeChunkSyncCallback)((object[])buildInfo.Reference)[1];
        queue.RemoveAt(0);

        if (request.hasError)
        {
            Debug.LogError($"[{name}][VolumeChunkSync][ERR]: Gpu Readback has error.");
            return;
        }

        float[] data = new float[1];
        if (request.TryGetData(data))
            Debug.Log(data[0] * (1 << (2 * Mathf.RoundToInt(Mathf.Log(texMipMap[lodLevels - 1].width, 2)))));
        
        /*if (!request.TryGetData(readback))
        {
            Debug.LogError($"[{name}][VolumeChunkSync][ERR]: Gpu Readback failed to get data.");
            return;
        }

        int len = BitConverter.SingleToInt32Bits(readback[0].r); 

        Color[] trimmed = new Color[len];
        Array.Copy(readback, trimmed, trimmed.Length);

        callback.OnChunkSyncData(volume, trimmed);
        */
    }
}
