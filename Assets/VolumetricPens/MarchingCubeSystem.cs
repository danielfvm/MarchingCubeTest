
using System.Linq.Expressions;
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDK3.Data;
using VRC.SDKBase;
using VRC.Udon;

namespace VolumetricPens
{
    public class MarchingCubeSystem : UdonSharpBehaviour
    {
        public Material matPaint; 
        private int passPaint, passReset;
        public RenderTexture buffer;
        
        private DataDictionary blocks = new DataDictionary();

        private readonly int VoxelAmount = 40; 

        public Text text;
        
        
        private void Start()
        {
            blocks.Add(DataBlock.ToKey(Vector3.zero), DataBlock.New().AsDataToken());
            blocks.Add(DataBlock.ToKey(Vector3.one), DataBlock.New().AsDataToken());
            transform.position = Vector3.zero;

            passPaint = matPaint.FindPass("Paint");
            passReset = matPaint.FindPass("Reset");

            buffer = new RenderTexture(1024/4, 1024/4, 0, RenderTextureFormat.RFloat);
            buffer.filterMode = FilterMode.Point;
            buffer.Create();
        }

        private DataBlock GetDataBlock(ulong key)
        {
            if (blocks.TryGetValue(key, out DataToken token))
                return (DataBlock)(object)token.DataList;

            DataBlock block = DataBlock.New();
            blocks.SetValue(key, block.AsDataToken());
            return block;
        }

        public void Paint(Vector3 pos, float radius)
        {
            // Manually unrolled loop and use dictonary as a trick to remove duplicate keys
            Vector3 local = transform.InverseTransformPoint(pos);

            matPaint.SetVector("_Position", (local + Vector3.one * 0.5f) * VoxelAmount);
            matPaint.SetInteger("_VoxelAmount", VoxelAmount);
            matPaint.SetTexture("_PrevData", buffer);

            Vector3 localCenter = transform.InverseTransformPoint(pos);
            int minX = Mathf.FloorToInt(localCenter.x - radius);
            int maxX = Mathf.FloorToInt(localCenter.x + radius);
            int minY = Mathf.FloorToInt(localCenter.y - radius);
            int maxY = Mathf.FloorToInt(localCenter.y + radius);
            int minZ = Mathf.FloorToInt(localCenter.z - radius);
            int maxZ = Mathf.FloorToInt(localCenter.z + radius);

            for (int x = minX; x <= maxX; x++)
            for (int y = minY; y <= maxY; y++)
            for (int z = minZ; z <= maxZ; z++)
            {
                Vector3 chunkCoord = new Vector3(x, y, z);
                ulong key = DataBlock.ToKey(chunkCoord);
                DataBlock block = GetDataBlock(key);
                RenderTexture data = block.GetData();

                matPaint.SetVector("_Chunk", chunkCoord);

                VRCGraphics.Blit(data, buffer);
                VRCGraphics.Blit(null, data, matPaint, passPaint);
            }

            int blockCount = blocks.Count;
            float sizeMb = blockCount * 256f * 256f * 4f / 1024f / 1024f;
            text.text = "Blocks: " + blockCount + "\nSize: " + (Mathf.Floor(sizeMb * 100f) / 100f)  + "mb";
        }

        #if UNITY_EDITOR && !COMPILER_UDONSHARP
        private void OnDrawGizmosSelected()
        {
            Matrix4x4 oldMatrix = Gizmos.matrix;
            Gizmos.matrix = transform.localToWorldMatrix;
            Gizmos.color = Color.white;

            foreach (var key in blocks.GetKeys())
                Gizmos.DrawWireCube(DataBlock.ToPos(key.ULong), Vector3.one);

            Gizmos.matrix = oldMatrix;
        }
        #endif
    }
}