
using UdonSharp;
using UnityEngine;
using VRCVolumes;

public class VolumeAreaManagerCallback : UdonSharpBehaviour
{
    public virtual void OnAreaChange(Vector3Int chunkPos, Vector3Int prevPos) {}
    public virtual void OnNewChunkLoad(VolumeChunk chunk) {}
    public virtual void OnNewDataLoad(VolumeData data) {}
    public virtual void OnEdit(Bounds bounds) {}
    public virtual void OnColliderBuildDone(ulong key, Mesh mesh) {}
    public virtual void OnMeshBuildDone(ulong key, Mesh mesh) {}
}
