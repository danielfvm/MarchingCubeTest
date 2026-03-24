
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;

public class VolumeData : UdonSharpBehaviour
{
    public static VolumeData Create(ulong key, RenderTexture data)
    {
        return (VolumeData)(object)new DataList(new DataToken[]
        {
            key,
            data,
            new RenderTexture(data),
        });
    }
}