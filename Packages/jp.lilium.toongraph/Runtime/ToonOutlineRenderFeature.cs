using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using Unity.Collections;

public class ToonOutlineRenderFeature : ScriptableRendererFeature
{
    DrawObjectsPass drawObjectsPass;

    public override void Create()
    {
        // Create the render pass that draws the objects, and pass in the override material
        drawObjectsPass = new DrawObjectsPass();

        // Insert render passes after URP's post-processing render pass
        drawObjectsPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }
 
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Add the render pass to the URP rendering loop
        renderer.EnqueuePass(drawObjectsPass);
    }

    class DrawObjectsPass : ScriptableRenderPass
    {
        readonly GlobalKeyword _toonOutlineKeyword = GlobalKeyword.Create("_TOON_OUTLINE");

        readonly RenderStateBlock _renderStateBlock;

        public DrawObjectsPass()
        {
            _renderStateBlock = new RenderStateBlock(RenderStateMask.Raster);
            _renderStateBlock.rasterState = new RasterState { cullingMode = CullMode.Front };
        }
       
        private class PassData
        {
            // Create a field to store the list of objects to draw
            public RendererListHandle rendererListHandle;
        }
 
        static RenderStateBlock[] s_RenderStateBlocks = new RenderStateBlock[1];
        static ShaderTagId[] s_ShaderTagValues = new ShaderTagId[1];
        
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameContext)
        {
            using (var builder = renderGraph.AddRasterRenderPass<PassData>("LiliumToonOutline", out var passData))
            {
                // Get the data needed to create the list of objects to draw
                UniversalRenderingData renderingData = frameContext.Get<UniversalRenderingData>();
                UniversalCameraData cameraData = frameContext.Get<UniversalCameraData>();
                UniversalLightData lightData = frameContext.Get<UniversalLightData>();
                SortingCriteria sortFlags = cameraData.defaultOpaqueSortFlags;
                RenderQueueRange renderQueueRange = RenderQueueRange.opaque;
                FilteringSettings filterSettings = new FilteringSettings(renderQueueRange);

                // Redraw only objects that have their LightMode tag set to UniversalForward 
                ShaderTagId shadersToOverride = new ShaderTagId("UniversalForward");

                // Create drawing settings
                DrawingSettings drawSettings = RenderingUtils.CreateDrawingSettings(shadersToOverride, renderingData, cameraData, lightData, sortFlags);

                // Create the list of objects to draw
                s_RenderStateBlocks[0] = _renderStateBlock;
                s_ShaderTagValues[0] = ShaderTagId.none;
                NativeArray<ShaderTagId> tagValues = new NativeArray<ShaderTagId>(s_ShaderTagValues, Allocator.Temp);
                NativeArray<RenderStateBlock> stateBlocks = new NativeArray<RenderStateBlock>(s_RenderStateBlocks, Allocator.Temp);            
                var rendererListParameters = new RendererListParams(renderingData.cullResults, drawSettings, filterSettings)
                {
                    tagValues = tagValues,                    
                    stateBlocks = stateBlocks
                };
                // Convert the list to a list handle that the render graph system can use
                passData.rendererListHandle = renderGraph.CreateRendererList(rendererListParameters);
                
                // Set the render target as the color and depth textures of the active camera texture
                UniversalResourceData resourceData = frameContext.Get<UniversalResourceData>();
                builder.UseRendererList(passData.rendererListHandle);
                builder.SetRenderAttachment(resourceData.activeColorTexture, 0);
                builder.SetRenderAttachmentDepth(resourceData.activeDepthTexture, AccessFlags.Write);
                builder.AllowGlobalStateModification(true);

                builder.SetRenderFunc((PassData data, RasterGraphContext context) => ExecutePass(data, context));

            }

            void ExecutePass(PassData data, RasterGraphContext context)
            {
                context.cmd.SetKeyword(_toonOutlineKeyword, true);  
                context.cmd.DrawRendererList(data.rendererListHandle);
                context.cmd.SetKeyword(_toonOutlineKeyword, false);            
            }

        }


    }
 
}