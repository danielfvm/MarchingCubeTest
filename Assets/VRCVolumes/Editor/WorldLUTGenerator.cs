using System;
using UnityEditor;
using UnityEngine;

public class WorldLUTGenerator : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        // render the default gui
        base.OnGUI(materialEditor, properties);

        Material targetMat = materialEditor.target as Material;

        // see if redify is set, and show a checkbox
        // float[] continentalnessLUT = Array.IndexOf(targetMat.shaderKeywords, "continentalnessLUT") != -1;
        float[] continentalnessLUT = targetMat.GetFloatArray("continentalnessLUT");
        if (continentalnessLUT == null) continentalnessLUT = new float[24];

        EditorGUI.BeginChangeCheck();
        AnimationCurve newCurve = new AnimationCurve();
        
        for (int i = 0; i < continentalnessLUT.Length; i++)
        {
            newCurve.AddKey((float)i / continentalnessLUT.Length, continentalnessLUT[i]);
        }

        newCurve = EditorGUILayout.CurveField("Test Curve", newCurve);
        if (EditorGUI.EndChangeCheck())
        {
            for (int i = 0; i < continentalnessLUT.Length; i++)
            {
                continentalnessLUT[i] = newCurve.Evaluate((float)i / continentalnessLUT.Length);
            }
            targetMat.SetFloatArray("continentalnessLUT", continentalnessLUT);
        }
    }
}
