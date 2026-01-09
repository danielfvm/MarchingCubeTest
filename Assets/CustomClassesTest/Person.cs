
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class Person : UdonSharpBehaviour
{
    public static Person New(string name, int age) => (Person)(object)new object[] { name, age };
}
