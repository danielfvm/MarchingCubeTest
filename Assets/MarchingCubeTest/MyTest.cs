
using System;
using UdonSharp;
using UnityEngine;
using VRC.SDK3.Data;
using VRC.SDKBase;
using VRC.Udon;

public class MyTest : UdonSharpBehaviour
{
    void Start()
    {
        Color32[] src = new Color32[1] { new Color32(1,2,3,4) };
        byte[] dst = (byte[])(Array)src;
        Debug.Log(dst);
        
        byte[] val = new byte[4];

        dst.CopyTo(val, 0);
    }
}
 