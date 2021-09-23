/// based on: UniversalStructs.cs

using UnityEditor.ShaderGraph;

namespace Lilium.ToonGraph.Editor
{
    static class UniversalStructs
    {

        public static StructDescriptor Varyings = new StructDescriptor()
        {
            name = "Varyings",
            packFields = true,
            populateWithCustomInterpolators = true,
            fields = new FieldDescriptor[]
            {
                StructFields.Varyings.positionCS,
                StructFields.Varyings.positionWS,
                StructFields.Varyings.normalWS,
                StructFields.Varyings.tangentWS,
                StructFields.Varyings.texCoord0,
                StructFields.Varyings.texCoord1,
                StructFields.Varyings.texCoord2,
                StructFields.Varyings.texCoord3,
                StructFields.Varyings.color,
                StructFields.Varyings.viewDirectionWS,
                StructFields.Varyings.screenPosition,
                ToonStructFields.Varyings.staticLightmapUV,
                ToonStructFields.Varyings.dynamicLightmapUV,
                ToonStructFields.Varyings.sh,
                ToonStructFields.Varyings.fogFactorAndVertexLight,
                ToonStructFields.Varyings.shadowCoord,
                StructFields.Varyings.instanceID,
                ToonStructFields.Varyings.stereoTargetEyeIndexAsBlendIdx0,
                ToonStructFields.Varyings.stereoTargetEyeIndexAsRTArrayIdx,
                StructFields.Varyings.cullFace,
            }
        };
    }
}
