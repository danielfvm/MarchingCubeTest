
using System;
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;
using VRC.Udon;
using VRCVolumes;

public class MyButton : UdonSharpBehaviour
{
    public VolumeAreaManager volumeArea;
    public Material material;
    public Text text;
    private bool e;

    public override void Interact()
    {
        e = !e;

        if (e) 
            material.EnableKeyword("_SMOOTH_SHADING_ON");
        else
            material.DisableKeyword("_SMOOTH_SHADING_ON");
        
        text.text = (volumeArea.TotalTextureDataInBytes / 1024 / 1024) + "MiB";
    }
}
