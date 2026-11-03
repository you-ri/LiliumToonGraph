using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using Unity.Collections;
using Lilium.ToonGraph.Runtime;

/// <summary>
/// Lilium Toon のアウトラインを描く。あわせて点光源・スポットライトの光源の半径（プロジェクト設定の既定と <see cref="ToonLightSourceRadius"/>）をシェーダーへ送る。
/// </summary>
public class ToonOutlineRenderFeature : ScriptableRendererFeature
{
    [Tooltip("アウトラインの太さの倍率。マテリアルの Outline Width に掛かる（1 でマテリアルのまま）")]
    [Range(0f, 8f)]
    public float widthScale = 1f;

    DrawObjectsPass drawObjectsPass;
    LightSourceRadiusPass lightSourceRadiusPass;

    public override void Create()
    {
        // Create the render pass that draws the objects, and pass in the override material
        drawObjectsPass = new DrawObjectsPass();
        // パスが走る前に読まれても太さが 0 にならないように、作った時点でも入れておく
        drawObjectsPass.SetWidthScaleGlobal(widthScale);

        // Insert render passes after URP's post-processing render pass
        drawObjectsPass.renderPassEvent = RenderPassEvent.AfterRenderingOpaques;

        // トゥーンのマテリアルを描く前に半径を入れておく
        lightSourceRadiusPass = new LightSourceRadiusPass();
        lightSourceRadiusPass.renderPassEvent = RenderPassEvent.BeforeRenderingPrePasses;
    }
 
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        // Add the render pass to the URP rendering loop
        // インスペクタで変えた太さをそのフレームから効かせる
        drawObjectsPass.widthScale = widthScale;
        renderer.EnqueuePass(lightSourceRadiusPass);
        renderer.EnqueuePass(drawObjectsPass);
    }

    /// <summary>
    /// 追加ライトの半径の配列をグローバル _ToonLightSourceRadius へ入れる（ToonLighting.hlsl が読む）。
    /// 画面に映るライトはカリングの後にしか分からないので、カメラごとにここで並べる。
    /// </summary>
    class LightSourceRadiusPass : ScriptableRenderPass
    {
        static readonly int s_RadiusId = Shader.PropertyToID("_ToonLightSourceRadius");

        // 配列のグローバルは最初に入れた長さで固定されるので、URP の追加ライトの上限と同じ長さで毎回送る
        float[] _radii;

        class PassData
        {
            public float[] radii;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameContext)
        {
            UniversalLightData lightData = frameContext.Get<UniversalLightData>();
            int count = UniversalRenderPipeline.maxVisibleAdditionalLights;
            if (_radii == null || _radii.Length != count)
                _radii = new float[count];
            // 設定が無い（URP のグローバル設定アセットが古い）ときも既定値を使う
            bool enabled = true;
            float defaultRadius = 0.5f;
            if (GraphicsSettings.TryGetRenderPipelineSettings<LiliumToonSettings>(out var settings))
            {
                enabled = settings.lightSourceRadiusEnabled;
                defaultRadius = settings.defaultLightSourceRadius;
            }
            // 切っているときは全部 0（URP のまま 1/d²）。前のカメラの値を残さないように送ること自体は続ける
            if (enabled)
                ToonLightSourceRadius.FillAdditionalLightRadii(new VisibleLightList(lightData.visibleLights), lightData.mainLightIndex, defaultRadius, _radii);
            else
                System.Array.Clear(_radii, 0, _radii.Length);

            using (var builder = renderGraph.AddUnsafePass<PassData>("LiliumToonLightSourceRadius", out var passData))
            {
                passData.radii = _radii;
                builder.AllowPassCulling(false);
                builder.AllowGlobalStateModification(true);
                builder.SetRenderFunc(static (PassData data, UnsafeGraphContext context) =>
                    context.cmd.SetGlobalFloatArray(s_RadiusId, data.radii));
            }
        }

        readonly struct VisibleLightList : ToonLightSourceRadius.IVisibleLightList
        {
            readonly NativeArray<VisibleLight> _lights;

            public VisibleLightList(NativeArray<VisibleLight> lights) => _lights = lights;

            public int Count => _lights.IsCreated ? _lights.Length : 0;
            public LightType GetLightType(int index) => _lights[index].lightType;
            public Light GetLight(int index) => _lights[index].light;
        }
    }

    class DrawObjectsPass : ScriptableRenderPass
    {
        static readonly GlobalKeyword s_ToonOutlineKeyword = GlobalKeyword.Create("_TOON_OUTLINE");

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

                // this を掴むと記録のたびにデリゲートを作って GC Alloc が出るので、static のまま渡す
                builder.SetRenderFunc(static (PassData data, RasterGraphContext context) => ExecutePass(data, context));

            }

            static void ExecutePass(PassData data, RasterGraphContext context)
            {
                context.cmd.SetGlobalFloat(s_WidthScaleId, data.widthScale);
                context.cmd.SetKeyword(s_ToonOutlineKeyword, true);  
                context.cmd.DrawRendererList(data.rendererListHandle);
                context.cmd.SetKeyword(s_ToonOutlineKeyword, false);            
                // キーワードと同じく、このパスの外へは持ち出さない
                context.cmd.SetGlobalFloat(s_WidthScaleId, 1f);
            }

        }


    }
 
}