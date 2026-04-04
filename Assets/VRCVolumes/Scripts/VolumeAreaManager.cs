using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDKBase;

namespace VRCVolumes
{
    [RequireComponent(typeof(VolumeBuilder))]
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class VolumeAreaManager : UdonSharpBehaviour
    {
        #region Serialized Fields
        [Header("Settings")]
        // if true will offset data textures to fix chunk borders for MarchingCubes
        public bool Chunked = true;
        public bool Collider = true;
        public bool Lod = true;
        public int AutoLoadChunks = 0;
        public bool AutoLoadChunksAsSphere = false;
        public int GridSize = 64;
        public bool WaitForBuildQueue;
        public Material volumeMaterial, generateMaterial;

        [Header("References")]
        public BulkInstantiate chunkInstantiate;
        public Material copyWeightsMaterial;

        [Header("Debug")]
        public bool debug_limitedChunkHeightGeneration = false;
        public int debug_minChunkHeight = -1;
        public int debug_maxChunkHeight = 1;
        #endregion

        #region Local Fields
        private VolumeBuilder builder;
        private DataDictionary chunks, datas;
        private RenderTexture tempData, tempChunkData, tempTexDataCombined;
        private int copyPass, copySubPass;

        // We use a dict instead of a list because that allows us to not rebuild a mesh multiple times
        // downside order gets lost
        private DataDictionary buildQueue = new DataDictionary();

        private VRCPlayerApi localPlayer;

        #endregion

        #region Utils
        public Vector2Int TextureDimensionInt => builder.TextureDimensionInt;
        public int TotalTextureDataInBytes => datas.Count * builder.TextureDimensionInt.x * builder.TextureDimensionInt.y * 4 /* RFloat */; 

        public Vector3 WorldToGridPos(Vector3 pos) => transform.InverseTransformPoint(pos) * (GridSize - 2);

        private Vector3Int WorldToChunkPos(Vector3 pos)
        {
            pos = transform.InverseTransformPoint(pos);

            return new Vector3Int(
                Mathf.FloorToInt(pos.x),
                Mathf.FloorToInt(pos.y),
                Mathf.FloorToInt(pos.z)
            );
        }

        private bool IsChunkLoaded(ulong key)
        {
            return chunks.ContainsKey(key);
        }

        private VolumeChunk GetChunkAt(ulong key)
        {
            if (chunks.TryGetValue(key, out DataToken value))
                return value.AsVolumeChunk();
            
            var gameObject = chunkInstantiate.Spawn(transform);
            var chunk = VolumeChunk.Create(gameObject, key);
            chunks.SetValue(key, chunk.AsDataToken());

            if (!Chunked)
                gameObject.transform.localPosition += Vector3.one / 2f;

            return chunk;
        }

        public VolumeData GetDataAt(ulong key)
        {
            if (datas.TryGetValue(key, out DataToken value))
                return value.AsVolumeData();
            
            var gridPos = VolumeChunk.KeyToGrid(key);
            var chunk = builder.CreateData();

            // Required because when creating a new RenderTexture it is not guranteed to be empty
            GenerateChunkData(gridPos, chunk);

            var data = VolumeData.Create(key, chunk);
            datas.SetValue(key, data.AsDataToken());

            return data;
        }

        private void GenerateChunkData(Vector3 gridPos, RenderTexture data)
        {
            generateMaterial.SetVector("_ChunkPos", gridPos);
            generateMaterial.SetVector("_TargetSize", builder.TextureDimension);
            generateMaterial.SetVector("_VoxelDimension", Vector3.one * (GridSize - 2));
            VRCGraphics.Blit(null, data, generateMaterial);
        }

        private VolumeChunk[] GetChunksInBounds(Bounds bounds)
        {
            float offset = Chunked ? 0.5f : 0.0f;
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

        private VolumeData[] GetDatasInBounds(Bounds bounds)
        {
            Vector3Int min = WorldToChunkPos(bounds.min);
            Vector3Int max = WorldToChunkPos(bounds.max);

            int maxCount = (max.x - min.x + 1) * (max.y - min.y + 1) * (max.z - min.z + 1);
            var result = new DataList[maxCount];
            int i = 0;

            for (int x = min.x; x <= max.x; x++)
            for (int y = min.y; y <= max.y; y++)
            for (int z = min.z; z <= max.z; z++)
            {
                var gridPos = new Vector3Int(x, y, z);
                result[i++] = (DataList)(object)GetDataAt(VolumeChunk.GridToKey(gridPos));
            }

            return (VolumeData[])(object[])result;
        }
        #endregion

        private void Start()
        {
            builder = GetComponent<VolumeBuilder>();

            if (Chunked)
                volumeMaterial.EnableKeyword("_CHUNKED_ON");
            else
                volumeMaterial.DisableKeyword("_CHUNKED_ON");

            builder.Setup(Vector3Int.one * (GridSize - 2), true, volumeMaterial, VolumeType.Surface);
            chunks = new DataDictionary();
            datas = new DataDictionary();
            tempData = builder.CreateData();
            tempChunkData = builder.CreateData();

            // Rotation breaks the bounds check which needs to be axis aligned, so we reset it - this is pretty sad, I would love to also be able to rotate the mesh
            transform.rotation = Quaternion.identity;

            // This texture will contained the 8 textures from in a single texture 2x4, this is because
            // there is no support for TextureArrays in UdonSharp and sampling 8 differnet textures is slow on Quest 
            tempTexDataCombined = new RenderTexture(builder.TextureDimensionInt.x * 2, builder.TextureDimensionInt.y * 4, 0, RenderTextureFormat.RFloat);
            tempTexDataCombined.filterMode = FilterMode.Point;
            tempTexDataCombined.Create();

            copyPass = copyWeightsMaterial.FindPass("Copy");
            copySubPass = copyWeightsMaterial.FindPass("CopySub");

            localPlayer = Networking.LocalPlayer;
        }

        public void OnDestroy()
        {
            DataList list = datas.GetValues();
            for (int i = 0; i < list.Count; i++)
                list[i].AsVolumeData().Destroy();
        }

        public void Edit(Bounds bounds, Material material, int pass = -1)
        {
            /// Update Datas ///
            foreach (VolumeData data in GetDatasInBounds(bounds))
            {
                RenderTexture texture = data.GetData();
                material.SetVector("_ChunkPos", data.GetGridPos());
                material.SetVector("_TargetSize", builder.TextureDimension);
                material.SetVector("_VoxelDimension", Vector3.one * (GridSize - 2));

                copyWeightsMaterial.SetTexture("_DataTex", texture);
                copyWeightsMaterial.SetVector("_TargetSize", builder.TextureDimension);
                VRCGraphics.Blit(null, tempData, copyWeightsMaterial, copyPass);

                material.SetTexture("_DataTex", tempData);

                VRCGraphics.Blit(null, texture, material, pass);

                if (Lod)
                    data.ComputeLODs(this);
            }

            /// Add Chunks to update queue ///
            foreach (VolumeChunk chunk in GetChunksInBounds(bounds))
            {
                chunk.MarkEdited();
                buildQueue[chunk.GetKey()] = chunk.AsDataToken();
            }
        }

        public void LoadChunks(Bounds bounds)
        {
            foreach (VolumeChunk chunk in GetChunksInBounds(bounds))
                LoadChunk(chunk);
        }

        public void LoadChunk(VolumeChunk chunk)
        {
            buildQueue[chunk.GetKey()] = chunk.AsDataToken();
        }

        private Texture GetChunkData(VolumeChunk chunk)
        {
            // If this chunk was not edited yet, we do not have any data chunks
            // so instead we will just temporarily generate a preview, we do this
            // to save on memory. This is only required when using this for terrain.
            if (!chunk.WasEdited())
            {
                if (Chunked)
                {
                    copyWeightsMaterial.SetVector("_TargetSize", builder.TextureDimension);
                    for (int i = 0; i < 8; i++)
                    {
                        GenerateChunkData(chunk.GetGridPos() - new Vector3Int(1 - i % 2, 1 - i / 2 % 2, 1 - i / 4), tempChunkData);

                        copyWeightsMaterial.SetTexture("_DataTex", tempChunkData);
                        copyWeightsMaterial.SetInteger("_TextureIdx", i);
                        VRCGraphics.Blit(null, tempTexDataCombined, copyWeightsMaterial, copySubPass);
                    }

                    return tempTexDataCombined;
                }
                else
                {
                    GenerateChunkData(chunk.GetGridPos(), tempChunkData);
                    return tempChunkData;
                }
            }


            var data = chunk.GetDataRefs(this);

            if (Chunked)
            {
                copyWeightsMaterial.SetVector("_TargetSize", builder.TextureDimension);
                for (int i = 0; i < data.Count; i++)
                {
                    copyWeightsMaterial.SetTexture("_DataTex", data[i].AsVolumeData().GetData());
                    copyWeightsMaterial.SetInteger("_TextureIdx", i);
                    VRCGraphics.Blit(null, tempTexDataCombined, copyWeightsMaterial, copySubPass);
                }

                return tempTexDataCombined;
            }
            else
            {
                return data[0].AsVolumeData().GetData();
            }
        }

        Vector3Int prevPos = Vector3Int.one * 1000000;

        /// <summary>
        /// Forces reloading of chunks, does not reset data chunks (edits stay)
        /// </summary>
        public void Reload()
        {
            // Forces regeneration of chunks
            prevPos = Vector3Int.one * 1000000;

            DataList list = chunks.GetValues();
            for (int i = 0; i < list.Count; i++)
                list[i].AsVolumeChunk().Destroy();

            chunks.Clear();
            buildQueue.Clear();
        }

        private void Update()
        {
            if ((!WaitForBuildQueue || !builder.IsBuilding) && buildQueue.Count > 0)
            {
                var key = buildQueue.GetKeys()[0];
                VolumeChunk chunk = buildQueue[key].AsVolumeChunk();

                // The added time is to force it to rebuild after 1 / 2 seconds
                builder.Build(key.ULong, GetChunkData(chunk), chunk.GetMeshFilter().sharedMesh, Collider ? chunk.GetMeshCollider() : null);
                buildQueue.Remove(key);
            }

            Vector3Int chunkPos = WorldToChunkPos(localPlayer.GetPosition() + transform.localScale / 2f);
            if (prevPos != chunkPos && AutoLoadChunks > 0)
            {
                prevPos = chunkPos;
                int d = AutoLoadChunks - 1;

                for (int x = -d; x <= d; x++)
                for (int y = -d; y <= d; y++)
                for (int z = -d; z <= d; z++)
                {  
                    if (debug_limitedChunkHeightGeneration && ((chunkPos.y + y) < debug_minChunkHeight || (chunkPos.y + y) > debug_maxChunkHeight))
                        continue;

                    if (AutoLoadChunksAsSphere)
                    {
                        if ((x*x + y*y + z*z) > d*d)
                            continue;
                    }

                    var pos = chunkPos + new Vector3Int(x, y, z);
                    ulong key = VolumeChunk.GridToKey(pos);
                    if (!IsChunkLoaded(key))
                        LoadChunk(GetChunkAt(key));

                    // TODO: Optionally disable/enable chunk meshcollider here
                }
            }
        }

        #if UNITY_EDITOR && !COMPILER_UDONSHARP
        private void OnDrawGizmosSelected()
        {
            if (!Application.isPlaying || chunks == null || datas == null)
                return;

            float offset = Chunked ? 0.5f : 0f;

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