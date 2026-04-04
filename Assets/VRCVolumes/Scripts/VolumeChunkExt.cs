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

        public static MeshRenderer GetMeshRenderer(this VolumeChunk self) => (MeshRenderer)((DataList)(object)self)[3].Reference;

        public static DataList GetDataRefs(this VolumeChunk self, VolumeAreaManager manager) {
            DataList list = ((DataList)(object)self)[4].DataList;

            // Only setup references on demand, allows for preview chunks that do not have no data blocks
            if (list.Count == 0)
            {
                var pos = self.GetIntGridPos();
                
                if (manager.Chunked)
                {
                    list.AddRange(new DataList(new DataToken[] {
                        manager.GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(1, 1, 1))).AsDataToken(),
                        manager.GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(0, 1, 1))).AsDataToken(),
                        manager.GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(1, 0, 1))).AsDataToken(),
                        manager.GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(0, 0, 1))).AsDataToken(),
                        manager.GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(1, 1, 0))).AsDataToken(),
                        manager.GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(0, 1, 0))).AsDataToken(),
                        manager.GetDataAt(VolumeChunk.GridToKey(pos - new Vector3Int(1, 0, 0))).AsDataToken(),
                        manager.GetDataAt(VolumeChunk.GridToKey(pos)).AsDataToken(),
                    }));
                } 
                else
                {
                    list.Add(manager.GetDataAt(VolumeChunk.GridToKey(pos)).AsDataToken());
                }
            }
        
            return list;
        }

        // Methods
        public static bool WasEdited(this VolumeChunk self) => ((DataList)(object)self)[5].Boolean;
        public static void MarkEdited(this VolumeChunk self) => ((DataList)(object)self)[5] = true;


        public static bool IsDirty(this VolumeChunk self) => ((DataList)(object)self)[6].Boolean;
        public static void MarkDirty(this VolumeChunk self) => ((DataList)(object)self)[6] = true;
        public static void ClearDirty(this VolumeChunk self) => ((DataList)(object)self)[6] = false;

        public static void Destroy(this VolumeChunk self)
        {
            // Trick to get the GameObject of this chunk, since we don't save it directly at the moment.
            GameObject obj = self.GetMeshFilter().gameObject;
            GameObject.Destroy(obj);
        }


        public static bool IsVisible(this VolumeChunk self)
        {
            return self.GetMeshRenderer().enabled;
        }

        // Utils
        public static Vector3Int GetIntGridPos(this VolumeChunk self) => VolumeChunk.KeyToIntGrid(self.GetKey());
        public static Vector3 GetGridPos(this VolumeChunk self) => VolumeChunk.KeyToGrid(self.GetKey());
        public static DataToken AsDataToken(this VolumeChunk self) => (DataList)(object)self;
        public static VolumeChunk AsVolumeChunk(this DataToken self) => (VolumeChunk)(object)self.DataList;
    }
}