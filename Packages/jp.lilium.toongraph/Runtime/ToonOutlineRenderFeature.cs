using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

using UnityEngine;

namespace Lilium.ToonGraph.Runtime
{
    public class ToonOutlineRenderFeature : ScriptableRendererFeature
    {

        [System.Serializable]
        public class RenderObjectsSettings
        {
            public string passTag = "ToonOutlineFeature";
            public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;

            public FilterSettings filterSettings = new FilterSettings();
        }

        [System.Serializable]
        public class FilterSettings
        {
            // TODO: expose opaque, transparent, all ranges as drop down
            public RenderQueueType RenderQueueType;
            public LayerMask LayerMask;
            public string[] PassNames;

            public FilterSettings()
            {
                RenderQueueType = RenderQueueType.Opaque;
                LayerMask = 0;
            }
        }



        public RenderObjectsSettings settings = new RenderObjectsSettings();

        ToonOutlineRenderPass renderObjectsPass;

        public override void Create()
        {
            FilterSettings filter = settings.filterSettings;
            renderObjectsPass = new ToonOutlineRenderPass(settings.passTag, settings.Event, filter.PassNames,
                filter.RenderQueueType, filter.LayerMask);
        }

        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            renderer.EnqueuePass(renderObjectsPass);
        }
    }
}

