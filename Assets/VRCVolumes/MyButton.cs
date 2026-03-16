
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
    public Text text;

    public override void Interact()
    {
        text.text = (volumeArea.TotalTextureDataInBytes / 1024 / 1024) + "MiB";
    }
}
