using System;
//
// based on: com.unity.shadergraph@5.6.1\Editor\Data\MasterNodes\PBRMasterGUI.cs
//

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
