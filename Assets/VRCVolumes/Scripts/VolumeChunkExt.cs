using UnityEngine;
using VRC.SDK3.Data;

namespace VRCVolumes
{
    public static class VolumeChunkExt
    {
        // Getters
        public static ulong GetKey(this VolumeChunk self) => ((DataList)(object)self)[0].ULong;
        public static MeshFilter GetMeshFilter(this VolumeChunk self) => (MeshFilter)((DataList)(object)self)[1].Reference;
        public static MeshCollider GetMeshCollider(this VolumeChunk self) => (MeshCollider)((DataList)(object)self)[2].Reference;
        public static DataList GetDataRefs(this VolumeChunk self) => ((DataList)(object)self)[3].DataList;

        // Utils
        public static Vector3Int GetIntGridPos(this VolumeChunk self) => VolumeChunk.KeyToIntGrid(self.GetKey());
        public static Vector3 GetGridPos(this VolumeChunk self) => VolumeChunk.KeyToGrid(self.GetKey());
        public static DataToken AsDataToken(this VolumeChunk self) => (DataList)(object)self;
        public static VolumeChunk AsVolumeChunk(this DataToken self) => (VolumeChunk)(object)self.DataList;
    }
}