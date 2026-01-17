
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDKBase;
using VRC.Udon;

namespace VolumetricPens
{
    public class DataBlock : UdonSharpBehaviour
    {
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

        public static DataBlock New()
        {
            RenderTexture data = new RenderTexture(1024/4, 1024/4, 0, RenderTextureFormat.RFloat);
            data.filterMode = FilterMode.Point;
            data.Create();

            DataList container = new DataList();
            container.Add(data);

            return (DataBlock)(object)container;
        }
    }
}