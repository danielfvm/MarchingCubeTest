
using System;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDK3.Rendering;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

namespace VRCVolumes
{
    public enum VolumeType
    {
        MarchingCube,
        SurfaceNets,
    }

    /// <summary>
    /// Generates a mesh including colliders using a shader + AsyncGPUReadback.
    /// Make sure to first initialize the Volume instance by calling Setup() before Build().
    /// </summary>
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
        private int[] tempTriangles;
        private Mesh tempMesh;
        private Color[] tempData;
        private DataList buildingQueue;
        private Material material;
        private int passGenerate, passActive, passCompact;
        private RenderTexture tempTexTriangle, tempTexActive, tempTexCompact;
        #endregion

        private void Cleanup()
        {
            if (tempTexTriangle != null && tempTexTriangle.IsCreated())
                tempTexTriangle.Release();
            if (tempTexActive != null && tempTexActive.IsCreated())
                tempTexActive.Release();
            if (tempTexCompact != null && tempTexCompact.IsCreated())
                tempTexCompact.Release();
        }

        public void OnDestroy() => Cleanup();
        
        /// <summary>
        /// Configure the VolumeBuilder. Try to avoid calling this function often / it is slow. If you need multiple VolumeBuilders with different
        /// configuration you should instead create multiple instances and configure each with the requried configuration.
        /// </summary>
        /// <param name="voxelDimension"></param>
        /// <param name="roundUpToPowerOf2"></param>
        /// <param name="material"></param>
        public void Setup(Vector3Int voxelDimension, VolumeType type, bool roundUpToPowerOf2, Material material)
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

            passGenerate = material.FindPass("Generate");
            passActive = material.FindPass("Active");
            passCompact = material.FindPass("Compact");

            // Cleanup temp textures if already created in previous Setup() call
            Cleanup();

            // TODO: We might want to support different types of mesh generation algorithms, therefore the Dimension and 
            // TextureFormat might need to be changed depending on which we want to use.

/*
            switch (type)
            {
            case VolumeType.MarchingCube:*/
                // Since we need 15 Vertices at max per Voxel (at least in MarchingCubes) we need 4x4 per Voxel.
                // We could try different algorithms e.g. Surface Nets that would reduce amount of Vertices per Voxel.
                tempTexTriangle = new RenderTexture(texDim * 4, texDim * 4, 0, RenderTextureFormat.ARGBFloat);
                tempTexTriangle.filterMode = FilterMode.Point;
                tempTexTriangle.Create();

                tempTexActive = new RenderTexture(texDim * 4, texDim * 4, 0, RenderTextureFormat.ARGBFloat);
                tempTexActive.useMipMap = true; // We want to generate mipmaps for the sparse texture algorithm
                tempTexActive.filterMode = FilterMode.Point;
                tempTexActive.Create();

                // This can be slightly smaller, assuming that not all Voxels take up 15 Vertices.
                // How small it can be is unclear.
                tempTexCompact = new RenderTexture(texDim * 2, texDim * 2, 0, RenderTextureFormat.ARGBFloat);
                tempTexCompact.filterMode = FilterMode.Point;
                tempTexCompact.Create();
               /* break;
            case VolumeType.SurfaceNets:
                tempTexTriangle = new RenderTexture(texDim * 2, texDim * 2, 0, RenderTextureFormat.ARGBFloat);
                tempTexTriangle.filterMode = FilterMode.Point;
                tempTexTriangle.Create();

                tempTexActive = new RenderTexture(texDim * 2, texDim * 2, 0, RenderTextureFormat.ARGBFloat);
                tempTexActive.useMipMap = true; // We want to generate mipmaps for the sparse texture algorithm
                tempTexActive.filterMode = FilterMode.Point;
                tempTexActive.Create();

                tempTexCompact = new RenderTexture(texDim, texDim, 0, RenderTextureFormat.ARGBFloat);
                tempTexCompact.filterMode = FilterMode.Point;
                tempTexCompact.Create();
                break;
            }*/

            // MarkDynamic is supposed to make it more optimized in case the mesh updates a lot
            // and indexFormat is set to UInt32 because otherwise it would fail with more than 2^16 vertices.
            tempMesh = new Mesh();
            tempMesh.MarkDynamic();
            tempMesh.bounds = new Bounds(Vector3.zero, Vector3.one);
            tempMesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;



            // Creating large arrays is slow so we do it only once.
            // We generate tempTriangles (aka the indicies) here to only need to do a simple Array.Copy. 
            // TODO: Change back
            tempData = new Color[tempTexCompact.width * tempTexCompact.height];
            tempTriangles = new int[tempTexCompact.width * tempTexCompact.height];


            for (int i = 0; i < tempTriangles.Length; i++)
                tempTriangles[i] = i;
            
            buildingQueue = new DataList();
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
        /// <param name="callback">If set, will be called after Mesh has been built.</param>
        public void Build(bool buildCollider, Texture data, Mesh sharedMesh = null, VolumeCallback callback = null)
        {
            if (buildingQueue == null)
            {
                Debug.LogError($"[{name}][VolumeBuilder][ERR]: Build() was called before Setup()");
                return;
            }

            if (sharedMesh != null)
            {
                sharedMesh.MarkDynamic();
                sharedMesh.bounds = new Bounds(Vector3.zero, Vector3.one);
                sharedMesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
            }

            // Generate the mesh
            material.SetTexture("_DataTex", data);
            material.SetInteger("_Collider", buildCollider ? 1 : 0); // Depending on this value the result's encoding changes

            material.SetVector("_VoxelDimension", VoxelDimension);
            material.SetVector("_DataSize", TextureDimension);
            material.SetVector("_TargetSize", new Vector2(tempTexTriangle.width, tempTexTriangle.height));
            VRCGraphics.Blit(null, tempTexTriangle, material, passGenerate);
            
            // Computes active texels, automatically generates MipMaps of it
            material.SetTexture("_TriangleTex", tempTexTriangle);
            material.SetVector("_TargetSize", new Vector2(tempTexActive.width, tempTexActive.height));
            VRCGraphics.Blit(null, tempTexActive, material, passActive);

            // Compute CompactSparseTexture, result contains vertices but compacted
            material.SetTexture("_TriangleTex", tempTexTriangle);
            material.SetTexture("_ActiveTex", tempTexActive);
            material.SetInteger("_MaxLod", Mathf.RoundToInt(Mathf.Log(tempTexTriangle.width, 2)));
            material.SetVector("_TargetSize", new Vector2(tempTexCompact.width, tempTexCompact.height));
            VRCGraphics.Blit(null, tempTexCompact, material, passCompact);

            // Readback from GPU to CPU (QUEUE ASSUMES READBACK IS IN ORDER BUT NOT SURE IF THATS THE CASE!)
            // if thats not the case, could store the index of this buildInfo into the tempTexCompact's end (similar to vertex length)
            buildingQueue.Add(new DataToken(new object[]
            {
                buildCollider,
                callback,
                sharedMesh,
                DateTimeOffset.Now.ToUnixTimeMilliseconds(),
            }));

            VRCAsyncGPUReadback.Request(tempTexCompact, 0, (IUdonEventReceiver)this);
        }

        public override void OnAsyncGpuReadbackComplete(VRCAsyncGPUReadbackRequest request)
        {
            if (!buildingQueue.TryGetValue(0, out DataToken buildInfo))
            {
                Debug.LogError($"[{name}][VolumeBuilder][ERR]: Expected queue element.");
                return;
            }

            var collider = (bool)((object[])buildInfo.Reference)[0];
            var callback = (VolumeCallback)((object[])buildInfo.Reference)[1];
            var sharedMesh = (Mesh)((object[])buildInfo.Reference)[2];
            var timeStart = (long)((object[])buildInfo.Reference)[3];
            buildingQueue.RemoveAt(0);

            if (request.hasError)
            {
                Debug.LogError($"[{name}][VolumeBuilder][ERR]: Gpu Readback has error.");
                return;
            }

            if (!request.TryGetData(tempData))
            {
                Debug.LogError($"[{name}][VolumeBuilder][ERR]: Gpu Readback failed to get data.");
                return;
            }

            // Shader has to make sure that the last pixel contains the total length of vertices
            int len = BitConverter.SingleToInt32Bits(tempData[tempData.Length - 1].r);
            if (len > tempData.Length)
            {
                Debug.LogError($"[{name}][VolumeBuilder][ERR]: Gpu Readback returned length of {len} but max is {tempData.Length}, was there an error with the shader material?");
                return;
            }

            var colors = new Color[len];
            Array.Copy(tempData, colors, len);

            int[] triangles = new int[len];
            Array.Copy(tempTriangles, triangles, len);

            // if MeshCollider is used, requires proper vertex coords => Convert data from Color[] to Vector3[], 
            // otherwise vertices are just (0,0,0) and the vertex shader transforms the vertices using the color data
            Vector3[] vertices = new Vector3[len];
            if (collider)
                for (int i = 0; i < len; i ++)
                    vertices[i] = new Vector3(tempData[i].r, tempData[i].g, tempData[i].b);
            
            // Update mesh with as few compute as possible (e.g. by disabling recalculating bounds which is default behaviour)
            var mesh = sharedMesh != null ? sharedMesh : tempMesh;
            mesh.Clear(true);
            mesh.SetVertices(vertices, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);
            mesh.SetColors(colors, 0, len, UnityEngine.Rendering.MeshUpdateFlags.DontRecalculateBounds);

            mesh.SetIndices(triangles, MeshTopology.Triangles, 0, false);
            //mesh.SetIndices(triangles, MeshTopology.Points, 0, false);
            //mesh.SetIndices(triangles, MeshTopology.Quads, 0, false);

            long timePast = DateTimeOffset.Now.ToUnixTimeMilliseconds() - timeStart;

            if (callback != null)
                callback.OnAsyncMeshBuild(mesh, collider, timePast);
        }
    }
}
