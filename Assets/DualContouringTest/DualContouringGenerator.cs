
using System;
using BestHTTP.SecureProtocol.Org.BouncyCastle.Ocsp;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon;
using VRC.Udon.Common.Interfaces;

public class DualContouringGenerator : UdonSharpBehaviour
{
    public Material debugWeightData, debugVertexData, debugActiveVertexData, debugCompactVertexData;
    private RenderTexture weightData, vertexData, activeVertexData, compactVertexData;
    public Material matDualContouring;
    public Material matWriteActiveTexels;
    public Material matCompactTexels;

    private Color[] dataReadback = new Color[256 * 256];

    public MeshFilter meshFilter;
    private int[] Triangles = new int[256 * 256];

    private void Start()
    {
        // Each pixel is a Voxel 512^2 = 64^3
        weightData = new RenderTexture(512, 512, 0, RenderTextureFormat.RFloat);
        weightData.filterMode = FilterMode.Point;
        weightData.Create();

        // Each pixel is a Vertex with position and normal
        vertexData = new RenderTexture(512, 512, 0, RenderTextureFormat.ARGBFloat);
        vertexData.filterMode = FilterMode.Point;
        vertexData.Create();

        activeVertexData = new RenderTexture(512, 512, 0, RenderTextureFormat.RFloat);
        activeVertexData.filterMode = FilterMode.Point;
        activeVertexData.useMipMap = true;
        activeVertexData.Create();

        compactVertexData = new RenderTexture(256, 256, 0, RenderTextureFormat.ARGBFloat);
        compactVertexData.filterMode = FilterMode.Point;
        compactVertexData.Create();


        for (int i = 0; i < Triangles.Length; i++)
            Triangles[i] = i;
    }

    public void Generate()
    {
        matDualContouring.SetTexture("_Data", weightData);
        VRCGraphics.Blit(null, vertexData, matDualContouring);

        matWriteActiveTexels.SetTexture("_DataTex", vertexData);
        VRCGraphics.Blit(null, activeVertexData, matWriteActiveTexels);

        // Compute CompactSparseTexture
        matCompactTexels.SetTexture("_DataTex", vertexData);
        matCompactTexels.SetTexture("_ActiveTexelMap", activeVertexData);
        matCompactTexels.SetVector("_TargetSize", new Vector2(compactVertexData.width, compactVertexData.height));
        matCompactTexels.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(vertexData.width, 2)));
        VRCGraphics.Blit(null, compactVertexData, matCompactTexels);
    
        // Update preview texture for debugging
        debugWeightData.SetTexture("_MainTex", weightData);
        debugVertexData.SetTexture("_MainTex", vertexData);
        debugActiveVertexData.SetTexture("_MainTex", activeVertexData);
        debugCompactVertexData.SetTexture("_MainTex", compactVertexData);

        VRCAsyncGPUReadback.Request(compactVertexData, 0, (IUdonEventReceiver)this);
    }

    public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
    {
        if (!request.TryGetData(dataReadback))
            return;

        int len = (int)dataReadback[dataReadback.Length - 1].r;

        Debug.Log("Vertices: " + len);

        Vector3[] vertices = new Vector3[len];
        int[] triangles = new int[len];
        Array.Copy(Triangles, triangles, len);

        for (int i = 0; i < len; i++)
            vertices[i] = new Vector3(dataReadback[i].r, dataReadback[i].g, dataReadback[i].b);
        
        Mesh mesh = new Mesh();
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one);
        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        mesh.SetVertices(vertices, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
        //mesh.SetColors(colors, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
        mesh.SetIndices(triangles, MeshTopology.Points, 0, false);

        meshFilter.sharedMesh = mesh;
    }
}
