
using UdonSharp;
using UnityEngine;
using VolumetricPens;
using VRC.SDKBase;
using VRC.Udon;

public class DataBlock : UdonSharpBehaviour
{
    public static DataBlock Empty(MarchingCubeSystem system)
    {
        int[] dimToTextureSize = new int[] { 
            /* 64: */ 512, 
            /* 32: */ 256, /* 181.02 */
            /* 16: */ 64, 
            /*  8: */ 32, /* 22.63 */
            /*  4: */ 8 
        };

        RenderTexture[] lod = new RenderTexture[dimToTextureSize.Length];
        
        for (int i = 0; i < dimToTextureSize.Length; i++)
        {
            int size = dimToTextureSize[i];
            lod[i] = new RenderTexture(size, size, 0, RenderTextureFormat.RFloat);
            lod[i].filterMode = FilterMode.Point;
            lod[i].Create();
        }

        return (DataBlock)(object)new object[]
        {
            system,
            lod
        };
    }
}
