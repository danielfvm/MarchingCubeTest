using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDKBase;


namespace VolumetricPens
{
    public static class DataBlockExt
    {
        public static RenderTexture GetData(this DataBlock self) => (RenderTexture)((DataList)(object)self)[0].Reference;

        public static DataToken AsDataToken(this DataBlock self) => (DataList)(object)self;

        /*public static void Draw(this DataBlock self, MarchingCubeSystem system, Vector3 pos, float size)
        {
            var data = self.GetData();
            VRCGraphics.Blit(data, system.buffer);
            VRCGraphics.Blit(null, data, system.drawMaterial);
        }*/
    }
}