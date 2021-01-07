// based on: com.unity.shadergraph@10.0.0-preview.27\Editor\Generation\TargetResources\BlockFields.cs
using UnityEditor.ShaderGraph;
using UnityEditor.ShaderGraph.Internal;

namespace Lilium.ToonGraph.Editor
{
    internal static class ToonBlockFields 
    {
        [GenerateBlocks]
        internal struct VertexDescription
        {
            public static string name = "ToonVertexDescription";

            public static BlockFieldDescriptor OutlineWidth    = new BlockFieldDescriptor(VertexDescription.name, "OutlineWidth", "Outline Width", "VERTEXDESCRIPTION_OUTLINEWIDTH",
                new FloatControl(0.5f), ShaderStage.Vertex);

           public static BlockFieldDescriptor OutlinePosition        = new BlockFieldDescriptor(VertexDescription.name, "OutlinePosition", "Outline Position", "VERTEXDESCRIPTION_OUTLINEPOSITION",
                new PositionControl(CoordinateSpace.Object), ShaderStage.Vertex);
 
        }
        
        [GenerateBlocks]
        internal struct SurfaceDescription
        {
            public static string name = "ToonSurfaceDescription";

            public static BlockFieldDescriptor OutlineColor     = new BlockFieldDescriptor(SurfaceDescription.name, "OutlineColor", "Outline Color", "SURFACEDESCRIPTION_OUTLINECOLOR",
                new ColorControl(UnityEngine.Color.grey, false), ShaderStage.Fragment);
        }
    }
}