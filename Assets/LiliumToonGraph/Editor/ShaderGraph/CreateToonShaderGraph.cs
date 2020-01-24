//
// based on: com.unity.shadergraph@7.1.2\Editor\AssetCallbacks\CreateShaderGraph.cs
//
using System.IO;
using UnityEditor;
using UnityEditor.ProjectWindowCallback;
using UnityEditor.ShaderGraph;

namespace LiliumEditor.Toon
{
    static class CreateShaderGraph
    {
        [MenuItem ("Assets/Create/Shader/Toon Graph", false, 208)]
        public static void CreateUnlitMasterMaterialGraph ()
        {
            GraphUtil.CreateNewGraph (new ToonMasterNode ());
        }
    }
}
