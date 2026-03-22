
using System;
using UdonSharp;
using UnityEditor;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.Data;
using VRC.SDKBase;

namespace VRCVolumes
{
    [RequireComponent(typeof(VolumeBuilder))]
    public class VolumeAreaManager : UdonSharpBehaviour
    {
        #region Serialized Fields
        [Header("Settings")]
        // if true will offset data textures to fix chunk borders for MarchingCubes
        public bool chunked = true;
        public int gridSize = 64;
        public Material volumeMaterial, copyWeightsMaterial, editMaterial;
        public BulkInstantiate chunkInstantiate;
        public bool waitForBuildQueue;
        #endregion

        #region Local Fields
        private VolumeBuilder builder;
        private DataDictionary chunks, datas;
        private RenderTexture tempData, tempTexDataCombined;
        private int copyPass, clearPass, copySubPass;
        #endregion

        #region Utils
        public int TotalTextureDataInBytes => datas.Count * builder.TextureDimensionInt.x * builder.TextureDimensionInt.y * 4 /* RFloat */; 

        public Vector3 WorldToGridPos(Vector3 pos) => transform.InverseTransformPoint(pos) * gridSize;

        private Vector3Int WorldToChunkPos(Vector3 pos)
        {
            pos = transform.InverseTransformPoint(pos);

            return new Vector3Int(
                Mathf.FloorToInt(pos.x),
                Mathf.FloorToInt(pos.y),
                Mathf.FloorToInt(pos.z)
            );
        }

        private VolumeChunk GetChunkAt(ulong key)
        {
            if (chunks.TryGetValue(key, out DataToken value))
                return value.AsVolumeChunk();
            
            var gameObject = chunkInstantiate.Spawn(transform);
            var pos = VolumeChunk.KeyToIntGrid(key);
            var refs = new DataList(chunked ? new DataToken[] {
                GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(1, 1, 1))),
                GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(0, 1, 1))),
                GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(1, 0, 1))),
                GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(0, 0, 1))),
                GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(1, 1, 0))),
                GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(0, 1, 0))),
                GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(1, 0, 0))),
                GetDataAt(key),
            } : new DataToken[] { GetDataAt(key) });

            var chunk = VolumeChunk.Create(gameObject, key, refs);
            chunks.SetValue(key, chunk.AsDataToken());

            if (!chunked)
                gameObject.transform.localPosition += Vector3.one / 2f;

            return chunk;
        }

        private RenderTexture GetDataAt(ulong key)
        {
            if (datas.TryGetValue(key, out DataToken value))
                return (RenderTexture)value.Reference;
            
            var chunk = builder.CreateData();
            datas.SetValue(key, chunk);

            // Required because when creating a new RenderTexture it is not guranteed to be empty
            VRCGraphics.Blit(null, chunk, copyWeightsMaterial, clearPass);

            return chunk;
        }

        private VolumeChunk[] GetChunksInBounds(Bounds bounds)
        {
            float offset = chunked ? 0.5f : 0.0f;
            Vector3Int min = WorldToChunkPos(bounds.min + transform.localScale * offset);
            Vector3Int max = WorldToChunkPos(bounds.max + transform.localScale * offset);

            int maxCount = (max.x - min.x + 1) * (max.y - min.y + 1) * (max.z - min.z + 1);
            var result = new DataList[maxCount];
            int i = 0;

            for (int x = min.x; x <= max.x; x++)
            for (int y = min.y; y <= max.y; y++)
            for (int z = min.z; z <= max.z; z++)
                result[i++] = (DataList)(object)GetChunkAt(VolumeChunk.GridToKey(new Vector3Int(x, y, z)));

            return (VolumeChunk[])(object[])result;
        }

        private object[] GetDatasInBounds(Bounds bounds)
        {
            Vector3Int min = WorldToChunkPos(bounds.min);
            Vector3Int max = WorldToChunkPos(bounds.max);

            int maxCount = (max.x - min.x + 1) * (max.y - min.y + 1) * (max.z - min.z + 1);
            var result = new object[maxCount];
            int i = 0;

            for (int x = min.x; x <= max.x; x++)
            for (int y = min.y; y <= max.y; y++)
            for (int z = min.z; z <= max.z; z++)
            {
                var gridPos = new Vector3Int(x, y, z);
                result[i++] = new object[] { gridPos, GetDataAt(VolumeChunk.GridToKey(gridPos)) };
            }

            return result;
        }
        #endregion

        private void Start()
        {
            builder = GetComponent<VolumeBuilder>();

            if (chunked)
                volumeMaterial.EnableKeyword("_CHUNKED_ON");
            else
                volumeMaterial.DisableKeyword("_CHUNKED_ON");

            builder.Setup(Vector3Int.one * gridSize, true, volumeMaterial);
            chunks = new DataDictionary();
            datas = new DataDictionary();
            tempData = builder.CreateData();

            // Rotation breaks the bounds check which needs to be axis aligned, so we reset it - this is pretty sad, I would love to also be able to rotate the mesh
            //transform.rotation = Quaternion.identity;

            // This texture will contained the 8 textures from in a single texture 2x4, this is because
            // there is no support for TextureArrays in UdonSharp and sampling 8 differnet textures is slow on Quest 
            tempTexDataCombined = new RenderTexture(builder.TextureDimensionInt.x * 2, builder.TextureDimensionInt.y * 4, 0, RenderTextureFormat.RFloat);
            tempTexDataCombined.filterMode = FilterMode.Point;
            tempTexDataCombined.Create();

            copyPass = copyWeightsMaterial.FindPass("Copy");
            copySubPass = copyWeightsMaterial.FindPass("CopySub");
            clearPass = copyWeightsMaterial.FindPass("Clear");
        }

        public void OnDestroy()
        {
            DataList list = datas.GetValues();
            for (int i = 0; i < list.Count; i++)
                ((RenderTexture)list[i].Reference).Release();
        }

        private DataList buildQueue = new DataList();

        public void Edit(Bounds bounds, Material material, int pass = -1)
        {
            /// Update Datas ///
            foreach (object[] values in GetDatasInBounds(bounds))
            {
                Vector3Int gridPos = (Vector3Int)values[0];
                RenderTexture data = (RenderTexture)values[1];
                material.SetVector("_ChunkPos", new Vector3(gridPos.x, gridPos.y, gridPos.z));
                material.SetVector("_TargetSize", builder.TextureDimension);
                material.SetVector("_VoxelDimension", Vector3.one * gridSize);

                copyWeightsMaterial.SetTexture("_DataTex", data);
                copyWeightsMaterial.SetVector("_TargetSize", builder.TextureDimension);
                VRCGraphics.Blit(null, tempData, copyWeightsMaterial, copyPass);

                material.SetTexture("_DataTex", tempData);
                VRCGraphics.Blit(null, data, material, pass);
            }

            /// Add Chunks to update queue ///
            foreach (VolumeChunk chunk in GetChunksInBounds(bounds))
                buildQueue.Add(chunk.AsDataToken());
        }

        private Texture GetChunkData(VolumeChunk chunk)
        {
            var data = chunk.GetDataRefs();

            if (chunked)
            {
                copyWeightsMaterial.SetVector("_TargetSize", builder.TextureDimension);
                for (int i = 0; i < data.Count; i++)
                {
                    copyWeightsMaterial.SetTexture("_DataTex", (Texture)data[i].Reference);
                    copyWeightsMaterial.SetInteger("_TextureIdx", i);
                    VRCGraphics.Blit(null, tempTexDataCombined, copyWeightsMaterial, copySubPass);
                }

                return tempTexDataCombined;
            }
            else
            {
                return (Texture)data[0].Reference;
            }
        }

        private void Update()
        {
            if ((!waitForBuildQueue || !builder.IsBuilding) && buildQueue.Count > 0)
            {
                VolumeChunk chunk = buildQueue[0].AsVolumeChunk();
                builder.Build(false, GetChunkData(chunk), chunk.GetMeshFilter().sharedMesh);
                buildQueue.RemoveAt(0);
            }
        }

        #if UNITY_EDITOR && !COMPILER_UDONSHARP
        private void OnDrawGizmosSelected()
        {
            if (!Application.isPlaying || chunks == null || datas == null)
                return;

            float offset = chunked ? 0.5f : 0f;

            Matrix4x4 oldMatrix = Gizmos.matrix;
            Gizmos.matrix = transform.localToWorldMatrix;
            {
                /// Chunks ///
                Gizmos.color = Color.white;
                DataList list = chunks.GetKeys();
                for (int i = 0; i < list.Count; i++)
                    Gizmos.DrawWireCube(VolumeChunk.KeyToGrid(list[i].ULong), Vector3.one);

                /// Datas ///
                Gizmos.color = Color.yellow;
                list = datas.GetKeys();
                for (int i = 0; i < list.Count; i++)
                    Gizmos.DrawWireCube(VolumeChunk.KeyToGrid(list[i].ULong) + Vector3.one * offset, Vector3.one * 0.9f);
            }
            Gizmos.matrix = oldMatrix;
        }
        #endif
    }
}