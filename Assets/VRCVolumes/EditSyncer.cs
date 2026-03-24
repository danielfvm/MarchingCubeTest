using System;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDK3.UdonNetworkCalling;
using VRC.Udon.Common.Interfaces;
using VRCVolumes;

public class EditSyncer : UdonSharpBehaviour
{
    public VolumeAreaManager volumeManager;
    public Material editMaterial;
    public float syncInterval = 0.5f;
    private DataList fullHistory;
    private Vector4[] tempHistory;
    private int historyIndex;

    [NetworkCallable(100)]
    public void SyncRecv(Vector4[] events)
    {
        foreach (Vector4 data in events)
        {
            fullHistory.Add(new DataToken(data));

            var extra = BitConverter.SingleToInt32Bits(data.z);
            int size = extra >> 8;
            int color = extra & 0xFF;

            Paint(data, size, color, false);
        }
    }

    private void Start()
    {
        fullHistory = new DataList();
        tempHistory = new Vector4[256];
        Sync();
    }

    public void Sync()
    {
        if (historyIndex > 0)
        {
            Vector4[] trimmed = new Vector4[historyIndex];
            Array.Copy(tempHistory, trimmed, historyIndex);

            SendCustomNetworkEvent(NetworkEventTarget.Others, nameof(Sync), tempHistory);
            historyIndex = 0;
        }

        SendCustomEventDelayedSeconds(nameof(Sync), syncInterval);
    }

    public void Paint(Vector3 pos, int size, int color, bool broadcast = true)
    {
        Vector4 data = pos;
        data.z = BitConverter.Int32BitsToSingle((size << 8) | (color & 0xFF));

        // TODO: This fixes index out of bounds but might break situations where the users modifies 
        // a lot of chunks simultaneously 
        if (historyIndex >= tempHistory.Length)
            return;

        if (broadcast)
            tempHistory[historyIndex++] = data;
    
        // TODO: Do the paint
    }
}
