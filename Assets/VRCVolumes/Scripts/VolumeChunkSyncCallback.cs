
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class VolumeChunkSyncCallback : UdonSharpBehaviour
{
    public void OnChunkSyncData(VolumeData volume, Color[] data) {}
}
