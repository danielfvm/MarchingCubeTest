
using UdonSharp;
using UnityEngine;
using VolumetricPens;
using VRC.SDKBase;
using VRC.Udon;

/// <summary>
/// Octree of Chunks
/// </summary>
public class Chunk : UdonSharpBehaviour
{
    public Chunk chunkPrefab;

    private Chunk[] children = new Chunk[8];
    private Chunk parent;
    private int level;

    public static Chunk Create(Chunk parent, int level)
    {
        Chunk chunk = Instantiate(parent.chunkPrefab, parent.transform);
        chunk.parent = parent;
        chunk.level = level;

        return chunk;
    }

    public void GenerateMesh(MarchingCubeSystem system)
    {
        
    }
}
