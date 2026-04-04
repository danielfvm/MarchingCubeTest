
using UdonSharp;
using UnityEngine;
using VRCVolumes;

public class Bomb : UdonSharpBehaviour
{
    public EditSyncer editSyncer;
    public Rigidbody rb;

    private Vector3 startPos;
    private Bomb next;
    
    void Start()
    {
        startPos = transform.position;

        next = Instantiate(gameObject, startPos, Quaternion.identity).GetComponent<Bomb>();
        next.gameObject.SetActive(false);
        next.gameObject.name = gameObject.name;
    }

    public override void OnPickup()
    {
        next.gameObject.SetActive(true);
    }

    public override void OnDrop()
    {
        rb.isKinematic = false;
    }

    void OnCollisionEnter(Collision collision)
    {
        if (!rb.isKinematic)
        {
            rb.isKinematic = true;
            editSyncer.Edit(transform.position, 10, 0, EditType.Erase);
            Destroy(gameObject);
        }
    }
}
