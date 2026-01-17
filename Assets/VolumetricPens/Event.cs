
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

namespace VolumetricPens
{
    enum EventType
    {
        Paint,
        Erase,
        Clear,
    }

    public class Event : UdonSharpBehaviour
    {        public static Event Paint(Vector3 position, float scale) => (Event)(object)(new object[]
        {
            EventType.Paint,
            position,
            scale,
        });

        public static Event Erase(Vector3 position, float scale) => (Event)(object)(new object[]
        {
            EventType.Erase,
            position,
            scale,
        });

        public static Event Clear() => (Event)(object)(new object[]
        {
            EventType.Clear
        });
    }
}
