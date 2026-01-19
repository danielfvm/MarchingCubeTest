
using UdonSharp;
using UnityEngine;
using VolumetricPens;
using VRC.SDKBase;

public class Chunk : UdonSharpBehaviour
{
    private MarchingCubeSystem system;
    public RenderTexture data;
    public MeshFilter[] meshFilter;
    public MeshCollider meshCollider;
    [HideInInspector] public Mesh[] mesh;

    public ulong key;

    public static Chunk Create(MarchingCubeSystem system, ulong key)
    {
        Chunk chunk = Instantiate(system.chunkPrefab.gameObject, system.transform).GetComponent<Chunk>();
        chunk.gameObject.SetActive(true);
        chunk.Init(system, key);

        return chunk;
    }

    private void Init(MarchingCubeSystem system, ulong key)
    {
        transform.localPosition = ToPos(key);
        this.system = system;
        this.key = key;

        EnableMeshCollider(system.collision);

        data = new RenderTexture(1024/4, 1024/4, 0, RenderTextureFormat.RFloat);
        data.filterMode = FilterMode.Point;
        data.Create();

        VRCGraphics.Blit(null, data, system.matPaint, system.passReset);

        mesh = new Mesh[2];
        
        for (int i = 0; i < mesh.Length; i++)
        {
            mesh[i] = new Mesh();
            mesh[i].MarkDynamic();
            mesh[i].bounds = new Bounds(Vector3.zero, transform.lossyScale);
            mesh[i].indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
            meshFilter[i].sharedMesh = mesh[i];
        }

        #if UNITY_EDITOR
        name = "Chunk " + transform.localPosition;
        #endif
    }

    public void EnableMeshCollider(bool enabled)
    {
        meshCollider.enabled = enabled;
    }

    public void UpdateMeshCollider(Mesh mesh)
    {
        meshCollider.sharedMesh = null;
        meshCollider.sharedMesh = mesh;
    }

    public void OnDestroy()
    {
        data.Release();
    }

    public void UpdateMesh()
    {
        system.GenerateMesh(this, 1);
    }

    public Vector3 GetCoord()
    {
        return ToPos(key);
    }

    public static ulong ToKey(Vector3 pos) 
    {
        return ToKey(new Vector3Int(
            Mathf.FloorToInt(pos.x), 
            Mathf.FloorToInt(pos.y), 
            Mathf.FloorToInt(pos.z)
        ));
    }

    public static ulong ToKey(Vector3Int pos)
    {
        ulong x = (ulong)(pos.x + 0x7FFFF) & 0xFFFFF; // 20 bits
        ulong y = (ulong)(pos.y + 0x7FFFF) & 0xFFFFF; // 20 bits
        ulong z = (ulong)(pos.z + 0x7FFFF) & 0xFFFFF; // 20 bits

        return x | (y << 20) | (z << 40);
    }

    public static Vector3Int ToPosInt(ulong key)
    {
        return new Vector3Int(
            (int)((long)(key & 0xFFFFF) - 0x7FFFF),
            (int)((long)((key >> 20) & 0xFFFFF) - 0x7FFFF),
            (int)((long)((key >> 40) & 0xFFFFF) - 0x7FFFF)
        );
    }

    public static Vector3 ToPos(ulong key)
    {
        return new Vector3(
            (int)((long)(key & 0xFFFFF) - 0x7FFFF),
            (int)((long)((key >> 20) & 0xFFFFF) - 0x7FFFF),
            (int)((long)((key >> 40) & 0xFFFFF) - 0x7FFFF)
        );
    }
}
