
using UdonSharp;
using UnityEngine;
using VRCVolumes;

public class Bomb : UdonSharpBehaviour
{
    public EditSyncer editSyncer;
    public Rigidbody rb;

    private Vector3 startPos;
    private Bomb next;

    [SerializeField] float fuseTime = 10;

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
        SendCustomEventDelayedSeconds(nameof(Explode), fuseTime);
    }

    void OnCollisionEnter(Collision collision)
    {
        Explode();
    }

    public void Explode()
    {
        if (!rb.isKinematic)
        {
            rb.isKinematic = true;
            editSyncer.Edit(transform.position, 10, 0, EditType.Erase);
            Destroy(gameObject);
        }
    }
}
