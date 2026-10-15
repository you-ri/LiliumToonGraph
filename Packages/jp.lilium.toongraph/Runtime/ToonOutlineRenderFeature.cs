using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using Unity.Collections;

public class ToonOutlineRenderFeature : ScriptableRendererFeature
{
    [Tooltip("アウトラインの太さの倍率。マテリアルの Outline Width に掛かる（1 でマテリアルのまま）")]
    [Range(0f, 8f)]
    public float widthScale = 1f;

    DrawObjectsPass drawObjectsPass;

    public override void Create()
    {
        // Create the render pass that draws the objects, and pass in the override material
        drawObjectsPass = new DrawObjectsPass();
        // パスが走る前に読まれても太さが 0 にならないように、作った時点でも入れておく
        drawObjectsPass.SetWidthScaleGlobal(widthScale);

        // Insert render passes after URP's post-processing render pass
        drawObjectsPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }
 
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Add the render pass to the URP rendering loop
        // インスペクタで変えた太さをそのフレームから効かせる
        drawObjectsPass.widthScale = widthScale;
        renderer.EnqueuePass(drawObjectsPass);
    }

    class DrawObjectsPass : ScriptableRenderPass
    {
        readonly GlobalKeyword _toonOutlineKeyword = GlobalKeyword.Create("_TOON_OUTLINE");

        /// <summary>アウトラインを描くシェーダーが読む太さの倍率（OutlineTransform.hlsl）</summary>
        static readonly int s_WidthScaleId = Shader.PropertyToID("_ToonOutlineWidthScale");

        /// <summary>アウトラインの太さの倍率。マテリアルの Outline Width に掛かる</summary>
        public float widthScale = 1f;

        readonly RenderStateBlock _renderStateBlock;

        public DrawObjectsPass()
        {
            _renderStateBlock = new RenderStateBlock(RenderStateMask.Raster);
            _renderStateBlock.rasterState = new RasterState { cullingMode = CullMode.Front };
        }
       
        public void SetWidthScaleGlobal(float scale)
        {
            Shader.SetGlobalFloat(s_WidthScaleId, scale);
        }

        private class PassData
        {
            // Create a field to store the list of objects to draw
            public RendererListHandle rendererListHandle;
            // 太さの倍率（このパスの間だけグローバルへ入れる）
            public float widthScale;
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
                passData.widthScale = widthScale;
                
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
                context.cmd.SetGlobalFloat(s_WidthScaleId, data.widthScale);
                context.cmd.SetKeyword(_toonOutlineKeyword, true);  
                context.cmd.DrawRendererList(data.rendererListHandle);
                context.cmd.SetKeyword(_toonOutlineKeyword, false);            
                // キーワードと同じく、このパスの外へは持ち出さない
                context.cmd.SetGlobalFloat(s_WidthScaleId, 1f);
            }

        }


    }
 
}