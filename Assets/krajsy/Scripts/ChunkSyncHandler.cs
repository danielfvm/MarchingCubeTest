
using System;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon;
using VRC.Udon.Common;
using VRC.Udon.Common.Interfaces;

namespace VolumetricPens
{
    [UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    public class ChunkSyncHandler : UdonSharpBehaviour
    {
        public MarchingCubeSystem system;

        public int currentChunkIndex = 0;
        public Chunk selectedChunk = null;

        public bool shouldSync = true;
        [UdonSynced] public ulong selectedChunkKey = 0;

        [UdonSynced] public double syncTime = 0;
        [UdonSynced] public byte[] syncData = new byte[texDim * texDim / 8];

        private const int texDim = 1024/4;
        // [NonSerialized] public Color32[] tempData32 = new Color32[texDim * texDim];
        [NonSerialized] public float[] tempFloatData = new float[texDim * texDim];
        [NonSerialized] public Color32[] decodingTempData32 = new Color32[texDim * texDim];

        [Header("Decoding Storage")]
        public Chunk decodingForChunk = null;
        public ulong decodingChunkKey = 0;
        public byte[] decodingSyncData = new byte[texDim * texDim / 8];
        public bool isDecoding = false;
        // public Texture2D tempTexture = new Texture2D(texDim, texDim, TextureFormat.RFloat, false);
        public Texture2D tempTexture;

        [Header("Encoding/Decoding Speed per frame")]
        int encodeSyncDataCurrentStep = 0;
        public int encodeSyncDataMaxSteps = 512;
        int decodeSyncDataCurrentStep = 0;
        public int decodeSyncDataMaxSteps = 512;

        [Header("Debug Variables")]
        public float testThreshold = .5f;
        public bool unityTestBool;

        void Start()
        {
            tempTexture = new Texture2D(texDim, texDim, TextureFormat.RFloat, false);
            tempTexture.filterMode = FilterMode.Point;

            if (Networking.LocalPlayer.IsOwner(this.gameObject))
            {
                SendCustomEventDelayedFrames(nameof(CustomUpdate), 1);
            }
        }

        public void CustomUpdate()
        {
            DataList existingChunks = system.chunkDict.GetValues();

            if (existingChunks.Count <= 0)
            {
                // Debug.Log($"[{nameof(ChunkSyncHandler)}] {nameof(CustomUpdate)}() existingChunks.Count <= 0");
                SendCustomEventDelayedFrames(nameof(CustomUpdate), 10);
                return;
            }

            currentChunkIndex %= existingChunks.Count;

            selectedChunk = (Chunk)existingChunks[currentChunkIndex].Reference;
            if (selectedChunk == null)
            {
                Debug.LogWarning($"[{nameof(ChunkSyncHandler)}] {nameof(CustomUpdate)}() selectedChunk == null");
                SendCustomEventDelayedFrames(nameof(CustomUpdate), 10);
                return;
            }

            Debug.Log($"[{nameof(ChunkSyncHandler)}] {nameof(CustomUpdate)}() selectedChunk: {selectedChunk.gameObject.name}");
            selectedChunkKey = selectedChunk.key;

            // selectedChunk
            VRCAsyncGPUReadback.Request(selectedChunk.data, 0, (IUdonEventReceiver)this);

            currentChunkIndex++;
            // SendCustomEventDelayedFrames(nameof(CustomUpdate), 1);
            // RequestSerialization();
        }

        public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
        {
            if (request.hasError)
            {
                Debug.LogError($"[{nameof(ChunkSyncHandler)}] GPU READBACK FAILED");
                return;
            }

            if (!request.TryGetData(tempFloatData))
            {
                Debug.LogError($"[{nameof(ChunkSyncHandler)}] GET GPU DATA FAILED");
                return;
            }

            // request.TryGetData(syncData);
            // request.TryGetData()

            if (selectedChunk == null)
            {
                return;
            }

            EncodeSyncData();

            // #if UNITY_EDITOR
            // SendCustomEventDelayedFrames(nameof(Run_OnPreSerialization), 10);
            // #else
            // RequestSerialization();
            // #endif
        }

        public void EncodeSyncData()
        {
            int i = 0;
            for (i = encodeSyncDataCurrentStep; i < Mathf.Min(syncData.Length, encodeSyncDataCurrentStep + encodeSyncDataMaxSteps); i++)
            {
                syncData[i] = 0;
                syncData[i] |= (byte)((tempFloatData[i*8 + 0] >= testThreshold ? 1 : 0) << 0);
                syncData[i] |= (byte)((tempFloatData[i*8 + 1] >= testThreshold ? 1 : 0) << 1);
                syncData[i] |= (byte)((tempFloatData[i*8 + 2] >= testThreshold ? 1 : 0) << 2);
                syncData[i] |= (byte)((tempFloatData[i*8 + 3] >= testThreshold ? 1 : 0) << 3);
                syncData[i] |= (byte)((tempFloatData[i*8 + 4] >= testThreshold ? 1 : 0) << 4);
                syncData[i] |= (byte)((tempFloatData[i*8 + 5] >= testThreshold ? 1 : 0) << 5);
                syncData[i] |= (byte)((tempFloatData[i*8 + 6] >= testThreshold ? 1 : 0) << 6);
                syncData[i] |= (byte)((tempFloatData[i*8 + 7] >= testThreshold ? 1 : 0) << 7);
            }

            encodeSyncDataCurrentStep = i;

            if (encodeSyncDataCurrentStep >= syncData.Length)
            {
                Debug.Log($"[{nameof(ChunkSyncHandler)}] {nameof(EncodeSyncData)}() syncData compiled and compressed!");

                #if UNITY_EDITOR
                SendCustomEventDelayedFrames(nameof(Run_OnPreSerialization), 10);
                #else
                RequestSerialization();
                #endif

                encodeSyncDataCurrentStep = 0;
                return;
            }

            SendCustomEventDelayedFrames(nameof(EncodeSyncData), 1);
        }

        public void DecodeSyncData()
        {
            int i = 0;
            for (i = decodeSyncDataCurrentStep; i < Mathf.Min(decodingSyncData.Length, decodeSyncDataCurrentStep + decodeSyncDataMaxSteps); i++)
            {
                decodingTempData32[i*8 + 0] = new Color32((byte)((decodingSyncData[i] >> 0 & 1) * 255), (byte)((decodingSyncData[i] >> 0 & 1) * 255), (byte)((decodingSyncData[i] >> 0 & 1) * 255), 255);
                decodingTempData32[i*8 + 1] = new Color32((byte)((decodingSyncData[i] >> 1 & 1) * 255), (byte)((decodingSyncData[i] >> 1 & 1) * 255), (byte)((decodingSyncData[i] >> 1 & 1) * 255), 255);
                decodingTempData32[i*8 + 2] = new Color32((byte)((decodingSyncData[i] >> 2 & 1) * 255), (byte)((decodingSyncData[i] >> 2 & 1) * 255), (byte)((decodingSyncData[i] >> 2 & 1) * 255), 255);
                decodingTempData32[i*8 + 3] = new Color32((byte)((decodingSyncData[i] >> 3 & 1) * 255), (byte)((decodingSyncData[i] >> 3 & 1) * 255), (byte)((decodingSyncData[i] >> 3 & 1) * 255), 255);
                decodingTempData32[i*8 + 4] = new Color32((byte)((decodingSyncData[i] >> 4 & 1) * 255), (byte)((decodingSyncData[i] >> 4 & 1) * 255), (byte)((decodingSyncData[i] >> 4 & 1) * 255), 255);
                decodingTempData32[i*8 + 5] = new Color32((byte)((decodingSyncData[i] >> 5 & 1) * 255), (byte)((decodingSyncData[i] >> 5 & 1) * 255), (byte)((decodingSyncData[i] >> 5 & 1) * 255), 255);
                decodingTempData32[i*8 + 6] = new Color32((byte)((decodingSyncData[i] >> 6 & 1) * 255), (byte)((decodingSyncData[i] >> 6 & 1) * 255), (byte)((decodingSyncData[i] >> 6 & 1) * 255), 255);
                decodingTempData32[i*8 + 7] = new Color32((byte)((decodingSyncData[i] >> 7 & 1) * 255), (byte)((decodingSyncData[i] >> 7 & 1) * 255), (byte)((decodingSyncData[i] >> 7 & 1) * 255), 255);
            }

            decodeSyncDataCurrentStep = i;

            if (decodeSyncDataCurrentStep >= decodingSyncData.Length)
            {
                Debug.Log($"[{nameof(ChunkSyncHandler)}] {nameof(DecodeSyncData)}() syncData decompiled!");

                if (decodingForChunk != null)
                {
                    // Texture2D tempTexture = new Texture2D(texDim, texDim, TextureFormat.RFloat, false);
                    // tempTexture = new Texture2D(texDim, texDim, TextureFormat.RFloat, false);
                    // tempTexture.filterMode = FilterMode.Point;
                    tempTexture.SetPixels32(decodingTempData32);
                    // tempTexture.SetPixels(tempData);
                    tempTexture.Apply();

                    VRCGraphics.Blit(tempTexture, decodingForChunk.data);
                    Debug.Log($"[{nameof(ChunkSyncHandler)}] {nameof(DecodeSyncData)}() Blit success?");

                    system.lod.UpdateLOD(decodingForChunk);

                    decodingForChunk.UpdateMesh();

                    decodingForChunk.hasBeenSynced = true;
                }

                isDecoding = false;
                decodeSyncDataCurrentStep = 0;
                return;
            }

            SendCustomEventDelayedFrames(nameof(DecodeSyncData), 1);
        }

        #if UNITY_EDITOR
        public void Run_OnPreSerialization() => OnPreSerialization();
        #endif
        public override void OnPreSerialization()
        {
            Debug.Log($"[{nameof(ChunkSyncHandler)}] {nameof(OnPreSerialization)}()");
            syncTime = Networking.GetServerTimeInSeconds();

            #if UNITY_EDITOR
            SendCustomEventDelayedFrames(nameof(Run_OnPostSerialization), 1);
            #endif
        }

        #if UNITY_EDITOR
        public void Run_OnPostSerialization() => OnPostSerialization(new SerializationResult());
        #endif
        public override void OnPostSerialization(SerializationResult result)
        {
            Debug.Log($"[{nameof(ChunkSyncHandler)}] {nameof(OnPostSerialization)}()");
            SendCustomEventDelayedFrames(nameof(CustomUpdate), 1);
        }

        #if UNITY_EDITOR
        public void Run_OnDeserialization() => OnDeserialization();
        #endif
        public override void OnDeserialization()
        {
            Debug.Log($"[{nameof(ChunkSyncHandler)}] {nameof(OnDeserialization)}()");

            if (isDecoding || !shouldSync) return;

            decodingSyncData = syncData;
            decodingChunkKey = selectedChunkKey;
            if (unityTestBool)
            {
                Vector3 tempVec = Chunk.ToPos(decodingChunkKey);
                tempVec.y += 2;
                decodingChunkKey = Chunk.ToKey(tempVec);
                // Debug.Log($"Chunk.ToPos(decodingChunkKey): {Chunk.ToPos(decodingChunkKey)}");
            }
            system.TryGetChunk(decodingChunkKey, out decodingForChunk);

            if (decodingForChunk.hasBeenSynced)
            {
                return;
            }

            isDecoding = true;

            DecodeSyncData();
        }

        public override void OnOwnershipTransferred(VRCPlayerApi player)
        {
            if (player.isLocal)
            {
                SendCustomEventDelayedFrames(nameof(CustomUpdate), 1);
            }
        }

        public void ToggleSyncing()
        {
            shouldSync = !shouldSync;
        }
    }
}
