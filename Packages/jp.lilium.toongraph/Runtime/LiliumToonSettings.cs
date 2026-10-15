using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Categorization;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// Lilium Toon のプロジェクト全体の設定。Project Settings > Graphics > URP の「Lilium Toon」に出る。
/// URP のグローバル設定アセットに保存されるのでビルドにも入る。
/// </summary>
[Serializable]
[SupportedOnRenderPipeline(typeof(UniversalRenderPipelineAsset))]
[CategoryInfo(Name = "Lilium Toon", Order = 1000)]
public class LiliumToonSettings : IRenderPipelineGraphicsSettings
{
    [SerializeField, HideInInspector]
    int m_Version;

    public int version => m_Version;

    bool IRenderPipelineGraphicsSettings.isAvailableInPlayerBuild => true;

    [SerializeField, Range(0f, 1f)]
    [Tooltip("光が当たる側と影の境目。光と面の角度の cos(N・L) がこの値を超えると光が当たる。大きいほど浅い光が影になる（0.1 で約 6°、0.5 で約 30° より浅い光が影）")]
    float m_ShadeThreshold = 0.1f;

    [SerializeField, Range(0f, 1f)]
    [Tooltip("SSS（表面下散乱）が出る境目。大きいほど SSS の出る範囲が狭くなる")]
    float m_SubsurfaceThreshold = 0.5f;

    /// <summary>直接光の影の境目（ToonLighting.hlsl の _ToonShadeThreshold）</summary>
    public float shadeThreshold
    {
        get => m_ShadeThreshold;
        set => this.SetValueAndNotify(ref m_ShadeThreshold, value, nameof(m_ShadeThreshold));
    }

    /// <summary>SSS の境目（ToonLighting.hlsl の _ToonSubsurfaceThreshold）</summary>
    public float subsurfaceThreshold
    {
        get => m_SubsurfaceThreshold;
        set => this.SetValueAndNotify(ref m_SubsurfaceThreshold, value, nameof(m_SubsurfaceThreshold));
    }
}

/// <summary>
/// <see cref="LiliumToonSettings"/> の値をシェーダーのグローバルへ入れる。
/// 設定画面で変えた値がそのフレームから効くように、描画のたびに入れ直す。
/// </summary>
static class LiliumToonGlobals
{
    static readonly int s_ShadeThresholdId = Shader.PropertyToID("_ToonShadeThreshold");
    static readonly int s_SubsurfaceThresholdId = Shader.PropertyToID("_ToonSubsurfaceThreshold");

#if UNITY_EDITOR
    [UnityEditor.InitializeOnLoadMethod]
#endif
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
    static void Initialize()
    {
        RenderPipelineManager.beginContextRendering -= OnBeginContextRendering;
        RenderPipelineManager.beginContextRendering += OnBeginContextRendering;
        Apply();
    }

    static void OnBeginContextRendering(ScriptableRenderContext context, List<Camera> cameras) => Apply();

    static void Apply()
    {
        // 設定が無い（URP 以外・グローバル設定アセットが古い）ときも既定値を入れる。
        // グローバルが未設定だと 0 になり、すべての面が光の当たる側になってしまうため。
        var shade = 0.1f;
        var subsurface = 0.5f;
        if (GraphicsSettings.TryGetRenderPipelineSettings<LiliumToonSettings>(out var settings))
        {
            shade = settings.shadeThreshold;
            subsurface = settings.subsurfaceThreshold;
        }
        Shader.SetGlobalFloat(s_ShadeThresholdId, shade);
        Shader.SetGlobalFloat(s_SubsurfaceThresholdId, subsurface);
    }
}
