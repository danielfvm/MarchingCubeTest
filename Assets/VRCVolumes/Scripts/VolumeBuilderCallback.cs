
using UdonSharp;
using UnityEngine;

public class VolumeBuilderCallback : UdonSharpBehaviour
{
    public virtual void OnColliderBuildDone(ulong key, Mesh mesh) {}
    public virtual void OnMeshBuildDone(ulong key, Mesh mesh) {}
}
