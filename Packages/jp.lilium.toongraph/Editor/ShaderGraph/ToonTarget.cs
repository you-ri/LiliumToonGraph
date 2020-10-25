using System;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.UIElements;
using UnityEditor.UIElements;
using UnityEditor.ShaderGraph;
using UnityEditor.ShaderGraph.Drawing;
using UnityEditor.Graphing.Util;
using UnityEditor.ShaderGraph.Internal;
using UnityEditor.ShaderGraph.Legacy;

using UnityEditor.Rendering.Universal.ShaderGraph;


namespace UnityEditor.ShaderGraph
{
    sealed class ToonTarget : Target, ILegacyTarget
    {
        const string kAssetGuid = "9172C44166BA4EBAB787AC35964DE4CC";

        [SerializeField]
        bool m_Lit;

        [SerializeField]
        bool m_AlphaTest = false;


        [SerializeField]
        SurfaceType m_SurfaceType = SurfaceType.Opaque;


        [SerializeField]
        bool m_AlphaClip = false;        

        
        public ToonTarget()
        {
            displayName = "Lilium Toon";
        }

        public bool lit
        {
            get => m_Lit;
            set => m_Lit = value;
        }

        public bool alphaTest
        {
            get => m_AlphaTest;
            set => m_AlphaTest = value;
        }


        public SurfaceType surfaceType
        {
            get => m_SurfaceType;
            set => m_SurfaceType = value;
        }


        public bool alphaClip
        {
            get => m_AlphaClip;
            set => m_AlphaClip = value;
        }

        public string renderType
        {
            get
            {
                if(surfaceType == SurfaceType.Transparent)
                    return $"{RenderType.Transparent}";
                else
                    return $"{RenderType.Opaque}";
            }
        }

        public string renderQueue
        {
            get
            {
                if(surfaceType == SurfaceType.Transparent)
                    return $"{UnityEditor.ShaderGraph.RenderQueue.Transparent}";
                else if(alphaClip)
                    return $"{UnityEditor.ShaderGraph.RenderQueue.AlphaTest}";
                else
                    return $"{UnityEditor.ShaderGraph.RenderQueue.Geometry}";
            }
        }        

        public override bool IsActive() => true;
        
        public override void Setup(ref TargetSetupContext context)
        {
            context.AddAssetDependencyPath(AssetDatabase.GUIDToAssetPath(kAssetGuid));

            // Process SubShaders
            SubShaderDescriptor[] subShaders = { SubShaders.Unlit, SubShaders.UnlitDOTS };
            for(int i = 0; i < subShaders.Length; i++)
            {
                // Update Render State
                subShaders[i].renderType = this.renderType;
                subShaders[i].renderQueue = this.renderQueue;

                // Add
                context.AddSubShader(subShaders[i]);
            }            
        }

        public override void GetFields(ref TargetFieldContext context)
        {
            var descs = context.blocks.Select(x => x.descriptor);
            // Core fields
            context.AddField(Fields.GraphVertex,            descs.Contains(BlockFields.VertexDescription.Position) ||
                                                            descs.Contains(BlockFields.VertexDescription.Normal) ||
                                                            descs.Contains(BlockFields.VertexDescription.Tangent));
            context.AddField(Fields.GraphPixel);
            context.AddField(Fields.AlphaClip,              alphaClip);
        }

        public override bool IsNodeAllowedByTarget(Type nodeType)
        {
            return true;
        }

        public override void GetActiveBlocks(ref TargetActiveBlockContext context)
        {

            // Core blocks
            context.AddBlock(BlockFields.VertexDescription.Position);
            context.AddBlock(BlockFields.VertexDescription.Normal);
            context.AddBlock(BlockFields.VertexDescription.Tangent);
            context.AddBlock(ToonBlockFields.VertexDescription.OutlineWidth);

            context.AddBlock(BlockFields.SurfaceDescription.BaseColor);
            context.AddBlock(BlockFields.SurfaceDescription.Alpha);
            context.AddBlock(BlockFields.SurfaceDescription.AlphaClipThreshold, alphaTest);
            context.AddBlock(ToonBlockFields.SurfaceDescription.OutlineColor);
        }

        enum MaterialMode
        {
            Unlit,
            Lit
        }

        public override void GetPropertiesGUI(ref TargetPropertyGUIContext context, Action onChange, Action<String> registerUndo)
        {
            context.AddProperty("Material", new EnumField(MaterialMode.Unlit) { value = m_Lit ? MaterialMode.Lit : MaterialMode.Unlit }, evt =>
            {
                var newLit = (MaterialMode)evt.newValue == MaterialMode.Lit;
                if (Equals(m_Lit, newLit))
                    return;

                registerUndo("Change Material Lit");
                m_Lit = newLit;
                onChange();
            });

            context.AddProperty("Alpha Clipping", new Toggle() { value = m_AlphaTest }, (evt) =>
            {
                if (Equals(m_AlphaTest, evt.newValue))
                    return;

                registerUndo("Change Alpha Test");
                m_AlphaTest = evt.newValue;
                onChange();
            });
        }

        // TODO: delete ??
        public static Dictionary<BlockFieldDescriptor, int> s_BlockMap = new Dictionary<BlockFieldDescriptor, int>()
        {
            { ToonBlockFields.SurfaceDescription.OutlineColor, ShaderGraphVfxAsset.ColorSlotId },   
            { ToonBlockFields.VertexDescription.OutlineWidth, ShaderGraphVfxAsset.MetallicSlotId }, //TODO:
            { BlockFields.SurfaceDescription.Alpha, ShaderGraphVfxAsset.AlphaSlotId },
            { BlockFields.SurfaceDescription.AlphaClipThreshold, ShaderGraphVfxAsset.AlphaThresholdSlotId },
        };

        // TODO: マスターノードからのアップグレードはサポートしないため削除してもよい
        public bool TryUpgradeFromMasterNode(IMasterNode1 masterNode, out Dictionary<BlockFieldDescriptor, int> blockMap)
        {
            blockMap = null;
            if(!(masterNode is VisualEffectMasterNode1 vfxMasterNode))
                return false;

            lit = vfxMasterNode.m_Lit;
            alphaTest = vfxMasterNode.m_AlphaTest;

            blockMap = new Dictionary<BlockFieldDescriptor, int>();
            if (lit)
            {
                blockMap.Add(ToonBlockFields.SurfaceDescription.OutlineColor, ShaderGraphVfxAsset.ColorSlotId);
            }
            else
            {
                blockMap.Add(ToonBlockFields.SurfaceDescription.OutlineColor, ShaderGraphVfxAsset.ColorSlotId);
            }

            blockMap.Add(BlockFields.SurfaceDescription.Alpha, ShaderGraphVfxAsset.AlphaSlotId);

            if(alphaTest)
            {
                blockMap.Add(BlockFields.SurfaceDescription.AlphaClipThreshold, ShaderGraphVfxAsset.AlphaThresholdSlotId);
            }

            return true;
        }

        public override bool WorksWithSRP(RenderPipelineAsset scriptableRenderPipeline)
        {
            return GraphicsSettings.currentRenderPipeline != null && scriptableRenderPipeline?.GetType() == GraphicsSettings.currentRenderPipeline.GetType();
        }



#region SubShader
        static class SubShaders
        {
            public static SubShaderDescriptor Unlit = new SubShaderDescriptor()
            {
                pipelineTag = UniversalTarget.kPipelineTag,
                generatesPreview = true,
                passes = new PassCollection
                {
                    { UnlitPasses.Unlit },
                    { UnlitPasses.Outline },
                    { CorePasses.ShadowCaster },
                    { CorePasses.DepthOnly },
                },
            };

            public static SubShaderDescriptor UnlitDOTS
            {
                get
                {
                    var unlit = UnlitPasses.Unlit;
                    var outline = UnlitPasses.Outline;
                    var shadowCaster = CorePasses.ShadowCaster;
                    var depthOnly = CorePasses.DepthOnly;

                    unlit.pragmas = CorePragmas.DOTSForward;
                    outline.pragmas = CorePragmas.DOTSForward;
                    shadowCaster.pragmas = CorePragmas.DOTSInstanced;
                    depthOnly.pragmas = CorePragmas.DOTSInstanced;
                    
                    return new SubShaderDescriptor()
                    {
                        pipelineTag = UniversalTarget.kPipelineTag,
                        generatesPreview = true,
                        passes = new PassCollection
                        {
                            { unlit },
                            { outline },
                            { shadowCaster },
                            { depthOnly },
                        },
                    };
                }
            }
        }
#endregion


#region RenderStates
    static class ToonRenderStates
    {
        public static readonly RenderStateCollection Outline = new RenderStateCollection
        {
            { RenderState.ZTest(ZTest.Less) },
            { RenderState.ZWrite(ZWrite.On) },
            { RenderState.Cull(Cull.Front) },
            { RenderState.Blend(Blend.SrcAlpha, Blend.OneMinusSrcAlpha, Blend.One, Blend.OneMinusSrcAlpha) },
        };
    
    };
#endregion

#region Pass

        static class UnlitPasses
        {
            public static PassDescriptor Unlit = new PassDescriptor
            {
                // Definition
                displayName = "Pass",
                referenceName = "SHADERPASS_UNLIT",
                lightMode = "UniversalForward",
                useInPreview = true,

                // Template
                passTemplatePath = GenerationUtils.GetDefaultTemplatePath("PassMesh.template"),
                sharedTemplateDirectories = GenerationUtils.GetDefaultSharedTemplateDirectories(),

                // Port Mask
                validVertexBlocks = CoreBlockMasks.Vertex,
                validPixelBlocks =  CoreBlockMasks.FragmentColorAlpha,

                // Fields
                structs = CoreStructCollections.Default,
                requiredFields = ToonRequiredFields.Forward,                
                fieldDependencies = CoreFieldDependencies.Default,

                // Conditional State
                renderStates = CoreRenderStates.Default,
                pragmas = CorePragmas.Forward,
                keywords = UnlitKeywords.Unlit,
                includes = ToonIncludes.Unlit,
            };

            public static PassDescriptor Outline = new PassDescriptor
            {
                // Definition
                displayName = "Universal Outline",
                referenceName = "SHADERPASS_FORWARD",
                useInPreview = true,

                // Template
                passTemplatePath = GenerationUtils.GetDefaultTemplatePath("PassMesh.template"),
                sharedTemplateDirectories = GenerationUtils.GetDefaultSharedTemplateDirectories(),

                // Port Mask
                validVertexBlocks = ToonBlockMasks.Vertex,
                validPixelBlocks = ToonBlockMasks.FragmentToon,

                // Fields
                structs = CoreStructCollections.Default,
                requiredFields = ToonRequiredFields.Forward,                
                fieldDependencies = CoreFieldDependencies.Default,

                // Conditional State
                renderStates = ToonRenderStates.Outline,
                pragmas = CorePragmas.Forward,
                keywords = UnlitKeywords.Unlit,
                includes = ToonIncludes.Outline,
            };            
        }
#endregion

#region RequiredFields
        static class ToonRequiredFields
        {
            public static FieldCollection Forward = new FieldCollection()
            {
                StructFields.Attributes.uv1,                            // needed for meta vertex position
                StructFields.Varyings.positionWS,
                StructFields.Varyings.normalWS,
                StructFields.Varyings.tangentWS,                        // needed for vertex lighting
                StructFields.Varyings.viewDirectionWS,
                UniversalStructFields.Varyings.lightmapUV,
                UniversalStructFields.Varyings.sh,
                UniversalStructFields.Varyings.fogFactorAndVertexLight, // fog and vertex lighting, vert input is dependency
                UniversalStructFields.Varyings.shadowCoord,             // shadow coord, vert input is dependency
            };

            public static FieldCollection GBuffer = new FieldCollection()
            {
                StructFields.Attributes.uv1,                            // needed for meta vertex position
                StructFields.Varyings.positionWS,
                StructFields.Varyings.normalWS,
                StructFields.Varyings.tangentWS,                        // needed for vertex lighting
                StructFields.Varyings.viewDirectionWS,
                UniversalStructFields.Varyings.lightmapUV,
                UniversalStructFields.Varyings.sh,
                UniversalStructFields.Varyings.fogFactorAndVertexLight, // fog and vertex lighting, vert input is dependency
                UniversalStructFields.Varyings.shadowCoord,             // shadow coord, vert input is dependency
            };

            public static FieldCollection DepthNormals = new FieldCollection()
            {
                StructFields.Attributes.uv1,                            // needed for meta vertex position
                StructFields.Varyings.normalWS,
                StructFields.Varyings.tangentWS,                        // needed for vertex lighting
            };

            public static FieldCollection Meta = new FieldCollection()
            {
                StructFields.Attributes.uv1,                            // needed for meta vertex position
                StructFields.Attributes.uv2,                            //needed for meta vertex position
            };
        }
#endregion

#region PortMasks
        static class ToonBlockMasks
        {
        public static BlockFieldDescriptor[] Vertex = new BlockFieldDescriptor[]
            {
                BlockFields.VertexDescription.Position,
                BlockFields.VertexDescription.Normal,
                BlockFields.VertexDescription.Tangent,
                ToonBlockFields.VertexDescription.OutlineWidth,
            };            

            public static BlockFieldDescriptor[] FragmentToon = new BlockFieldDescriptor[]
            {
                BlockFields.SurfaceDescription.BaseColor,
                BlockFields.SurfaceDescription.NormalOS,
                BlockFields.SurfaceDescription.NormalTS,
                BlockFields.SurfaceDescription.NormalWS,
                BlockFields.SurfaceDescription.Emission,
                BlockFields.SurfaceDescription.Metallic,
                BlockFields.SurfaceDescription.Specular,
                BlockFields.SurfaceDescription.Smoothness,
                BlockFields.SurfaceDescription.Occlusion,
                BlockFields.SurfaceDescription.Alpha,
                BlockFields.SurfaceDescription.AlphaClipThreshold,
                ToonBlockFields.SurfaceDescription.OutlineColor,
            };

            public static BlockFieldDescriptor[] FragmentMeta = new BlockFieldDescriptor[]
            {
                BlockFields.SurfaceDescription.BaseColor,
                BlockFields.SurfaceDescription.Emission,
                BlockFields.SurfaceDescription.Alpha,
                BlockFields.SurfaceDescription.AlphaClipThreshold,
            };

            public static BlockFieldDescriptor[] FragmentDepthNormals = new BlockFieldDescriptor[]
            {
                BlockFields.SurfaceDescription.NormalOS,
                BlockFields.SurfaceDescription.NormalTS,
                BlockFields.SurfaceDescription.NormalWS,
                BlockFields.SurfaceDescription.Alpha,
                BlockFields.SurfaceDescription.AlphaClipThreshold,
            };

        }
#endregion


#region Keywords
        static class UnlitKeywords
        {
            public static KeywordCollection Unlit = new KeywordCollection
            {
                { CoreKeywordDescriptors.Lightmap },
                { CoreKeywordDescriptors.DirectionalLightmapCombined },
                { CoreKeywordDescriptors.SampleGI },
            };
        }
#endregion

#region Includes
        static class ToonIncludes
        {
            const string kUnlitPass = "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/UnlitPass.hlsl";            
            const string kOutlinePass = "Packages/jp.lilium.toongraph/Editor/ShaderGraph/ToonOutlinePass.hlsl";
            
            public static IncludeCollection Unlit = new IncludeCollection
            {
                // Pre-graph
                { CoreIncludes.CorePregraph },
                { CoreIncludes.ShaderGraphPregraph },

                // Post-graph
                { CoreIncludes.CorePostgraph },
                { kUnlitPass, IncludeLocation.Postgraph },
            };

            public static IncludeCollection Outline = new IncludeCollection
            {
                // Pre-graph
                { CoreIncludes.CorePregraph },
                { CoreIncludes.ShaderGraphPregraph },

                // Post-graph
                { CoreIncludes.CorePostgraph },
                { kOutlinePass, IncludeLocation.Postgraph },
            };            
        }
#endregion     


    }

    // based on: com.unity.render-pipelines.universal\Editor\ShaderGraph\AssetCallbacks\CreateLitShaderGraph.cs
    // TODO:
    static class CreateToonShaderGraph
    {
        [MenuItem("Assets/Create/Shader/Toon Shader Graph", false, 208)]
        public static void CreateToonGraph()
        {
            var target = (ToonTarget)Activator.CreateInstance(typeof(ToonTarget));

            var blockDescriptors = new [] 
            { 
                BlockFields.SurfaceDescription.BaseColor,
                BlockFields.SurfaceDescription.Alpha,
            };

            GraphUtil.CreateNewGraphWithOutputs(new [] {target}, blockDescriptors);
        }
    }    

    // based on: com.unity.shadergraph@10.0.0-preview.27\Editor\Generation\TargetResources\BlockFields.cs
    internal static class ToonBlockFields 
    {
        [GenerateBlocks]
        internal struct VertexDescription
        {
            public static string name = "ToonVertexDescription";

            public static BlockFieldDescriptor OutlineWidth    = new BlockFieldDescriptor(VertexDescription.name, "OutlineWidth", "Outline Width", "SURFACEDESCRIPTION_OUTLINEWIDTH",
                new FloatControl(0.5f), ShaderStage.Vertex);
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
