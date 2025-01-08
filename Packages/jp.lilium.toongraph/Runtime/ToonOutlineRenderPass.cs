using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;
using ProfilingScope = UnityEngine.Rendering.ProfilingScope;

namespace Lilium.ToonGraph.Runtime
{
    public class ToonOutlineRenderPass : ScriptableRenderPass
    {
        readonly string profilerTag;
        
        LayerMask layerMask;
        RenderQueueType renderQueueType;
        List<ShaderTagId> shaderTagIds = new();

        public ToonOutlineRenderPass(RenderPassEvent renderPassEvent, string profilerTag, LayerMask layerMask, RenderQueueType renderQueueType, List<string> shaderTagList)
        {
            this.renderPassEvent = renderPassEvent;
            this.profilerTag     = profilerTag;
            profilingSampler     = new ProfilingSampler(profilerTag);
            this.renderQueueType = renderQueueType;
            foreach (var tag in shaderTagList)
            {
                shaderTagIds.Add(new ShaderTagId(tag));
            }
        }

        // Passで使うデータを定義しておく
        internal class PassData
        {
            internal TextureHandle colorHandle;
            internal TextureHandle depthHandle;
            // このHandleをCommandBuffer.DrawRendererに渡す
            internal RendererListHandle rendererList;
        }

        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
        {
            //  RenderingDataでなく、ContextContainerから自分で必要なデータを撮るようになった
            UniversalCameraData    cameraData    = frameData.Get<UniversalCameraData>();
            UniversalRenderingData renderingData = frameData.Get<UniversalRenderingData>();
            UniversalLightData     lightData     = frameData.Get<UniversalLightData>();
            UniversalResourceData  resourceData  = frameData.Get<UniversalResourceData>();
            
            // 今回はRasterRenderPassで作成
            using (var builder = renderGraph.AddRasterRenderPass<PassData>(profilerTag, out var passData))
            {
                // ShaderなどでGlobalにアクセスする可能性がある場合は、Trueにしておく
                builder.UseAllGlobalTextures(true);
                
                // 特にターゲットを切り替える訳ではなくても、ターゲット設定をしないと怒られます。
                passData.colorHandle = resourceData.activeColorTexture;
                builder.SetRenderAttachment(passData.colorHandle,0);

                passData.depthHandle = resourceData.activeDepthTexture;
                builder.SetRenderAttachmentDepth(passData.depthHandle);
                
                // Render時のソート条件
                SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent)
                                                      ? SortingCriteria.CommonTransparent
                                                      : cameraData.defaultOpaqueSortFlags;
                
                // 描画設定、今回はマテリアルのoverrideなどを行わないのでShaderTagとソート条件のみ。
                // context.DrawRenderersを使用していた時とことなり、RenderStaeBlockのオーバーライドが不要なら用意しなくてよくなった。
                // RenderStaeteBlockを指定したい場合は、下記のRenderListParamに設定します。今回は無し。
                DrawingSettings  drawSettings     = RenderingUtils.CreateDrawingSettings(shaderTagIds, renderingData, cameraData, lightData, sortingCriteria);
                
                RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
                                                        ? RenderQueueRange.transparent
                                                        : RenderQueueRange.opaque;
                FilteringSettings filteringSettings = new FilteringSettings(renderQueueRange, layerMask);
               
                // RenderListHandleの取得
                // AssempblyReferenceでURPパッケージ参照いれてたり、直接URPパッケージ内にカスタム作成する場合 or URPパッケージのAssemblyInfoでInternalアクセスを許可している場合はm、RenderingUtils.CreateRendererList()が使えるので楽
                // URP使用しない場合もあるのでCore RPのみ利用パターンはこれ(URP17といいつつ)
                RendererListParams rendererListParams = new RendererListParams(renderingData.cullResults, drawSettings, filteringSettings);
                passData.rendererList          = renderGraph.CreateRendererList(rendererListParams);
                
                // このPassで使用するリソースとして宣言する
                builder.UseRendererList(passData.rendererList);
                
                
                builder.SetRenderFunc((PassData data, RasterGraphContext context) =>
                {
                    using (new ProfilingScope(context.cmd, profilingSampler))
                    {
                        // 描画
                        context.cmd.DrawRendererList(data.rendererList);
                    }
                });
            }
        }

    }
}