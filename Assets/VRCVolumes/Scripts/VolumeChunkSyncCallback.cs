
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class VolumeChunkSyncCallback : UdonSharpBehaviour
{
    public virtual void OnChunkSyncData(VolumeData volume, Color[] data) {}
}
