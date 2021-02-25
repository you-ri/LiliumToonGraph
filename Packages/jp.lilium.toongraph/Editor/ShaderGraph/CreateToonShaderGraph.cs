// based on: com.unity.render-pipelines.universal\Editor\ShaderGraph\AssetCallbacks\CreateLitShaderGraph.cs
using System;
using UnityEditor;
using UnityEditor.ShaderGraph;


namespace Lilium.ToonGraph.Editor
{
    static class CreateToonShaderGraph
    {
        [MenuItem("Assets/Create/Shader/Universal Render Pipeline/Lilium Toon Shader Graph", false, 208)]
        public static void CreateToonGraph()
        {
            var target = (ToonTarget)Activator.CreateInstance(typeof(ToonTarget));

            var blockDescriptors = new [] 
            { 
                BlockFields.VertexDescription.Position,
                BlockFields.VertexDescription.Normal,
                BlockFields.VertexDescription.Tangent,
                ToonBlockFields.VertexDescription.OutlinePosition,

                BlockFields.SurfaceDescription.BaseColor,
                ToonBlockFields.SurfaceDescription.OutlineColor,
            };

            GraphUtil.CreateNewGraphWithOutputs(new [] {target}, blockDescriptors);
        }
    }    
}