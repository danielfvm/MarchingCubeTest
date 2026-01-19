
using UdonSharp;
using UnityEngine;
using VolumetricPens;
using VRC.SDKBase;
using VRC.Udon.Common;
using VRC.Udon.Common.Interfaces;

public class VolumePen : UdonSharpBehaviour
{
    public MarchingCubeMeshGenerator generator;
    public MarchingCubeSystem system;
    public bool erase;
    private bool used;

    int i = 0, j = 0;
    private Vector3[] positionHistory = new Vector3[3];
    private bool canDraw = true;
    private bool picked = false;
    public float radius = 0.2f;
    private VRCPlayerApi localPlayer;
    private bool inVR;

    public int colorIndex;
    public MeshRenderer meshRenderer;

    private void Start()
    {
        localPlayer = Networking.LocalPlayer;
        inVR = localPlayer.IsUserInVR();

        MaterialPropertyBlock block = new MaterialPropertyBlock();
        block.SetInteger("_ColorIndex", colorIndex);
        meshRenderer.SetPropertyBlock(block);
    }

    bool prevValue = false;

    public override void InputLookVertical(float value, UdonInputEventArgs args)
    {
        if (inVR && !prevValue && value > 0.5f)
            radius *= 1.2f;

        if (inVR && !prevValue && value < -0.5f)
            radius /= 1.2f;

        prevValue = Mathf.Abs(value) < 0.25f;
    }

    public void Update()
    {
        if (picked)
        {
            if (Input.GetKeyDown(KeyCode.Plus) || Input.GetKeyDown(KeyCode.KeypadPlus))
                radius *= 1.2f;
            if (Input.GetKeyDown(KeyCode.Minus) || Input.GetKeyDown(KeyCode.KeypadMinus))
                radius /= 1.2f;

            radius = Mathf.Clamp(radius, 0.02f, 1f);
            transform.localScale = Vector3.one * radius;
        }

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

        if (used && i % 2 == 0 && (canDraw || erase))
        {
            system.SendCustomNetworkEvent(
                NetworkEventTarget.All, 
                nameof(MarchingCubeSystem.Paint), 
                positionHistory[(i + 1) % 3], 
                positionHistory[(i + 2) % 3], 
                positionHistory[(i + 3) % 3], 
                erase, radius, colorIndex
            );
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

    // TODO: Not performant!
    private void OnTriggerStay(Collider other)
    {
        if (other.gameObject != null && other.gameObject.GetComponent<NoDrawZone>() != null)
            canDraw = false;
    }


    private void OnTriggerExit(Collider other)
    {
        if (other.gameObject != null && other.gameObject.GetComponent<NoDrawZone>() != null)
            canDraw = true;
    }

    public override void OnPickupUseDown() => used = true;
    public override void OnPickupUseUp() => used = false;
    public override void OnDrop() {
        picked = false;
        used = false;
    }

    public override void OnPickup() {
        picked = true;
    }
}
