#if UNITY_EDITOR
using System.IO;
using UnityEditor;

namespace UdonSharpOptimizer
{
    [InitializeOnLoad]
    public static class USOPatch
    {
        static USOPatch()
        {
            PatchUdonSharp();
        }

        [MenuItem("UdonSharpOptimizer/Patch UdonSharp")]
        public static void PatchUdonSharp()
        {
            const string path = "Packages/com.vrchat.worlds/Integrations/UdonSharp/Editor/USOInternals.cs";
            if (!File.Exists(path))
            {
                if (EditorUtility.DisplayDialog("Patch UdonSharp", "This version of Unity requires a small patch to UdonSharp for the optimizer to function.\nWould you like to apply this patch?", "Yes", "No"))
                {
                    File.WriteAllText(path, @"[assembly: System.Runtime.CompilerServices.InternalsVisibleTo(""BlueAmulet.UdonSharpOptimizer"")]");
                    AssetDatabase.Refresh();
                }
            }
        }
    }
}
#endif