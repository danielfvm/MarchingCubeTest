
using System;
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon.Common;
using VRC.Udon.Common.Interfaces;

public class MarchingCubeMeshGenerator : UdonSharpBehaviour
{
    [Header("References")]
    public MeshFilter meshFilter;
    public MeshCollider meshCollider;
    
    [Header("Compute")]
    public Material matDraw;
    public Material matMarchingCube;
    public Material matWriteActiveTexels;
    public Material matCompactTexels;
    //public Material matDeflate;

    [Header("Debug")]
    public Material debugData;
    public Material debugVertex;
    public Material debugMipMap;
    public Material debugCompact;

    private const int texDim = 1024;

    private readonly int[] Triangles = new int[texDim * texDim];
    private RenderTexture vertexData, compact, deflate, mipMap;

    public Text text;

    private int VoxelAmount;
    private bool inVR;

    // Grid data, this should be put into its own Chunk in the future
    private RenderTexture data, dbData;

    private int erasePass, paintPass, resetPass;
    private Mesh mesh;

    // 8bit R
    // 
    void Start()
    {
        inVR = Networking.LocalPlayer.IsUserInVR();

        VoxelAmount = Mathf.FloorToInt(Mathf.Pow(texDim/4, 2f/3f));
        Debug.Log("Voxel Size: " + VoxelAmount);

        data = new RenderTexture(texDim/4, texDim/4, 0, RenderTextureFormat.RFloat);
        data.filterMode = FilterMode.Point;
        data.Create();
        dbData = new RenderTexture(texDim/4, texDim/4, 0, RenderTextureFormat.RFloat);
        dbData.filterMode = FilterMode.Point;
        dbData.Create();

        // Do it once and later just use it in Array.Copy
        for (int i = 0; i < Triangles.Length; i++)
            Triangles[i] = i;

        vertexData = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.ARGBFloat); // ARGBFloat seams to be cutoff on Quest to 16bit per channel
        vertexData.filterMode = FilterMode.Point;
        vertexData.Create();

        mipMap = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.RFloat);
        mipMap.useMipMap = true;
        mipMap.filterMode = FilterMode.Point; 
        mipMap.Create();

        compact = new RenderTexture(texDim / 2, texDim / 2, 0, RenderTextureFormat.ARGBFloat);
        compact.filterMode = FilterMode.Point;
        compact.Create();

        deflate = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.ARGB32);
        deflate.filterMode = FilterMode.Point;
        deflate.Create();

        paintPass = matDraw.FindPass("Paint");
        erasePass = matDraw.FindPass("Erase");
        resetPass = matDraw.FindPass("Reset");


        mesh = new Mesh();
        mesh.MarkDynamic();
        mesh.bounds = new Bounds(Vector3.zero, transform.lossyScale);
        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
    }

    long timeStart;

    bool swap;

    public void Reset()
    {
        swap = !swap;
        VRCGraphics.Blit(null, swap ? data : dbData, matDraw, resetPass);

        Generate(swap ? data : dbData);
    }

    public void Draw(Vector3 position)
    {
        Vector3 local = transform.InverseTransformPoint(position);
        Debug.Log(local);

        matDraw.SetVector("_Position", (local + Vector3.one * 0.5f) * VoxelAmount);
        matDraw.SetInteger("_VoxelAmount", VoxelAmount);
        matDraw.SetTexture("_PrevData", swap ? data : dbData);

        swap = !swap;
        VRCGraphics.Blit(null, swap ? data : dbData, matDraw, paintPass);

        Generate(swap ? data : dbData);
    }

    public void Erase(Vector3 position)
    {
        Vector3 local = transform.InverseTransformPoint(position);
        Debug.Log(local);

        matDraw.SetVector("_Position", (local + Vector3.one * 0.5f) * VoxelAmount);
        matDraw.SetInteger("_VoxelAmount", VoxelAmount);
        matDraw.SetTexture("_PrevData", swap ? data : dbData);

        swap = !swap;
        VRCGraphics.Blit(null, swap ? data : dbData, matDraw, erasePass);

        Generate(swap ? data : dbData);
    }

    public void Generate(Texture weights)
    {
        debugData.SetTexture("_MainTex", weights);

        timeStart = DateTimeOffset.Now.ToUnixTimeMilliseconds();

        // Generate data
        // Generate MarchingCube Triangle Data
        matMarchingCube.SetTexture("_Data", weights);
        matMarchingCube.SetFloat("_MyTime", Time.time);
        matMarchingCube.SetVector("_TargetSize", new Vector2(texDim, texDim));
        matMarchingCube.SetInteger("_Lod", 1);
        matMarchingCube.SetInteger("_VoxelAmount", VoxelAmount);
        VRCGraphics.Blit(null, vertexData, matMarchingCube);
              
        matWriteActiveTexels.SetTexture("_DataTex", vertexData);
        VRCGraphics.Blit(null, mipMap, matWriteActiveTexels);

        // Compute CompactSparseTexture
        matCompactTexels.SetTexture("_DataTex", vertexData);
        matCompactTexels.SetTexture("_ActiveTexelMap", mipMap);
        VRCGraphics.Blit(null, compact, matCompactTexels);

        text.text = "Gen: " + (DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart) + "ms\n";     
        timeStart = DateTimeOffset.Now.ToUnixTimeMilliseconds();   

        // Just for debugging, delete later
        debugVertex.SetTexture("_MainTex", vertexData);
        debugMipMap.SetTexture("_MainTex", mipMap);
        debugCompact.SetTexture("_MainTex", compact);

        // TODO: Change to deflate
        VRCAsyncGPUReadback.Request(compact, 0, (IUdonEventReceiver)this);
    }

    bool doUpdate = false;

    void Update()
    {
        if (!inVR)
            doUpdate = Input.GetKey(KeyCode.F);

        if (doUpdate)
            Generate(data);
    }

    public override void InputLookVertical(float value, UdonInputEventArgs args)
    {
        if (inVR)
            doUpdate = value > 0.8;
    }

    #if UNITY_EDITOR && !COMPILER_UDONSHARP
    void OnDrawGizmos()
    {
        Gizmos.color = Color.white;
        Gizmos.DrawWireCube(transform.position, transform.lossyScale);
    }
    #endif

    public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
    {
        if (request.hasError)
        {
            Debug.LogError("GPU READBACK FAILED");
            return;
        }

        var data = new Color[request.width * request.height];

        if (!request.TryGetData(data))
        {
            Debug.LogError("GET GPU DATA FAILED");
            return;
        }

        text.text += "Readback: " + (DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart) + "ms\n";  
 
        int len = (int)data[data.Length - 1].r;
        //int len = (int)(size.r * 255.0) | ((int)(size.g * 255.0) << 8) | ((int)(size.b * 255.0) << 16);
       // Debug.Log(size);
        //Debug.Log(len);

        if (len % 3 != 0)
        {
            Debug.LogError("Not % 3!");
            return;
        }

        timeStart = DateTimeOffset.Now.ToUnixTimeMilliseconds();   
        // This sadly is as of now, unavoidable :/
        /*Vector3[] vertices = new Vector3[len];
        for (int i = 0; i < len; i ++)
            vertices[i] = new Vector3(data[i].r, data[i].g, data[i].b);*/

        var colors = new Color[len];
        Array.Copy(data, colors, len);

        int[] triangles = new int[len];
        Array.Copy(Triangles, triangles, len);
        text.text += "Loop: " + (DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart) + "ms\n";  

        if (len == 0)
        {
            swap = !swap;
            VRCGraphics.Blit(null, swap ? this.data : dbData, matDraw, resetPass);
        }


        timeStart = DateTimeOffset.Now.ToUnixTimeMilliseconds();   
        //mesh.vertices = vertices;
       // mesh.SetVertices(new Vector3[len], 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
        mesh.Clear(true);
        mesh.SetVertices(new Vector3[len], 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
        mesh.SetColors(colors, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
        mesh.SetIndices(triangles, MeshTopology.Triangles, 0, false);
        
        // mesh.RecalculateNormals();
        // mesh.RecalculateBounds();

        meshFilter.mesh = mesh;
       // meshCollider.sharedMesh = mesh;
        text.text += "Mesh: " + (DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart) + "ms\n"; 

        text.text += "Vertex: " + len + "\n";  
    }
}