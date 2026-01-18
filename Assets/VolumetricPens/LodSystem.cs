
using System;
using UdonSharp;
using UnityEngine;
using VolumetricPens;
using VRC.SDK3.Data;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon;
using VRC.Udon.Common.Interfaces;

public class LodSystem : UdonSharpBehaviour
{
    [Header("References")]
    public MarchingCubeSystem system;

    [Header("Debug")]
    public Material debugMipMapData;
    public Material debugMipMapData2;
    public Material debugVertex;
    public Material debugMipMap;
    public Material debugCompact; 


    [Header("Comute")]
    public Material matMarchingCubeLod;
    public Material matMipMapLod;


    // We use a dict as a queue to prevent duplicate chunks, downside: no order -> starvation possible
    private DataDictionary queue = new DataDictionary();
    private DataList gpuUpdateQueue = new DataList();
    private RenderTexture[] mipmapData = new RenderTexture[2];
    private RenderTexture vertexData, compact, mipmapVertex;
    private int passMipMap;

    void Start()
    {
        // 20x20 min would be 90x90
        mipmapData[0] = new RenderTexture(128, 128, 0, RenderTextureFormat.RFloat);
        mipmapData[0].filterMode = FilterMode.Point;
        mipmapData[0].Create();

        // 10x10
        mipmapData[1] = new RenderTexture(32, 32, 0, RenderTextureFormat.RFloat);
        mipmapData[1].filterMode = FilterMode.Point;
        mipmapData[1].Create();

        vertexData = new RenderTexture(128, 128, 0, RenderTextureFormat.ARGBFloat);
        vertexData.filterMode = FilterMode.Point;
        vertexData.Create();

        mipmapVertex = new RenderTexture(128, 128, 0, RenderTextureFormat.RFloat);
        mipmapVertex.useMipMap = true;
        mipmapVertex.filterMode = FilterMode.Point; 
        mipmapVertex.Create();

        compact = new RenderTexture(128 / 2, 128 / 2, 0, RenderTextureFormat.ARGBFloat);
        compact.filterMode = FilterMode.Point;
        compact.Create();

        passMipMap = matMipMapLod.FindPass("MipMap");
    }

    public void Reset()
    {
        queue.Clear();
        gpuUpdateQueue.Clear();
    }

    public void UpdateLOD(Chunk chunk)
    {
        if (queue.ContainsKey(chunk.key))
            return;
        queue.Add(chunk.key, chunk);
    }

    void Update()
    {
        if (queue.Count > 0)
        {
            ulong key = queue.GetKeys()[0].ULong;
            GenerateChunk((Chunk)queue[key].Reference);
            queue.Remove(key);
        }
    }

    private void GenerateChunk(Chunk chunk)
    {
        gpuUpdateQueue.Add(chunk);

        // Generate mipmap of data
        matMipMapLod.SetInteger("_VoxelAmount", 40);
        matMipMapLod.SetTexture("_PrevData", chunk.data);
        matMipMapLod.SetVector("_TargetSize", new Vector2(mipmapData[0].width, mipmapData[0].height));
        VRCGraphics.Blit(null, mipmapData[0], matMipMapLod, passMipMap);

        matMipMapLod.SetInteger("_VoxelAmount", 20);
        matMipMapLod.SetTexture("_PrevData", mipmapData[0]);
        matMipMapLod.SetVector("_TargetSize", new Vector2(mipmapData[1].width, mipmapData[1].height));
        VRCGraphics.Blit(null, mipmapData[1], matMipMapLod, passMipMap);

        // Generate MarchingCube Triangle Data
        matMarchingCubeLod.SetTexture("_Data", mipmapData[1]);
        matMarchingCubeLod.SetVector("_TargetSize", new Vector2(vertexData.width, vertexData.height));
        matMarchingCubeLod.SetInteger("_VoxelAmount", 10 - 4);
        VRCGraphics.Blit(null, vertexData, matMarchingCubeLod);
        
        system.matWriteActiveTexels.SetTexture("_DataTex", vertexData);
        VRCGraphics.Blit(null, mipmapVertex, system.matWriteActiveTexels);

        // Compute CompactSparseTexture
        system.matCompactTexels.SetTexture("_DataTex", vertexData);
        system.matCompactTexels.SetTexture("_ActiveTexelMap", mipmapVertex);
        system.matCompactTexels.SetVector("_TargetSize", new Vector2(compact.width, compact.height));
        system.matCompactTexels.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(vertexData.width, 2)));
        VRCGraphics.Blit(null, compact, system.matCompactTexels);

        // Just for visualization
        debugMipMapData.SetTexture("_MainTex", mipmapData[0]);
        debugMipMapData2.SetTexture("_MainTex", mipmapData[1]);
        debugVertex.SetTexture("_MainTex", vertexData);
        debugMipMap.SetTexture("_MainTex", mipmapVertex);
        debugCompact.SetTexture("_MainTex", compact);

        VRCAsyncGPUReadback.Request(compact, 0, (IUdonEventReceiver)this);
    }

    private readonly Color[] tempData = new Color[128 * 128 / 4];

    public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
    {
        if (request.hasError)
        {
            Debug.LogError("GPU READBACK FAILED");
            return;
        }

        if (!request.TryGetData(tempData))
        {
            Debug.LogError("GET GPU DATA FAILED");
            return;
        }

        int len = (int)tempData[tempData.Length - 1].r;

        if (len % 3 != 0 || len >= tempData.Length)
        {
            Debug.LogError(len + " not % 3!");
            return;
        }

        // This sadly is as of now, unavoidable :/
        Vector3[] vertices = new Vector3[len];
        for (int i = 0; i < len; i ++)
            vertices[i] = new Vector3(tempData[i].r, tempData[i].g, tempData[i].b);

        //var colors = new Color[len];
        //Array.Copy(tempData, colors, len);

        int[] triangles = new int[len];
        Array.Copy(system.Triangles, triangles, len);

        if (!gpuUpdateQueue.TryGetValue(0, out DataToken chunkToken)) {
            Debug.LogError("Failed to get queue element!");
            return;
        }

        gpuUpdateQueue.RemoveAt(0);

        Chunk chunk = (Chunk)chunkToken.Reference;
        Mesh mesh = chunk.mesh[1];

        mesh.Clear(true); 
        mesh.SetVertices(vertices, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
        //mesh.SetColors(colors, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
        mesh.SetIndices(triangles, MeshTopology.Triangles, 0, false);
        mesh.RecalculateNormals();

        //Debug.Log("Mesh updated!");
    }
}
