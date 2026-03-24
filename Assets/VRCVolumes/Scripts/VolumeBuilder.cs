
using System;
using UdonSharp;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Analytics;
using VRC.SDK3.Data;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

namespace VRCVolumes
{
    public enum VolumeType
    {
        Surface,
        Cloud,
    }

    /// <summary>
    /// Generates a mesh including colliders using a shader + AsyncGPUReadback.
    /// Make sure to first initialize the Volume instance by calling Setup() before Build().
    /// </summary>
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class VolumeBuilder : UdonSharpBehaviour
    {
        /// <summary>
        /// true if the VolumeBuilder is currently updating the mesh / waiting on async readback.
        /// </summary>
        public bool IsBuilding => buildingQueue.Count > 0;

        /// <summary>
        /// The texture dimension required for VolumeBuilder.Build(data). (Assuming every pixel is one voxel)
        /// </summary>
        public Vector2Int TextureDimensionInt { get; private set; }

        /// <summary>
        /// The texture dimension required for VolumeBuilder.Build(data). This is the same value as TextureDimensionInt but 
        /// casted from Vector3Int to Vector3 to simplify assignments / conversions. 
        /// </summary>
        public Vector2 TextureDimension => new Vector2(TextureDimensionInt.x, TextureDimensionInt.y);

        /// <summary>
        /// Defines the width, height and depth of the VolumeBuilder. 
        /// </summary>
        public Vector3Int VoxelDimensionInt { get; private set; }

        /// <summary>
        /// Defines the width, height and depth of the VolumeBuilder. This is the same value as VoxelDimensionInt but 
        /// casted from Vector3Int to Vector3 to simplify assignments / conversions. 
        /// </summary>
        public Vector3 VoxelDimension => new Vector3(VoxelDimensionInt.x, VoxelDimensionInt.y, VoxelDimensionInt.z);

        /// <summary>
        /// The total amount of Voxels
        /// </summary>
        public uint VoxelCount => (uint)(VoxelDimension.x * VoxelDimension.y * VoxelDimension.z);

        #region Local Fields
        private Mesh tempMesh;
        private Color[] vertexReadback;
        private byte[] indexReadback;
        private int[] triangles;
        private DataList buildingQueue;
        private Material material;
        private int passVertices, passIndices, passActive, passCompact, passLookup, passCollider;
        private RenderTexture texVertices, texActiveVertices, texCompactVertices, texCompactCollider;
        private RenderTexture texIndexLookup, texIndices, texActiveIndices, texCompactIndices;
        private VolumeType volumeType;
        private DataDictionary colliderBuildQueue;
        #endregion

        private void Cleanup()
        {
            if (texVertices != null && texVertices.IsCreated())
                texVertices.Release();
            if (texActiveVertices != null && texActiveVertices.IsCreated())
                texActiveVertices.Release();
            if (texCompactVertices != null && texCompactVertices.IsCreated())
                texCompactVertices.Release();
            if (texCompactCollider != null && texCompactCollider.IsCreated())
                texCompactCollider.Release();
            if (texIndexLookup != null && texIndexLookup.IsCreated())
                texIndexLookup.Release();
            if (texIndices != null && texIndices.IsCreated())
                texIndices.Release();
            if (texActiveIndices != null && texActiveIndices.IsCreated())
                texActiveIndices.Release();
            if (texCompactIndices != null && texCompactIndices.IsCreated())
                texCompactIndices.Release();
        }

        public void OnDestroy() => Cleanup();
        
        /// <summary>
        /// Configure the VolumeBuilder. Try to avoid calling this function often / it is slow. If you need multiple VolumeBuilders with different
        /// configuration you should instead create multiple instances and configure each with the requried configuration.
        /// </summary>
        /// <param name="voxelDimension"></param>
        /// <param name="roundUpToPowerOf2"></param>
        /// <param name="material"></param>
        public void Setup(Vector3Int voxelDimension, bool roundUpToPowerOf2, Material material, VolumeType volumeType)
        {
            // Compute a square texture dimension that can contain all the voxels.
            // It is probably not really necessary to limit it to a square texture with power of 2,
            // but maybe Quest/OpenGL does not properly work otherwise - TEST IT!
            int totalPixelCount = voxelDimension.x * voxelDimension.y * voxelDimension.z;
            int texDim = Mathf.CeilToInt(Mathf.Sqrt(totalPixelCount));
            if (roundUpToPowerOf2)
                texDim = Mathf.CeilToInt(Mathf.Pow(2, Mathf.Ceil(Mathf.Log(texDim, 2))));

            VoxelDimensionInt = voxelDimension;
            TextureDimensionInt = new Vector2Int(texDim, texDim);
            this.material = material;
            this.volumeType = volumeType;

            passVertices = material.FindPass("Vertices");
            passIndices = material.FindPass("Indices");
            passActive = material.FindPass("Active");
            passCompact = material.FindPass("Compact");
            passLookup = material.FindPass("Lookup");
            passCollider = material.FindPass("Collider");

            // Cleanup temp textures if already created in previous Setup() call
            Cleanup();

            // TODO: We might want to support different types of mesh generation algorithms, therefore the Dimension and 
            // TextureFormat might need to be changed depending on which we want to use.
            // Vertex related Textures
            {
                texVertices = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.ARGBFloat);
                texVertices.filterMode = FilterMode.Point;
                texVertices.Create();

                texActiveVertices = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.RFloat);
                texActiveVertices.useMipMap = true; // We want to generate mipmaps for the sparse texture algorithm
                texActiveVertices.filterMode = FilterMode.Point;
                texActiveVertices.Create();

                // This can be slightly smaller, assuming that not all Voxels take up 15 Vertices.
                // How small it can be is unclear.
                texCompactVertices = new RenderTexture(texDim / 2, texDim / 2, 0, RenderTextureFormat.ARGBFloat);
                texCompactVertices.filterMode = FilterMode.Point;
                texCompactVertices.Create();

                // Collision texture, will copy texCompactVertices but with different encoding
                texCompactCollider = new RenderTexture(texDim / 2, texDim / 2, 0, RenderTextureFormat.ARGBFloat);
                texCompactCollider.filterMode = FilterMode.Point;
                texCompactCollider.Create();
            }

            // Index related Textures
            {
                texIndexLookup = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.RFloat); // RFloat would be enough, but idk if it works
                texIndexLookup.filterMode = FilterMode.Point;
                texIndexLookup.Create();

                texIndices = new RenderTexture(texDim * 2, texDim * 2, 0, RenderTextureFormat.ARGBFloat);
                texIndices.filterMode = FilterMode.Point;
                texIndices.Create();

                texActiveIndices = new RenderTexture(texDim * 2, texDim * 2, 0, RenderTextureFormat.RFloat);
                texActiveIndices.useMipMap = true; // We want to generate mipmaps for the sparse texture algorithm
                texActiveIndices.filterMode = FilterMode.Point;
                texActiveIndices.Create();

                texCompactIndices = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.ARGBFloat);
                texCompactIndices.filterMode = FilterMode.Point;
                texCompactIndices.Create();   
            }

            // MarkDynamic is supposed to make it more optimized in case the mesh updates a lot
            // and indexFormat is set to UInt32 because otherwise it would fail with more than 2^16 vertices.
            tempMesh = new Mesh();
            tempMesh.MarkDynamic();
            tempMesh.bounds = new Bounds(Vector3.zero, Vector3.one);

            // Creating large arrays is slow so we do it only once.
            // We generate tempTriangles (aka the indicies) here to only need to do a simple Array.Copy. 
            // TODO: Change back
            vertexReadback = new Color[texCompactVertices.width * texCompactVertices.height];
            indexReadback = new byte[texCompactIndices.width * texCompactIndices.height * 4 * 4];
            
            buildingQueue = new DataList();
            colliderBuildQueue = new DataDictionary();

            // Used for VolumeType.Cloud
            triangles = new int[texCompactVertices.width * texCompactVertices.height];
            for (int i = 0; i < triangles.Length; i++)
                triangles[i] = i;
        }

        public RenderTexture CreateData()
        {
            var data = new RenderTexture(TextureDimensionInt.x, TextureDimensionInt.y, 0, RenderTextureFormat.RFloat);
            data.filterMode = FilterMode.Point;
            data.Create();

            return data;
        }


        /// <summary>
        /// Builds a marching cube mesh from the provided weights (data argument) and either directly updates the 
        /// VolumeBuilder.meshFilter or VolumeBuilder.meshCollider (if buildCollider true) or calls the callback function with
        /// the newly created Mesh as an argument.
        /// </summary>
        /// <param name="data">Weight (and optionally color) data with an expected size of VolumeBuilder.TextureDimension</param>
        /// <param name="buildCollider">If true will generate a CPU mesh useful for colliders (slower!).</param>
        /// <param name="sharedMesh">Optionally specify what mesh to update, otherwise will use internal one.</param>
        public void Build(ulong key, Texture data, Mesh sharedMesh = null, MeshCollider collider = null)
        {
            if (buildingQueue == null)
            {
                Debug.LogError($"[{name}][VolumeBuilder][ERR]: Build() was called before Setup()");
                return;
            }

            var startTime = DateTimeOffset.Now.ToUnixTimeMilliseconds();

            // Compute vertices
            {
                material.SetTexture("_DataTex", data);
                material.SetVector("_VoxelDimension", VoxelDimension);
                material.SetVector("_DataSize", TextureDimension);
                material.SetVector("_TargetSize", new Vector2(texVertices.width, texVertices.height));
                VRCGraphics.Blit(null, texVertices, material, passVertices);
                
                // Computes active texels, automatically generates MipMaps of it
                material.SetTexture("_TriangleTex", texVertices);
                material.SetVector("_TargetSize", new Vector2(texActiveVertices.width, texActiveVertices.height));
                VRCGraphics.Blit(null, texActiveVertices, material, passActive);

                // Compute CompactSparseTexture, result contains vertices but compacted
                material.SetTexture("_TriangleTex", texVertices);
                material.SetTexture("_ActiveTex", texActiveVertices);
                material.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(texVertices.width, 2)));
                material.SetVector("_TargetSize", new Vector2(texCompactVertices.width, texCompactVertices.height));
                VRCGraphics.Blit(null, texCompactVertices, material, passCompact);

                buildingQueue.Add(new DataToken(new object[] 
                {
                    null,
                    sharedMesh,
                    startTime,
                    key,
                }));

                VRCAsyncGPUReadback.Request(texCompactVertices, 0, (IUdonEventReceiver)this);
            }

            // Compute indices
            if (volumeType == VolumeType.Surface)
            {
                // Compute VertexIndexLookup
                material.SetTexture("_ActiveTexelMap", texActiveVertices);
                material.SetVector("_TargetSize", new Vector2(texIndexLookup.width, texIndexLookup.height));
                material.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(texVertices.width, 2)));
                VRCGraphics.Blit(null, texIndexLookup, material, passLookup);

                // Compute indices
                material.SetTexture("_DataTex", data);
                material.SetVector("_VoxelDimension", VoxelDimension);
                material.SetVector("_DataSize", TextureDimension);
                material.SetTexture("_IndexLookup", texIndexLookup);
                material.SetVector("_TargetSize", new Vector2(texIndices.width, texIndices.height));
                VRCGraphics.Blit(null, texIndices, material, passIndices);

                // Computes active texels, automatically generates MipMaps of it
                material.SetTexture("_TriangleTex", texIndices); // Rename it
                material.SetVector("_TargetSize", new Vector2(texActiveIndices.width, texActiveIndices.height));
                VRCGraphics.Blit(null, texActiveIndices, material, passActive);

                // Compute CompactSparseTexture
                material.SetTexture("_TriangleTex", texIndices);
                material.SetTexture("_ActiveTex", texActiveIndices);
                material.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(texIndices.width, 2)));
                material.SetVector("_TargetSize", new Vector2(texCompactIndices.width, texCompactIndices.height));
                VRCGraphics.Blit(null, texCompactIndices, material, passCompact);

                buildingQueue.Add(new DataToken(new object[]
                {
                    null,
                    sharedMesh,
                    startTime,
                    key,
                }));

                VRCAsyncGPUReadback.Request(texCompactIndices, 0, (IUdonEventReceiver)this);
            } 

            if (collider != null)
            {
                // Convert vertices to different encoding
                material.SetTexture("_TriangleTex", texCompactVertices);
                material.SetVector("_TargetSize", new Vector2(texCompactCollider.width, texCompactCollider.height));
                VRCGraphics.Blit(null, texCompactCollider, material, passCollider);

                buildingQueue.Add(new DataToken(new object[]
                {
                    collider,
                    sharedMesh,
                    startTime,
                    key,
                }));

                VRCAsyncGPUReadback.Request(texCompactCollider, 0, (IUdonEventReceiver)this);
            }
        }

        private void Update()
        {
            if (colliderBuildQueue.Count > 0)
            {
                var key = colliderBuildQueue.GetKeys()[0];
                var data = (object[])colliderBuildQueue[key].Reference;
                var collider = (MeshCollider)data[0];
                var colors = (Color[])data[1];
                var indices = (int[])data[2];
                var counter = (int)data[3];

                if (!Utilities.IsValid(collider))
                {   
                    colliderBuildQueue.Remove(key);
                }
                else if (counter > 0)
                {
                    colliderBuildQueue[key] = new DataToken(new object[]
                    {
                        collider,
                        colors,
                        indices,
                        counter - 1,
                    });
                }
                else
                {
                    colliderBuildQueue.Remove(key);

                    Vector3[] vertices = new Vector3[colors.Length];
                    for (int i = 0; i < vertices.Length; i ++)
                        vertices[i] = new Vector3(colors[i].r, colors[i].g, colors[i].b);

                    // TODO: This is an issue
                    var meshCollider = collider.sharedMesh;

                    if (meshCollider == null)
                    {
                        meshCollider = new Mesh();         
                        meshCollider.MarkDynamic();
                        meshCollider.bounds = new Bounds(Vector3.zero, Vector3.one);
                    }
                    else
                        meshCollider.Clear(true);
                        
                    meshCollider.SetVertices(vertices, 0, vertices.Length, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
                    meshCollider.SetIndices(indices, MeshTopology.Quads, 0, false);

                    // This is required in order to force the collider to update
                    collider.sharedMesh = null;
                    collider.sharedMesh = meshCollider;
                    collider.enabled = vertices.Length > 0;
                }
            }
        }

        private Color[] colors;
        private Vector3[] vertices;

        public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
        {
            if (!buildingQueue.TryGetValue(0, out DataToken buildInfo))
            {
                Debug.LogError($"[{name}][VolumeBuilder][ERR]: Expected queue element.");
                return;
            }

            var collider = (MeshCollider)((object[])buildInfo.Reference)[0];
            var sharedMesh = (Mesh)((object[])buildInfo.Reference)[1];
            var key = (ulong)((object[])buildInfo.Reference)[3];
            buildingQueue.RemoveAt(0);

            // This assumes that vertices and indices have different sized textures, alternative could be to just add it in the buildInfo.
            bool isVertexReadback = texCompactVertices.width == request.width && texCompactVertices.height == request.height;

            if (request.hasError)
            {
                Debug.LogError($"[{name}][VolumeBuilder][ERR]: Gpu Readback has error.");
                return;
            }

            var mesh = sharedMesh != null ? sharedMesh : tempMesh;

            if (collider != null) // && collider.sharedMesh != null)
            {
                if (!request.TryGetData(vertexReadback))
                {
                    Debug.LogError($"[{name}][VolumeBuilder][Collider][ERR]: Gpu Readback failed to get data.");
                    return;
                }

                var colors = new Color[mesh.vertices.Length];
                Array.Copy(vertexReadback, colors, colors.Length);

                colliderBuildQueue[key] = new DataToken(new object[]
                {
                    collider,
                    colors,
                    mesh.GetIndices(0),
                    5,
                });
            }
            else if (isVertexReadback)
            {
                if (!request.TryGetData(vertexReadback))
                {
                    Debug.LogError($"[{name}][VolumeBuilder][Vertex][ERR]: Gpu Readback failed to get data.");
                    return;
                }

                // Shader has to make sure that the last pixel contains the total length of vertices
                int len = BitConverter.SingleToInt32Bits(vertexReadback[vertexReadback.Length - 1].r);
                if (len > vertexReadback.Length || len < 0)
                {
                    Debug.LogError($"[{name}][VolumeBuilder][Vertex][ERR]: Gpu Readback returned length of {len} but max is {vertexReadback.Length}, was there an error with the shader material?");
                    return;
                }

                colors = new Color[len];
                Array.Copy(vertexReadback, colors, len);

                // if MeshCollider is used, requires proper vertex coords => Convert data from Color[] to Vector3[], 
                // otherwise vertices are just (0,0,0) and the vertex shader transforms the vertices using the color data
                vertices = new Vector3[len];

                if (volumeType == VolumeType.Cloud)
                {
                    var indices = new int[vertices.Length];
                    Array.Copy(triangles, indices, indices.Length);
                    mesh.SetIndices(indices, MeshTopology.Points, 0, false);
                }
            }
            else
            {
                if (!request.TryGetData(indexReadback))
                {
                    Debug.LogError($"[{name}][VolumeBuilder][Index][ERR]: Gpu Readback failed to get data.");
                    return;
                }

                // Shader has to make sure that the last pixel contains the total length of vertices
                int len = BitConverter.ToInt32(indexReadback, indexReadback.Length - 4) * 4;
                if (len * 4 > indexReadback.Length)
                {
                    Debug.LogError($"[{name}][VolumeBuilder][Index][ERR]: Gpu Readback returned length of {len} but max is {indexReadback.Length}, was there an error with the shader material?");
                    return;
                }

                int[] indices = new int[len];
                Buffer.BlockCopy(indexReadback, 0, indices, 0, len * 4);

                // Update mesh with as few compute as possible (e.g. by disabling recalculating bounds which is default behaviour)
                mesh.Clear(true);
                mesh.SetVertices(vertices, 0, vertices.Length, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
                mesh.SetColors(colors, 0, colors.Length, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
                mesh.SetIndices(indices, MeshTopology.Quads, 0, false);
            }
        }
    }
}
