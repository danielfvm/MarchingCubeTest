
using UdonSharp;
using UnityEngine;
using VRCVolumes;

public class MyPen : UdonSharpBehaviour
{
    public EditSyncer syncer;
    public MeshRenderer meshRenderer;
    public int color;
    public EditType type;

    private bool pressed;

    private void Start()
    {
        MaterialPropertyBlock block = new MaterialPropertyBlock();
        block.SetInteger("_ColorIndex", color);
        meshRenderer.SetPropertyBlock(block);
    }

    public override void OnPickupUseDown() => pressed = true;
    public override void OnPickupUseUp() {
        pressed = false;
        //prev = Vector3.zero;
    }

    int i = 0;

    Vector3 prev = Vector3.zero;

    private void Update()
    {
        i++;
        if (pressed && i > 3 && Vector3.Distance(prev, transform.position) > 0.05) // This value might need to change depending on use case
        {
            i = 0;

            if (prev == Vector3.zero)
                prev = transform.position;

            syncer.Edit(transform.position, 1, color, type);

            /*var center = (prev + transform.position) / 2.0f;

            var size = transform.localScale.x * 2; // TODO: Remove * 2

            //volumeManager.transform.localScale ><
            Bounds bounds = new Bounds(center, Vector3.one * size * 2f + new Vector3(
                Mathf.Abs(prev.x - transform.position.x),
                Mathf.Abs(prev.y - transform.position.y),
                Mathf.Abs(prev.z - transform.position.z)
            ));

            material.SetVector("_SphereFrom", volumeManager.WorldToGridPos(prev));
            material.SetVector("_SphereTo", volumeManager.WorldToGridPos(transform.position));
            material.SetFloat("_SphereRadius", size * volumeManager.GridSize / 2 / volumeManager.transform.localScale.x);
            material.SetInteger("_SphereColor", colorIdx);
            volumeManager.Edit(bounds, material, pass);*/

            prev = transform.position;
        }
    }
}
