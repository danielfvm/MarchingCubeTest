
using Cysharp.Threading.Tasks.Triggers;
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class VolumePen : UdonSharpBehaviour
{
    public MarchingCubeMeshGenerator generator;
    private bool used;

    public void Update()
    {
        if (used)
            generator.Draw(transform.position);
    }


    public override void OnPickupUseDown() => used = true;
    public override void OnPickupUseUp() => used = false;
    public override void OnDrop() => used = false;
}
