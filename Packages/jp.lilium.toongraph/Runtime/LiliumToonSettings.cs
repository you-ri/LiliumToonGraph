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

    [SerializeField]
    [Tooltip("影の階調を決めるトゥーンランプ（横 = N・L + 影マップのずれ（-1〜1）、縦 = 段階の種類、R = 直接光の強さ、G = 環境光とメインライト（SSS）の倍率。sRGB オフ・Clamp）。使うのは _TOON_SHADE_SHIFT のシェーダー（パレット形式）だけで、光と影の境目もこの絵で決まる")]
    Texture2D m_ToonRamp;

    [SerializeField, Range(0f, 1f)]
    [Tooltip("SSS（表面下散乱）が出る境目。大きいほど SSS の出る範囲が狭くなる")]
    float m_SubsurfaceThreshold = 0.5f;

    [SerializeField]
    [Tooltip("点光源・スポットライトを半径のある球として扱い、近づいても明るさが頭打ちになるようにする。切ると全ライトが URP のまま 1/d²（Toon Light Source Radius を付けたライトも）")]
    bool m_LightSourceRadiusEnabled = true;

    [SerializeField, Min(0f)]
    [Tooltip("点光源・スポットライトの光源の半径（メートル）の既定。これより近づいても明るさは増えない（0 で URP のまま 1/d²）。ライトごとに変えるには Toon Light Source Radius を付ける")]
    float m_DefaultLightSourceRadius = 0.5f;

    /// <summary>直接光の影の境目（ToonLighting.hlsl の _ToonShadeThreshold）</summary>
    public float shadeThreshold
    {
        get => m_ShadeThreshold;
        set => this.SetValueAndNotify(ref m_ShadeThreshold, value, nameof(m_ShadeThreshold));
    }

    /// <summary>トゥーンランプ（ToonLighting.hlsl の _ToonRamp）</summary>
    public Texture2D toonRamp
    {
        get => m_ToonRamp;
        set => this.SetValueAndNotify(ref m_ToonRamp, value, nameof(m_ToonRamp));
    }

    /// <summary>SSS の境目（ToonLighting.hlsl の _ToonSubsurfaceThreshold）</summary>
    public float subsurfaceThreshold
    {
        get => m_SubsurfaceThreshold;
        set => this.SetValueAndNotify(ref m_SubsurfaceThreshold, value, nameof(m_SubsurfaceThreshold));
    }

    /// <summary>点光源・スポットライトの光源の半径を使うか</summary>
    public bool lightSourceRadiusEnabled
    {
        get => m_LightSourceRadiusEnabled;
        set => this.SetValueAndNotify(ref m_LightSourceRadiusEnabled, value, nameof(m_LightSourceRadiusEnabled));
    }

    /// <summary>点光源・スポットライトの光源の半径の既定（Toon Light Source Radius が無いライトに使う）</summary>
    public float defaultLightSourceRadius
    {
        get => m_DefaultLightSourceRadius;
        set => this.SetValueAndNotify(ref m_DefaultLightSourceRadius, Mathf.Max(0f, value), nameof(m_DefaultLightSourceRadius));
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
    static readonly int s_ToonRampId = Shader.PropertyToID("_ToonRamp");

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
        // ランプが無いときは灰色（全面が同じ明るさ）。白だと影が消えたことに気づきにくい
        Texture ramp = Texture2D.grayTexture;
        if (GraphicsSettings.TryGetRenderPipelineSettings<LiliumToonSettings>(out var settings))
        {
            shade = settings.shadeThreshold;
            subsurface = settings.subsurfaceThreshold;
            if (settings.toonRamp != null)
                ramp = settings.toonRamp;
        }
        Shader.SetGlobalFloat(s_ShadeThresholdId, shade);
        Shader.SetGlobalFloat(s_SubsurfaceThresholdId, subsurface);
        Shader.SetGlobalTexture(s_ToonRampId, ramp);
    }
}
