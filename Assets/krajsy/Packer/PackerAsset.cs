using System;
using System.Collections.Generic;
using System.IO;
using BestHTTP.SecureProtocol.Org.BouncyCastle.Math.Field;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

#if UNITY_EDITOR
[Serializable]
public class Pack
{
    public string name;
    public Texture2D albedo, normal, occlusion, displacement, roughness;
}

[CreateAssetMenu(fileName = "Asset", menuName = "Packer/Asset", order = 1)]
public class PackerAsset : ScriptableObject
{
    public int dimension = 1024;
    public List<Pack> packs;
}

[CustomEditor(typeof(PackerAsset))]
public class PackerAssetInspector : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();

        var self = (PackerAsset)target;

        if (GUILayout.Button("Generate"))
        {
            var absolutePath = EditorUtility.SaveFilePanel("Save Texture destination", "Assets/", "packed", "png");
            var filePath = "Assets" + absolutePath.Substring(Application.dataPath.Length);

            if (!filePath.ToLower().EndsWith(".png"))
                return;

            var rawPath = filePath.Substring(0, filePath.Length - Path.GetExtension(filePath).Length);
            var dim = new Vector2Int(self.dimension * self.packs.Count, self.dimension);
            var material = new Material(Shader.Find("PacketAsset/Packer"));
            var albedoDisplacementPass = material.FindPass("AlbedoDisplacement");
            var normalOcclusionRoughnessPass = material.FindPass("NormalOcclusionRoughness");

            // RGB = Albedo, A = Displacement
            var albedoDisplacementTex = new RenderTexture(dim.x, dim.y, 0);
            
            // RG = Normal, B = Occlusion, A = Roughness
            var normalOcclusionRoughnessTex = new RenderTexture(dim.x, dim.y, 0);
            
            for (int i = 0; i < self.packs.Count; i++)
            {
                var pack = self.packs[i];

                material.SetTexture("_AlbedoTex", pack.albedo);
                material.SetTexture("_OcclusionTex", pack.occlusion);

                material.SetTexture("_NormalTex", pack.normal);
                material.SetTexture("_DisplacementTex", pack.displacement);
                material.SetTexture("_RoughnessTex", pack.roughness);
                
                material.SetInteger("_Index", i);
                material.SetInteger("_Count", self.packs.Count);
                Graphics.Blit(null, albedoDisplacementTex, material, albedoDisplacementPass);
                Graphics.Blit(null, normalOcclusionRoughnessTex, material, normalOcclusionRoughnessPass);
            }

            AsyncGPUReadback.Request(albedoDisplacementTex, 0, (result) => {
                var resultTex = new Texture2D(dim.x, dim.y);
                resultTex.SetPixels32(result.GetData<Color32>().ToArray());
                resultTex.Apply();

                var path = $"{rawPath}_albedoDisplacement.png";
                File.WriteAllBytes(path, resultTex.EncodeToPNG());
                AssetDatabase.ImportAsset(path);

                albedoDisplacementTex.Release();
            });

            AsyncGPUReadback.Request(normalOcclusionRoughnessTex, 0, (result) => {
                var resultTex = new Texture2D(dim.x, dim.y);
                resultTex.SetPixels32(result.GetData<Color32>().ToArray());
                resultTex.Apply();

                var path = $"{rawPath}_NormalOcclusionRoughness.png";
                Debug.Log(path);
                File.WriteAllBytes(path, resultTex.EncodeToPNG());
                AssetDatabase.ImportAsset(path);
                EditorGUIUtility.PingObject(AssetDatabase.LoadAssetAtPath(path, typeof(Texture2D)));

                normalOcclusionRoughnessTex.Release();
            });
        }
    }
}
#endif