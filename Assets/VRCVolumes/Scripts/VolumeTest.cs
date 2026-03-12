
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using VRCVolumes;

/// <summary>
/// Simple Test class that uses the Volume class to generate a mesh. Used to showcase how the
/// Volume class can be used.
/// </summary>
[RequireComponent(typeof(Volume))]
public class VolumeTest : VolumeCallback
{
    public Vector3Int voxelDimensions = Vector3Int.one * 64;
    public Material marchingCubeMaterial, generateWeightMaterial;

    void Start() {
        Setup();
        Build();
    }

    public RenderTexture data;

    public void Setup()
    {
        Volume volume = GetComponent<Volume>();
        volume.Setup(voxelDimensions, true, marchingCubeMaterial);
        var texDim = volume.TextureDimensionInt;

        Debug.Log($"Texture dimension: {texDim} Voxel dimension: {volume.VoxelDimension}");

        data = new RenderTexture(texDim.x, texDim.y, 0, RenderTextureFormat.RFloat);
        data.filterMode = FilterMode.Point;
        data.Create();
    }

    public void Build()
    {
        Volume volume = GetComponent<Volume>();

        // Generate weight data
        generateWeightMaterial.SetVector("_VoxelDimension", volume.VoxelDimension);
        generateWeightMaterial.SetVector("_TargetSize", volume.TextureDimension);
        VRCGraphics.Blit(null, data, generateWeightMaterial);

        // Build both visual and collider mesh, result recv in OnAsyncMeshBuild()
        volume.Build(data, true, new Mesh(), this);
        volume.Build(data, false, new Mesh(), this);
    }

    public override void OnAsyncMeshBuild(Mesh mesh, bool collider, long time)
    {
        Debug.Log($"Vertices: {mesh.vertices.Length} Collider: {collider} Time: {time}ms");
    }
}
