using System;
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
        None = 2,
    }

    [UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    public class EditSyncer : UdonSharpBehaviour
    {
        public VolumeAreaManager volumeManager;
        public Material editMaterial;
        public float syncInterval = 0.5f;
        private DataList fullHistory;
        private Vector4[] tempHistory;
        private int historyIndex;
        private int[] passes;
        private VRCPlayerApi localPlayer;

        private void Start()
        {
            fullHistory = new DataList();
            tempHistory = new Vector4[256];
            localPlayer = Networking.LocalPlayer;

            passes = new int[]
            {
                editMaterial.FindPass("Paint"),
                editMaterial.FindPass("Erase"),
                editMaterial.FindPass("Smooth"),
            };

            Sync();
        }

        private void HandleEvents(Vector4[] events)
        {
            foreach (Vector4 data in events)
            {
                fullHistory.Add(new DataToken(data));

                var extra = BitConverter.SingleToInt32Bits(data.w);
                int size = (extra >> 10) & 0xFFFF;
                int color = (extra >> 2) & 0xFF;
                int type = extra & 0x3;

                Edit(data, size, color, (EditType)type, false);
            }
        }

        [NetworkCallable(100)]
        public void SyncRecv(Vector4[] events)
        {
            HandleEvents(events);
        }

        [NetworkCallable(100)]
        public void SyncLateJoinRecv(int playerId, Vector4[] events)
        {
            if (localPlayer.playerId != playerId)
                return;
            
            Debug.Log("Recv Late join sync: " + events.Length);

            HandleEvents(events);
        }

        public void Sync()
        {
            if (historyIndex > 0)
            {
                Debug.Log("Sync: " + historyIndex);
                Vector4[] trimmed = new Vector4[historyIndex];
                Array.Copy(tempHistory, trimmed, historyIndex);

                SendCustomNetworkEvent(NetworkEventTarget.Others, nameof(SyncRecv), tempHistory);
                historyIndex = 0;
            }

            SendCustomEventDelayedSeconds(nameof(Sync), syncInterval);
        }

        public void Edit(Vector3 pos, int sizer, int color, EditType type, bool broadcast = true)
        {
            // TODO: This fixes index out of bounds but might break situations where the users modifies 
            // a lot of chunks simultaneously 
            if (historyIndex >= tempHistory.Length)
                return;

            if (broadcast)
            {         
                Vector4 data = pos;
                data.w = BitConverter.Int32BitsToSingle(((sizer & 0xFFFF) << 10) | ((color & 0xFF) << 2) | (int)type);

                tempHistory[historyIndex++] = data;
                fullHistory.Add(new DataToken(data));
            }

            float size = sizer / 2f;
            Bounds bounds = new Bounds(pos, Vector3.one * size * 2f);
            editMaterial.SetVector("_SphereFrom", volumeManager.WorldToGridPos(pos));
            editMaterial.SetVector("_SphereTo", volumeManager.WorldToGridPos(pos));
            editMaterial.SetFloat("_SphereRadius", (float)size * volumeManager.GridSize / 2.0f / volumeManager.transform.localScale.x);
            editMaterial.SetInteger("_SphereColor", color);
            volumeManager.Edit(bounds, editMaterial, passes[(int)type]);
        }

        public override void OnPlayerJoined(VRCPlayerApi player)
        {
            if (player.isLocal)
                return;

            if (!localPlayer.isMaster)
                return;

            Debug.Log("Send Late join sync: " + fullHistory.Count);

            int size = fullHistory.Count;
            int p = 0;
            while (size > 0)
            {
                int c = Math.Min(size, 1023);
                Vector4[] data = new Vector4[c];
                for (int i = 0; i < data.Length; i++)
                    data[i] = (Vector4)fullHistory[i + p].Reference;

                SendCustomNetworkEvent(NetworkEventTarget.Others, nameof(SyncLateJoinRecv), player.playerId, data);

                p += c;
                size -= c;
            }
        }
    }
}