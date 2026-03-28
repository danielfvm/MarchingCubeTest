using System;
using UnityEngine;
using VRC.SDK3.Data;

namespace VRCVolumes
{
    public static class VolumeDataExt
    {
        // Getters
        public static ulong GetKey(this VolumeData self) => ((DataList)(object)self)[0].ULong;
        public static RenderTexture GetData(this VolumeData self) => (RenderTexture)((DataList)(object)self)[1].Reference;
        public static RenderTexture GetLOD(this VolumeData self) => (RenderTexture)((DataList)(object)self)[2].Reference;
        public static bool IsDirty(this VolumeData self) => ((DataList)(object)self)[3].Boolean;
        public static void MarkDirty(this VolumeData self) {
            ((DataList)(object)self).SetValue(3, true);
        }

        // Methods
        public static void Destroy(this VolumeData self)
        {
            self.GetData().Release();
        
            RenderTexture lod = self.GetLOD();
            if (lod.IsCreated())
                lod.Release();
        }

        public static void ComputeLODs(this VolumeData self, VolumeAreaManager manager, int levels = -1)
        {
            /*
            RenderTexture data = self.GetData();
            RenderTexture lod = self.GetLOD();
            
            // We only create the render texture on demand -> saves on VRAM when LODs disabled
            if (!lod.IsCreated())
                lod.Create();

            // if no custom amount of levels is set we just use the maximum amount
            if (levels == -1)
                levels = Mathf.RoundToInt(Mathf.Log(data.width, 2));

            */
        }

        // Utils
        public static DataToken AsDataToken(this VolumeData self) => (DataList)(object)self;
        public static VolumeData AsVolumeData(this DataToken self) => (VolumeData)(object)self.DataList;
        public static Vector3 GetGridPos(this VolumeData self) => VolumeChunk.KeyToGrid(self.GetKey());
        public static Vector3Int GetIntGridPos(this VolumeData self) => VolumeChunk.KeyToIntGrid(self.GetKey());
    }
}