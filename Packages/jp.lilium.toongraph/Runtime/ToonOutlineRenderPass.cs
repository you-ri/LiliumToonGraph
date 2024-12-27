using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

using UnityEngine;


namespace Lilium.ToonGraph.Runtime
{
    public class ToonOutlineRenderPass : ScriptableRenderPass
    {
        public static float alpha = 1;

        public static float fieldOfView = 2;

        RenderQueueType _renderQueueType;

        FilteringSettings _filteringSettings;

        string _profilerTag;
        
        ProfilingSampler _profilingSampler;

        List<ShaderTagId> _shaderTagIdList = new List<ShaderTagId>();

        RenderStateBlock _renderStateBlock;

        readonly GlobalKeyword _toonOutlineKeyword = GlobalKeyword.Create("_TOON_OUTLINE");

        readonly int _projectionParamsId = Shader.PropertyToID("_ProjectionParams");

        public ToonOutlineRenderPass (string profilerTag, RenderPassEvent renderPassEvent, string[] shaderTags, RenderQueueType renderQueueType, int layerMask)
        {
            base.profilingSampler = new ProfilingSampler(nameof(RenderObjectsPass));

            _profilerTag = profilerTag;
            this.renderPassEvent = renderPassEvent;
            this._renderQueueType = renderQueueType;
            RenderQueueRange renderQueueRange = (renderQueueType == RenderQueueType.Transparent)
                ? RenderQueueRange.transparent
                : RenderQueueRange.opaque;
            _filteringSettings = new FilteringSettings(renderQueueRange, layerMask);

            if (shaderTags != null && shaderTags.Length > 0)
            {
                foreach (var passName in shaderTags)
                    _shaderTagIdList.Add(new ShaderTagId(passName));
            }
            else
            {
                _shaderTagIdList.Add(new ShaderTagId("SRPDefaultUnlit"));
                _shaderTagIdList.Add(new ShaderTagId("UniversalForward"));
                _shaderTagIdList.Add(new ShaderTagId("UniversalForwardOnly"));
                _shaderTagIdList.Add(new ShaderTagId("LightweightForward"));
            }

            _renderStateBlock = new RenderStateBlock(RenderStateMask.Raster);
            _renderStateBlock.rasterState = new RasterState { cullingMode = CullMode.Front };
        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {

            bool isSceneViewCamera = renderingData.cameraData.isSceneViewCamera;

            SortingCriteria sortingCriteria = (_renderQueueType == RenderQueueType.Transparent)
                ? SortingCriteria.CommonTransparent
                : renderingData.cameraData.defaultOpaqueSortFlags;

            DrawingSettings drawingSettings = CreateDrawingSettings(_shaderTagIdList, ref renderingData, sortingCriteria);

            ref CameraData cameraData = ref renderingData.cameraData;
            Camera camera = cameraData.camera;
            var viewMatrixPrev = camera.worldToCameraMatrix;
            var projectionMatrixPrev = camera.projectionMatrix;

            // In case of camera stacking we need to take the viewport rect from base camera
            Rect pixelRect = camera.pixelRect; // = renderingData.cameraData.pixelRect;
            float cameraAspect = (float) pixelRect.width / (float) pixelRect.height;

            CommandBuffer cmd = CommandBufferPool.Get(_profilerTag);

            // メッシュ描画
            using (new ProfilingScope(cmd, _profilingSampler))
            {
                // メッシュ描画前
                if (!isSceneViewCamera)
                {
                    float fov = Mathf.Lerp( camera.fieldOfView, fieldOfView, alpha == 1 ? 1 : 0);
                    Matrix4x4 newProjectionMatrix = Matrix4x4.Perspective (fov, cameraAspect, camera.nearClipPlane, camera.farClipPlane);
                    Matrix4x4 viewMatrix = camera.worldToCameraMatrix;
                    Vector4 cameraTranslation = viewMatrix.GetColumn (3);
                    Vector3 cameraPosition = cameraTranslation;

                    float ratio = newProjectionMatrix[1, 1] / camera.projectionMatrix[1, 1];

                    Vector3 lookAtDirection = camera.transform.forward;
                    lookAtDirection.y = 0;
                    //  Debug.Log (lookAtDirection*100 + "  " + Vector3.forward*100);
                    Plane lookAtPlane = new Plane (Vector3.forward, Vector3.zero);
                    float lookAtLength = lookAtPlane.GetDistanceToPoint (cameraPosition);
                    Vector3 lookAtPosition = cameraPosition - (lookAtDirection * lookAtLength);

                    //Debug.Log (camera.projectionMatrix[1, 1] + " " + projectionMatrix[1, 1]);
                    Vector3 newCameraPosition = lookAtPosition + (lookAtDirection * lookAtLength * (ratio));

                    var depthShiftLength = (cameraPosition - newCameraPosition).magnitude;

                    viewMatrix.SetColumn(3, new Vector4(newCameraPosition.x, newCameraPosition.y, newCameraPosition.z, ratio) );

                    newProjectionMatrix = Matrix4x4.Perspective (fov, cameraAspect, camera.nearClipPlane, camera.farClipPlane);
                    newProjectionMatrix = GL.GetGPUProjectionMatrix(newProjectionMatrix, cameraData.IsCameraProjectionMatrixFlipped());
                    //RenderingUtils.SetViewAndProjectionMatrices(cmd, viewMatrix, newProjectionMatrix, true);
                    cmd.SetGlobalVector(_projectionParamsId, new Vector4(1, camera.nearClipPlane+depthShiftLength, camera.farClipPlane+depthShiftLength, 1.0f / (camera.farClipPlane+depthShiftLength)));

                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();
                }

                // keyword "_TOON_OUTLINE" 有効化
                cmd.SetKeyword(_toonOutlineKeyword, true);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                // メッシュ描画
                context.DrawRenderers(renderingData.cullResults, ref drawingSettings, ref _filteringSettings, ref _renderStateBlock);

                // keyword "_TOON_OUTLINE" 無効化
                cmd.SetKeyword(_toonOutlineKeyword, false);
                context.ExecuteCommandBuffer(cmd);
                cmd.Clear();

                // メッシュ描画後
                if (!isSceneViewCamera) {
                    // カメラをもとに戻す
                    RenderingUtils.SetViewAndProjectionMatrices(cmd, cameraData.GetViewMatrix(), cameraData.GetGPUProjectionMatrix(), false);          
                    context.ExecuteCommandBuffer(cmd);
                    cmd.Clear();

                }
            }

            CommandBufferPool.Release(cmd);
        }

        // レンダリング処理後に呼ばれる
        // レンダリング処理に使用したリソースを片づけたりする
        public override void FrameCleanup(CommandBuffer cmd)
        {

        }        
    }
}
