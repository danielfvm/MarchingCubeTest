
using System;
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using VRC.Udon.Common.Interfaces;

public class Button : UdonSharpBehaviour
{
    public string action;
    public UdonSharpBehaviour behaviour;

    public override void Interact()
    {
        behaviour.SendCustomNetworkEvent(NetworkEventTarget.All, action);
    }
}
