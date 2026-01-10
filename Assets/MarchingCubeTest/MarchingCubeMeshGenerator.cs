
using System;
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

public class MarchingCubeMeshGenerator : UdonSharpBehaviour
{
    [Header("References")]
    public MeshFilter meshFilter;
    public MeshCollider meshCollider;
    
    [Header("Compute")]
    public Material matMarchingCube;
    public Material matMipMap;
    public Material matWriteActiveTexels;
    public Material matCompactTexels;
    //public Material matDeflate;


    [Header("Debug")]
    public Material debugData;
    public Material debugMipMap;
    public Material debugCompact; 

    private const int texDim = 1024;

    private readonly int[] Triangles = new int[texDim * texDim];
    private RenderTexture data, compact, deflate, mipMap;

    public Text text;
    public Texture test;
    //public CustomRenderTexture mipMap;

    private int VoxelAmount;

    //private RenderTexture[] mipMapDoubleBuffer;

    // 8bit R
    // 
    void Start()
    {
        VoxelAmount = Mathf.FloorToInt(Mathf.Pow(texDim/4, 2f/3f));
        Debug.Log("Voxel Size: " + VoxelAmount);

        // Do it once and later just use it in Array.Copy
        for (int i = 0; i < Triangles.Length; i++)
            Triangles[i] = i;

        data = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.ARGB32);
        data.filterMode = FilterMode.Point;
        data.Create();

        mipMap = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.RFloat);
        mipMap.useMipMap = true;
        mipMap.filterMode = FilterMode.Point;
        mipMap.Create();

        compact = new RenderTexture(texDim / 4, texDim / 4, 0, RenderTextureFormat.ARGB32);
        compact.filterMode = FilterMode.Point;
        compact.Create();

        deflate = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.ARGB32);
        deflate.filterMode = FilterMode.Point;
        deflate.Create();

        transform.localScale = Vector3.one / VoxelAmount;


       /* mipMapDoubleBuffer = new RenderTexture[2];
        for (int i = 0; i < mipMapDoubleBuffer.Length; i++)
        {
            mipMapDoubleBuffer[i] = new RenderTexture(texDim, texDim * 2, 0, RenderTextureFormat.ARGB32);
            mipMapDoubleBuffer[i].filterMode = FilterMode.Point;
            mipMapDoubleBuffer[i].Create();
        }*/

        //Generate();
    }

    long timeStart;

    public void Generate()
    {
        timeStart = DateTimeOffset.Now.ToUnixTimeMilliseconds();

        // Generate data
        // Generate MarchingCube Triangle Data
        matMarchingCube.SetFloat("_MyTime", Time.time);
        matMarchingCube.SetVector("_TargetSize", new Vector2(texDim, texDim));
        matMarchingCube.SetInteger("_Lod", 1);
        matMarchingCube.SetInteger("_VoxelAmount", VoxelAmount);
        VRCGraphics.Blit(null, data, matMarchingCube);
              
        matMipMap.SetTexture("_DataTex", data);

        
        // Generate MipMaps for CompactSparseTexture
        //var mipMap = GenerateMipMaps(texDim, data);
       // mipMap.Update(2);

        matWriteActiveTexels.SetTexture("_DataTex", data);
        VRCGraphics.Blit(null, mipMap, matWriteActiveTexels);

        // Compute CompactSparseTexture
        matCompactTexels.SetTexture("_DataTex", data);
        matCompactTexels.SetTexture("_ActiveTexelMap", mipMap);
        VRCGraphics.Blit(null, compact, matCompactTexels);

        text.text = "Gen: " + (DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart) + "ms\n";     
        timeStart = DateTimeOffset.Now.ToUnixTimeMilliseconds();   

        // Just for debugging, delete later
        debugData.SetTexture("_MainTex", data);
        debugMipMap.SetTexture("_MainTex", mipMap);
        debugCompact.SetTexture("_MainTex", compact);

        // TODO: Change to deflate
        VRCAsyncGPUReadback.Request(compact, 0, (IUdonEventReceiver)this);
    }

/*
    public RenderTexture GenerateMipMaps(int resolution, Texture src)
    {
        int levels = Mathf.RoundToInt(Mathf.Log(resolution, 2));

        matMipMap.SetInteger("_Level", 0);
        matMipMap.SetTexture("_DataTex", src);
        matMipMap.SetTexture("_MainTex", mipMapDoubleBuffer[1]); // just to be sure
        VRCGraphics.Blit(null, mipMapDoubleBuffer[0], matMipMap);

        Debug.Log(levels);

        for (int i = 0; i <= levels; i++)
        {
            matMipMap.SetTexture("_MainTex", mipMapDoubleBuffer[i % 2]);
            matMipMap.SetInteger("_Level", i);
            VRCGraphics.Blit(null, mipMapDoubleBuffer[1 - (i % 2)], matMipMap);
        }

        return mipMapDoubleBuffer[1 - (levels % 2)];
    }
*/
    public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
    {
        if (request.hasError)
        {
            Debug.LogError("GPU READBACK FAILED");
            return;
        }

        var data = new Color32[request.width * request.height];

        if (!request.TryGetData(data))
        {
            Debug.LogError("GET GPU DATA FAILED");
            return;
        }

        text.text += "Readback: " + (DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart) + "ms\n";  
 
        var size = data[data.Length - 1];
        int len = size.r | (size.g << 8) | (size.b << 16);
        Debug.Log(size);
        Debug.Log(len);

        if (len % 3 != 0)
        {
            Debug.LogError("Not % 3!");
            return;
        }



        timeStart = DateTimeOffset.Now.ToUnixTimeMilliseconds();   
        // This sadly is as of now, unavoidable :/
        Vector3[] vertices = new Vector3[len];
        for (int i = 0; i < len; i ++)
            vertices[i] = new Vector3(data[i].r, data[i].g, data[i].b);

        int[] triangles = new int[len];
        Array.Copy(Triangles, triangles, len);
        text.text += "Loop: " + (DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart) + "ms\n";  



        timeStart = DateTimeOffset.Now.ToUnixTimeMilliseconds();   
        var mesh = new Mesh();
        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        mesh.vertices = vertices;
        mesh.triangles = triangles;
        
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        meshFilter.mesh = mesh;
        meshCollider.sharedMesh = mesh;
        text.text += "Mesh: " + (DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart) + "ms\n"; 

        text.text += "Vertex: " + len + "\n";  
    }
}