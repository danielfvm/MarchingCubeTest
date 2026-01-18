
using Cysharp.Threading.Tasks.Triggers;
using UdonSharp;
using UnityEngine;
using VolumetricPens;
using VRC.SDKBase;
using VRC.Udon;
using VRC.Udon.Common.Interfaces;

public class VolumePen : UdonSharpBehaviour
{
    public MarchingCubeMeshGenerator generator;
    public MarchingCubeSystem system;
    public bool erase;
    private bool used;

    int i = 0, j = 0;
    private Vector3[] positionHistory = new Vector3[3];

    public void Update()
    {
        if (!used)
        {
            j = 0;
            i = 0;
            positionHistory[0] = transform.position;
            positionHistory[1] = transform.position;
            positionHistory[2] = transform.position;
            return;
        }

        j++;

        if (j % 2 == 0)
            return;


        i++;
        positionHistory[i % 3] = transform.position;

        if (used && i % 2 == 0)
        {
            system.SendCustomNetworkEvent(NetworkEventTarget.All, nameof(MarchingCubeSystem.Paint), positionHistory[(i + 1) % 3], positionHistory[(i + 2) % 3], positionHistory[(i + 3) % 3], erase, 0.2f);
            //system.Paint(positionHistory[(i + 1) % 3], positionHistory[(i + 2) % 3], positionHistory[(i + 3) % 3], erase, 0.2f);
        }

        /*i++;
        if (used && i > 2)
        {
            i = 0;
            if (prevPos == Vector3.zero)
                prevPos = transform.position;

            system.Paint(prevPos, transform.position, erase, 0.2f);
            prevPos = transform.position;
        }

        if (!used)
            prevPos = Vector3.zero;*/
    }


    public override void OnPickupUseDown() => used = true;
    public override void OnPickupUseUp() => used = false;
    public override void OnDrop() => used = false;
}
