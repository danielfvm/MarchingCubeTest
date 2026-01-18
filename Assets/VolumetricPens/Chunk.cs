
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VolumetricPens;
using VRC.SDKBase;
using VRC.Udon;

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
        transform.localPosition = DataBlock.ToPos(key);
        this.system = system;
        this.key = key;

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
        // TODO: meshCollider

        #if UNITY_EDITOR
        name = "Chunk " + transform.localPosition;
        #endif
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
        return DataBlock.ToPos(key);
    }
}
