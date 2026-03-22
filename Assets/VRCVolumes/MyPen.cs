
using UdonSharp;
using UnityEngine;
using VRC.Udon.Common;
using VRCVolumes;

public class MyPen : UdonSharpBehaviour
{
    public VolumeAreaManager volumeManager;
    public Material material;
    public MeshRenderer meshRenderer;
    public int colorIdx;
    private bool pressed;
    private int pass;

    private void Start()
    {
        pass = material.FindPass("Line");
        MaterialPropertyBlock block = new MaterialPropertyBlock();
        block.SetInteger("_ColorIndex", colorIdx);
        meshRenderer.SetPropertyBlock(block);
    }

    public override void OnPickupUseDown() => pressed = true;
    public override void OnPickupUseUp() {
        pressed = false;
        prev = Vector3.zero;
    }

    int i = 0;

    Vector3 prev = Vector3.zero;

    private void Update()
    {
        i++;
        if (pressed && i > 3)
        {
            i = 0;

            if (prev == Vector3.zero)
                prev = transform.position;

            var center = (prev + transform.position) / 2.0f;

            Bounds bounds = new Bounds(center, volumeManager.transform.localScale * 0.12f + new Vector3(
                Mathf.Abs(prev.x - transform.position.x),
                Mathf.Abs(prev.y - transform.position.y),
                Mathf.Abs(prev.z - transform.position.z)
            ));

            material.SetVector("_SphereFrom", volumeManager.WorldToGridPos(prev));
            material.SetVector("_SphereTo", volumeManager.WorldToGridPos(transform.position));
            material.SetFloat("_SphereRadius", 0.1f * volumeManager.gridSize / 2);
            material.SetInteger("_SphereColor", colorIdx);
            volumeManager.Edit(bounds, material, pass);

            prev = transform.position;
        }
    }
}
