
using Cysharp.Threading.Tasks.Triggers;
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class VolumePen : UdonSharpBehaviour
{
    public MarchingCubeMeshGenerator generator;
    public bool erase;
    private bool used;

    public void Update()
    {
        if (used)
        {
            if (erase)
                generator.Erase(transform.position);
            else
                generator.Draw(transform.position);
            
        }
    }


    public override void OnPickupUseDown() => used = true;
    public override void OnPickupUseUp() => used = false;
    public override void OnDrop() => used = false;
}
