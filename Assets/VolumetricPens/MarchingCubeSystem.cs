
using System;
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.Data;
using VRC.SDK3.Rendering;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
using VRC.Udon;
using VRC.Udon.Common.Interfaces;

namespace VolumetricPens
{
    public class MarchingCubeSystem : UdonSharpBehaviour
    {
        [Header("References")]
        public Chunk chunkPrefab;
        public LodSystem lod;

        [HideInInspector] public int passPaint, passReset, passErase;
        private RenderTexture buffer;
        
        private DataDictionary chunks = new DataDictionary();

        private readonly int VoxelAmount = 40 - 4; // -2 because of the border 

        public Text text;

            
        [Header("Compute")]
        public Material matPaint; 
        public Material matMarchingCube;
        public Material matWriteActiveTexels;
        public Material matCompactTexels;

        [Header("Debug")]
        public Material debugData;
        public Material debugVertex;
        public Material debugMipMap;
        public Material debugCompact; 
        
        private RenderTexture vertexData, compact, mipmapVertex;
        private const int texDim = 1024;
        [HideInInspector, NonSerialized] public readonly int[] Triangles = new int[texDim * texDim];
        
        private void Start()
        {
            transform.position = Vector3.zero;

            passPaint = matPaint.FindPass("Paint");
            passReset = matPaint.FindPass("Reset");
            passErase = matPaint.FindPass("Erase");

            buffer = new RenderTexture(texDim/4, texDim/4, 0, RenderTextureFormat.RFloat);
            buffer.filterMode = FilterMode.Point;
            buffer.Create();

            vertexData = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.ARGBFloat); // ARGBFloat seams to be cutoff on Quest to 16bit per channel
            vertexData.filterMode = FilterMode.Point;
            vertexData.Create();

            mipmapVertex = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.RFloat);
            mipmapVertex.useMipMap = true;
            mipmapVertex.filterMode = FilterMode.Point; 
            mipmapVertex.Create();

            compact = new RenderTexture(texDim / 2, texDim / 2, 0, RenderTextureFormat.ARGBFloat);
            compact.filterMode = FilterMode.Point;
            compact.Create();

            for (int i = 0; i < Triangles.Length; i++)
                Triangles[i] = i;
        }

        public void Reset()
        {
            var tokens = chunks.GetValues();
            for (int i = 0; i < chunks.Count; i++)
                Destroy(((Chunk)tokens[i].Reference).gameObject);
            chunks.Clear();
            gpuUpdateQueue.Clear();
            lod.Reset();
        }

        private Chunk GetChunk(ulong key)
        {
            if (chunks.TryGetValue(key, out DataToken token))
                return (Chunk)token.Reference;

            Chunk chunk = Chunk.Create(this, key);
            chunks.SetValue(key, chunk);
            return chunk;
        }

        [NetworkCallable]
        public void Paint(Vector3 from, Vector3 center, Vector3 to, bool erase, float radius)
        {
            // Manually unrolled loop and use dictonary as a trick to remove duplicate keys
            Vector3 localFrom = transform.InverseTransformPoint(from) + Vector3.one * 0.5f;
            Vector3 localCenter = transform.InverseTransformPoint(center) + Vector3.one * 0.5f;
            Vector3 localTo = transform.InverseTransformPoint(to) + Vector3.one * 0.5f;

            matPaint.SetVector("_PositionFrom", localFrom * VoxelAmount);
            matPaint.SetVector("_PositionCenter", localCenter * VoxelAmount);
            matPaint.SetVector("_PositionTo", localTo * VoxelAmount);
            matPaint.SetInteger("_VoxelAmount", VoxelAmount);
            matPaint.SetTexture("_PrevData", buffer);
            matPaint.SetVector("_TargetSize", new Vector2(buffer.width, buffer.height));

            Vector3 min = Vector3.Min(localFrom, Vector3.Min(localCenter, localTo));
            Vector3 max = Vector3.Max(localFrom, Vector3.Max(localCenter, localTo));

            int minX = Mathf.FloorToInt(min.x - radius);
            int maxX = Mathf.FloorToInt(max.x + radius);
            int minY = Mathf.FloorToInt(min.y - radius);
            int maxY = Mathf.FloorToInt(max.y + radius);
            int minZ = Mathf.FloorToInt(min.z - radius);
            int maxZ = Mathf.FloorToInt(max.z + radius);

            for (int x = minX; x <= maxX; x++)
            for (int y = minY; y <= maxY; y++)
            for (int z = minZ; z <= maxZ; z++)
            {
                Vector3 chunkCoord = new Vector3(x, y, z);
                ulong key = DataBlock.ToKey(chunkCoord);
                Chunk chunk = GetChunk(key);

                matPaint.SetVector("_Chunk", chunkCoord);

                VRCGraphics.Blit(chunk.data, buffer);
                VRCGraphics.Blit(null, chunk.data, matPaint, erase ? passErase : passPaint);

                lod.UpdateLOD(chunk);

                chunk.UpdateMesh();
            }

            int blockCount = chunks.Count;
            float sizeMb = blockCount * 256f * 256f * 4f / 1024f / 1024f;
            text.text = "Blocks: " + blockCount + "\nSize: " + (Mathf.Floor(sizeMb * 100f) / 100f)  + "mb";
        }

        #if UNITY_EDITOR && !COMPILER_UDONSHARP
        private void OnDrawGizmosSelected()
        {
            Matrix4x4 oldMatrix = Gizmos.matrix;
            Gizmos.matrix = transform.localToWorldMatrix;
            Gizmos.color = Color.white;

            foreach (var key in chunks.GetKeys())
                Gizmos.DrawWireCube(DataBlock.ToPos(key.ULong), Vector3.one);

            Gizmos.matrix = oldMatrix;
        }
        #endif

        private DataList gpuUpdateQueue = new DataList();

        public void GenerateMesh(Chunk chunk, int lod)
        {
            gpuUpdateQueue.Add(chunk);

            // Generate MarchingCube Triangle Data
            matMarchingCube.SetTexture("_Data", chunk.data);
            matMarchingCube.SetVector("_TargetSize", new Vector2(vertexData.width, vertexData.height));
            matMarchingCube.SetInteger("_Lod", lod);
            matMarchingCube.SetInteger("_VoxelAmount", VoxelAmount);
            VRCGraphics.Blit(null, vertexData, matMarchingCube);
                
            matWriteActiveTexels.SetTexture("_DataTex", vertexData);
            VRCGraphics.Blit(null, mipmapVertex, matWriteActiveTexels);

            // Compute CompactSparseTexture
            matCompactTexels.SetTexture("_DataTex", vertexData);
            matCompactTexels.SetTexture("_ActiveTexelMap", mipmapVertex);
            matCompactTexels.SetVector("_TargetSize", new Vector2(compact.width, compact.height));
            matCompactTexels.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(vertexData.width, 2)));
            VRCGraphics.Blit(null, compact, matCompactTexels);

            // Just for visualization
            debugData.SetTexture("_MainTex", chunk.data);
            debugVertex.SetTexture("_MainTex", vertexData);
            debugMipMap.SetTexture("_MainTex", mipmapVertex);
            debugCompact.SetTexture("_MainTex", compact);

            VRCAsyncGPUReadback.Request(compact, 0, (IUdonEventReceiver)this);
        }

        private readonly Color[] tempData = new Color[texDim * texDim / 4];

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
                Debug.LogError("Not % 3!");
                return;
            }

            // This sadly is as of now, unavoidable :/
            /*Vector3[] vertices = new Vector3[len];
            for (int i = 0; i < len; i ++)
                vertices[i] = new Vector3(data[i].r, data[i].g, data[i].b);*/

            var colors = new Color[len];
            Array.Copy(tempData, colors, len);

            int[] triangles = new int[len];
            Array.Copy(Triangles, triangles, len);

            if (!gpuUpdateQueue.TryGetValue(0, out DataToken chunkToken)) {
                Debug.LogError("Failed to get queue element!");
                return;
            }

            gpuUpdateQueue.RemoveAt(0);

            Chunk chunk = (Chunk)chunkToken.Reference;

            Mesh mesh = chunk.mesh[0];
            mesh.Clear(true);
            mesh.SetVertices(new Vector3[len], 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
            mesh.SetColors(colors, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
            mesh.SetIndices(triangles, MeshTopology.Triangles, 0, false);

            //Debug.Log("Mesh updated!");
        }
    }
}