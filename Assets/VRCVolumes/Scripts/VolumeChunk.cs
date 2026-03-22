
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;

namespace VRCVolumes
{
    public class VolumeChunk : UdonSharpBehaviour
    {
        public static Vector3Int KeyToIntGrid(ulong key)
        {
            return new Vector3Int(
                (int)((long)(key & 0xFFFFF) - 0x7FFFF),
                (int)((long)((key >> 20) & 0xFFFFF) - 0x7FFFF),
                (int)((long)((key >> 40) & 0xFFFFF) - 0x7FFFF)
            );
        }

        public static Vector3 KeyToGrid(ulong key)
        {
            return new Vector3(
                (int)((long)(key & 0xFFFFF) - 0x7FFFF),
                (int)((long)((key >> 20) & 0xFFFFF) - 0x7FFFF),
                (int)((long)((key >> 40) & 0xFFFFF) - 0x7FFFF)
            );
        }

        public static ulong GridToKey(Vector3Int pos)
        {
            ulong x = (ulong)(pos.x + 0x7FFFF) & 0xFFFFF;
            ulong y = (ulong)(pos.y + 0x7FFFF) & 0xFFFFF;
            ulong z = (ulong)(pos.z + 0x7FFFF) & 0xFFFFF;

            return x | (y << 20) | (z << 40);
        }

        public static VolumeChunk Create(GameObject self, ulong key)
        {
            var gridPos = KeyToIntGrid(key);

            self.transform.localPosition = gridPos;
            self.transform.localScale = Vector3.one;

            #if UNITY_EDITOR
            self.name = $"Chunk {gridPos}";
            #endif

            var meshFilter = self.GetComponent<MeshFilter>();
            var meshCollider = self.GetComponent<MeshCollider>();

            meshFilter.mesh = new Mesh();
            meshCollider.sharedMesh = new Mesh();

            return (VolumeChunk)(object)new DataList(new DataToken[]
            {
                key,
                meshFilter,
                meshCollider,
                new DataList(),
                false,
            });
        }
    }
}