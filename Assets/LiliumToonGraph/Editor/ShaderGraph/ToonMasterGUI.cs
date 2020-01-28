//
// based on: com.unity.shadergraph@7.1.2\Editor\PBRMasterGUI.cs
//
using System;
using UnityEngine;
using UnityEditor;


namespace LiliumEditor.Toon
{
    class ToonMasterGUI : ShaderGUI
    {
        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
			materialEditor.PropertiesDefaultGUI(props);

            foreach (MaterialProperty prop in props)
            {
                if (prop.name == "_EmissionColor")
                {
                    if (materialEditor.EmissionEnabledProperty())
                    {
                        materialEditor.LightmapEmissionFlagsProperty(MaterialEditor.kMiniTextureFieldLabelIndentLevel, true);
                    }
                    return;
                }
            }
        }
    }
}
