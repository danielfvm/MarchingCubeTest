using System;
using DeanCode;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDK3.UdonNetworkCalling;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

namespace VRCVolumes
{
    public enum EditType
    {
        Paint = 0,
        Erase = 1,
        Smooth = 2,
        None = 3,
    }

    [UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    public class EditSyncer : VolumeAreaManagerCallback
    {
        public VolumeAreaManager volumeManager;
        public NotificationManager notificationManager;
        public Material editMaterial;
        public float syncInterval = 0.5f;
        private int historyIndex;
        private int[] passes;
        private VRCPlayerApi localPlayer;
        private DataDictionary fullHistory, tempHistory;
        private Notification notification;
        public const int MAX_PACKETS = 2048;

        private void Start()
        {
            volumeManager.Register(this);

            fullHistory = new DataDictionary();
            tempHistory = new DataDictionary();
            localPlayer = Networking.LocalPlayer;

            passes = new int[]
            {
                editMaterial.FindPass("Paint"),
                editMaterial.FindPass("Erase"),
                editMaterial.FindPass("Smooth"),
            };

            SyncInterval();
        }

        public int Encode(ulong key, int type, int size, int color, Vector3 worldPos)
        {
            Vector3 chunkSize = volumeManager.transform.localScale;
            Vector3 local = worldPos - Vector3.Scale(VolumeChunk.KeyToGrid(key), chunkSize);
            int x = (int)(local.x / chunkSize.x * 0xFF);
            int y = (int)(local.y / chunkSize.y * 0xFF);
            int z = (int)(local.z / chunkSize.z * 0xFF);

            return (type & 0x3)
                 | ((size & 0x7) << 2)
                 | ((color & 0x7) << 5) // TODO: Does not support the full 32 bit color range!
                 | x << 8
                 | y << 16
                 | z << 24;
        }

        public void Decode(ulong key, int data, out int type, out int size, out int color, out Vector3 worldPos)
        {
            type = data & 0x3;
            size = (data >> 2) & 0x7;
            color = (data >> 5) & 0x7;

            Vector3 chunkSize = volumeManager.transform.localScale;
            Vector3 local = new Vector3(
                (data >>  8) & 0xFF,
                (data >> 16) & 0xFF,
                (data >> 24) & 0xFF
            ) / 0xFF;

            worldPos = Vector3.Scale(VolumeChunk.KeyToGrid(key) + local, chunkSize);
        }

        private void HandleEvents(ulong key, int[] events)
        {
            foreach (int data in events)
            {
                Decode(key, data, out int type, out int size, out int color, out Vector3 worldPos);
                Edit(worldPos, size, color, (EditType)type, false);
            }
        }

        [NetworkCallable(100)]
        public void SyncRecv(ulong key, int[] events)
        {
            HandleEvents(key, events);
        }

        [NetworkCallable(100)]
        public void SyncRecvTarget(ulong key, int playerId, int[] events)
        {
            if (localPlayer.playerId != playerId)
                return;

            if (notification == null)
                notification = notificationManager._SendNotification("Receiving " + VolumeChunk.KeyToIntGrid(key), NotificationType.Loading);

            Debug.Log($"Recv Sync {key}: {events.Length}");
            HandleEvents(key, events);
        }

        [NetworkCallable(100)]
        public void SyncRecvTargetDone(ulong key, int playerId)
        {
            if (localPlayer.playerId != playerId)
                return;

            if (notification != null)
            {
                notification.Close();
                notification = null;
            }
            
            Debug.Log($"Recv Sync {key}: Done");
        }

        public void SyncInterval()
        {
            var keys = tempHistory.GetKeys();
            for (int i = 0; i < keys.Count; i++)
            {
                var key = keys[i].ULong;
                var data = tempHistory[key].DataList;
                int[] events = new int[data.Count];

                for (int j = 0; j < events.Length; j++)
                    events[j] = data[j].Int;

                SendCustomNetworkEvent(NetworkEventTarget.Others, nameof(SyncRecv), key, events);
            }

            tempHistory.Clear();

            SendCustomEventDelayedSeconds(nameof(SyncInterval), syncInterval);
        }

        public void Edit(Vector3 worldPos, int size, int color, EditType type, bool broadcast = true)
        {
            if (broadcast)
            {
                ulong key = VolumeChunk.GridToKey(volumeManager.WorldToChunkPos(worldPos));
                int data = Encode(key, (int)type, size, color, worldPos);

                if (!fullHistory.ContainsKey(key))
                    fullHistory.SetValue(key, new DataList());
                if (!tempHistory.ContainsKey(key))
                    tempHistory.SetValue(key, new DataList());

                // TODO: This fixes index out of bounds but might break situations where the users modifies 
                // a lot of chunks simultaneously 
                if (tempHistory[key].DataList.Count >= MAX_PACKETS)
                    return;

                fullHistory[key].DataList.Add(data);
                tempHistory[key].DataList.Add(data);
            }

            float s = size / 2f;
            Bounds bounds = new Bounds(worldPos, Vector3.one * s * 2f);
            editMaterial.SetVector("_SphereFrom", volumeManager.WorldToGridPos(worldPos));
            editMaterial.SetVector("_SphereTo", volumeManager.WorldToGridPos(worldPos));
            editMaterial.SetFloat("_SphereRadius", (float)s * volumeManager.GridSize / 2.0f / volumeManager.transform.localScale.x);
            editMaterial.SetInteger("_SphereColor", (int)color);
            volumeManager.Edit(bounds, editMaterial, passes[(int)type]);
        }

        private DataList lateJoinSync = new DataList();

        [NetworkCallable]
        public void SyncRequest(ulong key, int playerId)
        {
            if (!localPlayer.isMaster)
                return;

            if (!fullHistory.ContainsKey(key))
                return;

            lateJoinSync.Add(new DataToken(new object[]
            {
                key,
                playerId,
                fullHistory[key].DataList
            }));
        }

        public override void OnNewDataLoad(VolumeData data)
        {
            if (localPlayer.isMaster)
                return;
            
            var key = data.GetKey();

            SendCustomNetworkEvent(NetworkEventTarget.All, nameof(SyncRequest), key, localPlayer.playerId);
        }

        public void Update()
        {
            if (tempHistory.Count != 0)
                return;
            
            if (lateJoinSync.Count == 0)
            {
                if (notification != null)
                {
                    notification.Close();
                    notification = null;
                }
                return;
            }
            
            var data = (object[])lateJoinSync[0].Reference;
            var key = (ulong)data[0];
            var playerId = (int)data[1];
            var history = (DataList)data[2];

            if (notification == null)
                notification = notificationManager._SendNotification("Sending " + VolumeChunk.KeyToIntGrid(key), NotificationType.Loading);

            if (Networking.IsClogged)
                return;

            int[] events = new int[Mathf.Min(history.Count, MAX_PACKETS)];

            for (int j = 0; j < events.Length; j++)
                events[j] = history[j].Int;

            SendCustomNetworkEvent(NetworkEventTarget.Others, nameof(SyncRecvTarget), key, playerId, events);

            history.RemoveRange(0, events.Length);

            if (history.Count == 0)
            {
                lateJoinSync.RemoveAt(0);
                SendCustomNetworkEvent(NetworkEventTarget.Others, nameof(SyncRecvTargetDone), key, playerId);
            }
        }
    }
}