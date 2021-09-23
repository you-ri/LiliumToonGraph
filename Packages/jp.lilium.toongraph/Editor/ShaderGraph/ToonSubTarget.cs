// based on: UniversalSubTarget.cs
using UnityEngine;
using UnityEditor.ShaderGraph;
using static Unity.Rendering.Universal.ShaderUtils;
using UnityEditor.ShaderGraph.Internal;
using UnityEditor.Rendering.Universal.ShaderGraph;
using UnityEditor.Rendering.Universal;
using UnityEditor.Rendering;
using UnityEditor;

namespace Lilium.ToonGraph.Editor
{
    abstract class ToonSubTarget : SubTarget<ToonTarget> //Modified: , IHasMetadata
    {
        static readonly GUID kSourceCodeGuid = new GUID("92228d45c1ff66740bfa9e6d97f7e280");  // UniversalSubTarget.cs

        public override void Setup(ref TargetSetupContext context)
        {
            context.AddAssetDependency(kSourceCodeGuid, AssetCollection.Flags.SourceDependency);
        }

        // Modified:
        //protected abstract ShaderID shaderID { get; }

        public virtual string identifier => GetType().Name;
        
        // Modified:
        #if false
        public virtual ScriptableObject GetMetadataObject()
        {
            var urpMetadata = ScriptableObject.CreateInstance<ToonMetadata>();
            urpMetadata.shaderID = shaderID;
            return urpMetadata;
        }
        #endif

        private int lastMaterialNeedsUpdateHash = 0;
        protected virtual int ComputeMaterialNeedsUpdateHash() => 0;

        // Modified:
        #if false
        public override object saveContext
        {
            get
            {
                int hash = ComputeMaterialNeedsUpdateHash();
                bool needsUpdate = hash != lastMaterialNeedsUpdateHash;
                if (needsUpdate)
                    lastMaterialNeedsUpdateHash = hash;

                return new UniversalShaderGraphSaveContext { updateMaterials = needsUpdate };
            }
        }
        #endif
    }

    internal static class SubShaderUtils
    {
        internal static void AddFloatProperty(this PropertyCollector collector, string referenceName, float defaultValue, HLSLDeclaration declarationType = HLSLDeclaration.DoNotDeclare)
        {
            collector.AddShaderProperty(new Vector1ShaderProperty
            {
                floatType = FloatType.Default,
                hidden = true,
                overrideHLSLDeclaration = true,
                hlslDeclarationOverride = declarationType,
                value = defaultValue,
                displayName = referenceName,
                overrideReferenceName = referenceName,
            });
        }

        internal static void AddToggleProperty(this PropertyCollector collector, string referenceName, bool defaultValue, HLSLDeclaration declarationType = HLSLDeclaration.DoNotDeclare)
        {
            collector.AddShaderProperty(new BooleanShaderProperty
            {
                value = defaultValue,
                hidden = true,
                overrideHLSLDeclaration = true,
                hlslDeclarationOverride = declarationType,
                displayName = referenceName,
                overrideReferenceName = referenceName,
            });
        }

        // Overloads to do inline PassDescriptor modifications
        // NOTE: param order should match PassDescriptor field order for consistency
        #region PassVariant
        internal static PassDescriptor PassVariant(in PassDescriptor source, PragmaCollection pragmas)
        {
            var result = source;
            result.pragmas = pragmas;
            return result;
        }

        #endregion
    }
}
