using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine.Scripting.APIUpdating;

namespace UnityEngine.Experimental.Rendering.Universal
{
    public class RenderMixProjectionObjectsPass : ScriptableRenderPass
    {
        RenderQueueType renderQueueType;
        FilteringSettings m_FilteringSettings;
        RenderMixProjectionObjects.CustomCameraSettings m_CameraSettings;
        string m_ProfilerTag;
        ProfilingSampler m_ProfilingSampler;

        List<ShaderTagId> m_ShaderTagIdList = new List<ShaderTagId>();


        RenderStateBlock m_RenderStateBlock;

        public RenderMixProjectionObjectsPass (string profilerTag, RenderPassEvent renderPassEvent, string[] shaderTags, RenderQueueType renderQueueType, int layerMask, RenderMixProjectionObjects.CustomCameraSettings cameraSettings)
        {
            m_ProfilerTag = profilerTag;
            m_ProfilingSampler = new ProfilingSampler(profilerTag);
            this.renderPassEvent = renderPassEvent;
            this.renderQueueType = renderQueueType;
            RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;
            m_FilteringSettings = new FilteringSettings(renderQueueRange, layerMask);

            if (shaderTags != null && shaderTags.Length > 0)
            {
                foreach (var passName in shaderTags)
                    m_ShaderTagIdList.Add(new ShaderTagId(passName));
            }
            else
            {
                m_ShaderTagIdList.Add(new ShaderTagId("UniversalForward"));
                m_ShaderTagIdList.Add(new ShaderTagId("LightweightForward"));
                m_ShaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
            }

            m_RenderStateBlock = new RenderStateBlock(RenderStateMask.Nothing);
            m_CameraSettings = cameraSettings;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            bool isSceneViewCamera = renderingData.cameraData.isSceneViewCamera;

            SortingCriteria sortingCriteria = (renderQueueType == RenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : renderingData.cameraData.defaultOpaqueSortFlags;

            DrawingSettings drawingSettings = CreateDrawingSettings(m_ShaderTagIdList, ref renderingData, sortingCriteria);

            ref CameraData cameraData = ref renderingData.cameraData;
            Camera camera = cameraData.camera;
            var viewMatrixPrev = camera.worldToCameraMatrix;
            var projectionMatrixPrev = camera.projectionMatrix;

            // In case of camera stacking we need to take the viewport rect from base camera
            Rect pixelRect = camera.pixelRect; // = renderingData.cameraData.pixelRect;
            float cameraAspect = (float) pixelRect.width / (float) pixelRect.height;
            CommandBuffer cmd = CommandBufferPool.Get(m_ProfilerTag);
            using (new ProfilingScope(cmd, m_ProfilingSampler))
            {
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                if (!isSceneViewCamera)
                {
                    Matrix4x4 projectionMatrix = Matrix4x4.Perspective (m_CameraSettings.cameraFieldOfView, cameraAspect, camera.nearClipPlane, camera.farClipPlane);
                    Matrix4x4 viewMatrix = camera.worldToCameraMatrix;
                    Vector4 cameraTranslation = viewMatrix.GetColumn (3);

                    float ratio = projectionMatrix[1, 1] / camera.projectionMatrix[1, 1];

                    //Debug.Log (camera.projectionMatrix[1, 1] + " " + projectionMatrix[1, 1]);

                    viewMatrix.SetColumn(3, new Vector4(cameraTranslation.x, cameraTranslation.y, ratio * cameraTranslation.z, ratio) );

                    cmd.SetViewProjectionMatrices(viewMatrix, projectionMatrix);
                    context.ExecuteCommandBuffer(cmd);
                }

                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref m_FilteringSettings,
                    ref m_RenderStateBlock);

                cmd.Clear();
                cmd.SetViewProjectionMatrices(viewMatrixPrev, projectionMatrixPrev);
                //cmd.SetViewProjectionMatrices(cameraData.viewMatrix, cameraData.projectionMatrix);
            }

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}
