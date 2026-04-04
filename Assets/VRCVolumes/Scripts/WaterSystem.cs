
using UnityEngine;
using VRC.SDKBase;
using VRCVolumes;

public class WaterSystem : VolumeAreaManagerCallback
{
    public Camera cam;
    public VolumeAreaManager manager;
    public Material material;
    public MeshFilter meshFilter;
    public MeshRenderer meshRenderer;
    public int range;

    public RenderTexture[] state;
    public RenderTexture depth;
    private Vector3 chunkSize;
    private int idx;

    void Start()
    {
        state = new RenderTexture[2];
        for (int i = 0; i < state.Length; i++)
        {
            state[i] = new RenderTexture(range * manager.GridSize, range * manager.GridSize, 0, RenderTextureFormat.ARGB32);
            state[i].filterMode = FilterMode.Point;
            state[i].Create();
        }

        depth = new RenderTexture(range * manager.GridSize, range * manager.GridSize, 0, RenderTextureFormat.Depth);
        depth.filterMode = FilterMode.Point;
        depth.Create();

        chunkSize = manager.transform.localScale;

        cam.targetTexture = depth;
        cam.orthographicSize = chunkSize.x * range / 2f;

        manager.Register(this);

        GenerateGrid(range * manager.GridSize, range * manager.GridSize, chunkSize.x / manager.GridSize);

        var block = new MaterialPropertyBlock();
        block.SetTexture("_WaterState", state[0]);
        meshRenderer.SetPropertyBlock(block);

       // UpdateWater();
    }

    private void GenerateGrid(int rows, int cols, float cellSize)
    {
        int vertexCount = rows * cols;
        var Vertices = new Vector3[vertexCount];
        var UVs = new Vector2[vertexCount];

        // Create vertices
        for (int y = 0; y < rows; y++)
        {
            for (int x = 0; x < cols; x++)
            {
                int i = y * cols + x;

                Vertices[i] = new Vector3(
                    x * cellSize - rows * cellSize / 2f,
                    0,
                    y * cellSize - cols * cellSize / 2
                );

                UVs[i] = new Vector2(
                    (float)x / (cols - 1),
                    (float)y / (rows - 1)
                );
            }
        }

        // Each quad = 2 triangles = 6 indices
        int quadCount = (rows - 1) * (cols - 1);
        var Triangles = new int[quadCount * 6];

        int t = 0;

        for (int y = 0; y < rows - 1; y++)
        {
            for (int x = 0; x < cols - 1; x++)
            {
                int i = y * cols + x;

                // Triangle 1
                Triangles[t++] = i;
                Triangles[t++] = i + cols;
                Triangles[t++] = i + 1;

                // Triangle 2
                Triangles[t++] = i + 1;
                Triangles[t++] = i + cols;
                Triangles[t++] = i + cols + 1;
            }
        }

        var mesh = new Mesh();
        mesh.SetVertices(Vertices);
        mesh.SetTriangles(Triangles, 0);
        mesh.SetUVs(0, UVs);

        meshFilter.mesh = mesh;
    }

    public void Update()
    {
        NextWaterState(Vector2.zero);
        //SendCustomEventDelayedSeconds(nameof(UpdateWater), 0.05f);
    }

    private void NextWaterState(Vector2 delta)
    {
        material.SetVector("_TargetSize", new Vector2(state[0].width, state[0].height));
        material.SetTexture("_PrevTex", state[idx % 2]);
        material.SetTexture("_DepthTex", depth);
        material.SetVector("_Delta", delta * manager.GridSize);
        VRCGraphics.Blit(null, state[(idx + 1) % 2], material);
        if (delta != Vector2.zero)
        Debug.Log(delta * manager.GridSize);
        idx++;   
    }

    public override void OnAreaChange(Vector3Int chunkPos, Vector3Int prevPos)
    {
        Vector2 delta = new Vector2(chunkPos.x - prevPos.x, chunkPos.z - prevPos.z);
        var pos = Vector3.Scale(chunkPos, chunkSize);
        transform.position = new Vector3(pos.x, transform.position.y, pos.z);
        NextWaterState(delta);
        cam.Render();
    }

    public override void OnMeshBuildDone(ulong key, Mesh mesh)
    {
        cam.Render();
    }
}
