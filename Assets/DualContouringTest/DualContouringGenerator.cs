
using System;
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon;
using VRC.Udon.Common;
using VRC.Udon.Common.Interfaces;

public class DualContouringGenerator : UdonSharpBehaviour
{
    public Material debugWeightData;
    public Material debugVertexData, debugActiveVertexData, debugCompactVertexData;
    public Material debugIndexData, debugActiveIndexData, debugCompactIndexData;

    private RenderTexture weightData;
    private RenderTexture vertexData, activeVertexData, compactVertexData;
    private RenderTexture indexLookupData, indexData, activeIndexData, compactIndexData;

    public Material matDualContouring;
    public Material matWriteActiveTexels;
    public Material matCompactTexels, matLookup;

    private Color[] vertexReadback = new Color[256 * 256];
    private byte[] indexReadback = new byte[4 * 4 * 512 * 512];

    public MeshFilter meshFilter;
    private int[] Triangles = new int[256 * 256];
    private int passIndices, passVertices;

    public Text text;
    private Mesh mesh;
    private bool inVR;

    private void Start()
    {
        inVR = Networking.LocalPlayer.IsUserInVR();
        passIndices = matDualContouring.FindPass("Indices");
        passVertices = matDualContouring.FindPass("Vertices");

        // Each pixel is a Voxel 512^2 = 64^3
        weightData = new RenderTexture(512, 512, 0, RenderTextureFormat.RFloat);
        weightData.filterMode = FilterMode.Point;
        weightData.Create();

        mesh = new Mesh();
        mesh.bounds = new Bounds(Vector3.zero, Vector3.one);
        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        meshFilter.sharedMesh = mesh;

        // Vertex - each pixel contains position (and normal)
        {
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
        }

        // Index - each pixel contains a quad. At max 3 quads per voxel => 2x2 (-1 unused)
        {
            indexLookupData = new RenderTexture(512, 512, 0, RenderTextureFormat.RFloat); // RFloat would be enough, but idk if it works
            indexLookupData.filterMode = FilterMode.Point;
            indexLookupData.Create();

            indexData = new RenderTexture(1024, 1024, 0, RenderTextureFormat.ARGBFloat);
            indexData.filterMode = FilterMode.Point;
            indexData.Create();

            activeIndexData = new RenderTexture(1024, 1024, 0, RenderTextureFormat.RFloat);
            activeIndexData.filterMode = FilterMode.Point;
            activeIndexData.useMipMap = true;
            activeIndexData.Create();

            compactIndexData = new RenderTexture(512, 512, 0, RenderTextureFormat.ARGBFloat);
            compactIndexData.filterMode = FilterMode.Point;
            compactIndexData.Create();   
        }

        for (int i = 0; i < Triangles.Length; i++)
            Triangles[i] = i;
    }

    bool rebuild;

    public void Update()
    {
        if (rebuild || Input.GetKey(KeyCode.F))
        {
            Generate();
        }
    }

    public override void InputLookVertical(float value, UdonInputEventArgs args)
    {
        rebuild = value > 0.8 && inVR;
    }

    public void Generate()
    {
        if (vertex)
            return;

        vertex = true;

        // debugWeightData.SetTexture("_MainTex", weightData);

        // Compute Vertices
        {
            matDualContouring.SetFloat("_UdonTime", Time.time);
            matDualContouring.SetTexture("_DataTex", weightData);
            VRCGraphics.Blit(null, vertexData, matDualContouring, passVertices);

            matWriteActiveTexels.SetTexture("_DataTex", vertexData);
            VRCGraphics.Blit(null, activeVertexData, matWriteActiveTexels);

            // Compute CompactSparseTexture
            matCompactTexels.SetInteger("_Index", 0);
            matCompactTexels.SetTexture("_DataTex", vertexData);
            matCompactTexels.SetTexture("_ActiveTexelMap", activeVertexData);
            matCompactTexels.SetVector("_TargetSize", new Vector2(compactVertexData.width, compactVertexData.height));
            matCompactTexels.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(vertexData.width, 2)));
            VRCGraphics.Blit(null, compactVertexData, matCompactTexels);

            // Compute VertexIndexLookup
            matLookup.SetTexture("_ActiveTexelMap", activeVertexData);
            matLookup.SetVector("_TargetSize", new Vector2(indexLookupData.width, indexLookupData.height));
            matLookup.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(vertexData.width, 2)));
            VRCGraphics.Blit(null, indexLookupData, matLookup);
        }

        // Compute Indices
        {
            matDualContouring.SetTexture("_IndexLookup", indexLookupData);
            matDualContouring.SetTexture("_DataTex", weightData);
            VRCGraphics.Blit(null, indexData, matDualContouring, passIndices);

            matWriteActiveTexels.SetTexture("_DataTex", indexData);
            VRCGraphics.Blit(null, activeIndexData, matWriteActiveTexels);

            // Compute CompactSparseTexture
            matCompactTexels.SetTexture("_IndexLookup", indexLookupData);
            matCompactTexels.SetInteger("_Index", 1);
            matCompactTexels.SetTexture("_DataTex", indexData);
            matCompactTexels.SetTexture("_ActiveTexelMap", activeIndexData);
            matCompactTexels.SetVector("_TargetSize", new Vector2(compactIndexData.width, compactIndexData.height));
            matCompactTexels.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(indexData.width, 2)));
            VRCGraphics.Blit(null, compactIndexData, matCompactTexels);

            VRCAsyncGPUReadback.Request(compactVertexData, 0, (IUdonEventReceiver)this);
            VRCAsyncGPUReadback.Request(compactIndexData, 0, (IUdonEventReceiver)this);
        }

        // Update preview texture for debugging
        debugVertexData.SetTexture("_MainTex", vertexData);
        debugActiveVertexData.SetTexture("_MainTex", activeVertexData);
        debugCompactVertexData.SetTexture("_MainTex", compactVertexData);
            
        // Update preview texture for debugging
        debugIndexData.SetTexture("_MainTex", indexData);
        debugActiveIndexData.SetTexture("_MainTex", activeIndexData);
        debugCompactIndexData.SetTexture("_MainTex", compactIndexData);
    }

    bool vertex;
    public bool triangles = true;

    public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
    {
        if (vertex)
        {
            vertex = false;
            if (!request.TryGetData(vertexReadback))
                return;

            int len = BitConverter.SingleToInt32Bits(vertexReadback[vertexReadback.Length - 1].r);

            Debug.Log("Vertices: " + len);

            //Vector3[] vertices = new Vector3[len];
            //int[] triangles = new int[len];
            //Array.Copy(Triangles, triangles, len);

            Color[] colors = new Color[len];
            if (colors.Length > vertexReadback.Length)
            {
                Debug.LogError("Shader error!");
                return;
            }

            Array.Copy(vertexReadback, colors, len);
            
            //for (int i = 0; i < len; i++)
            //    vertices[i] = new Vector3(vertexReadback[i].r, vertexReadback[i].g, vertexReadback[i].b);
            
            //mesh.SetVertices(vertices, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
            mesh.Clear(true);
            mesh.SetVertices(new Vector3[len], 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
            mesh.SetColors(colors, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
            //mesh.SetIndices(triangles, MeshTopology.Points, 0, false);
        }
        else
        {
            if (!request.TryGetData(indexReadback))
                return;

            int len = BitConverter.ToInt32(indexReadback, indexReadback.Length - 4);
            int[] indices = new int[len * 4];
            Buffer.BlockCopy(indexReadback, 0, indices, 0, len * 4 * 4);

            if (triangles)
            {
                mesh.SetIndices(indices, MeshTopology.Quads, 0, false);
               // mesh.RecalculateNormals();
            }

            Debug.Log("Indices: " + indices.Length);
            text.text = "Indices: " + indices.Length;
        }
    }
}