using System;
using System.Collections.Generic;
using UnityEngine;

namespace Lilium.ToonGraph.Runtime
{
    /// <summary>
    /// 点光源・スポットライトの光源の大きさ（半径）を、このライトだけプロジェクト設定の既定から変える。Lilium Toon のマテリアルだけに効く。
    /// URP の減衰は 1/d² で、光源の中心が面に近づくと際限なく明るくなって白飛びする。
    /// 光源を半径のある球として扱い、減衰を 1/(d²+r²) にして明るさを 1/r² で頭打ちにする。
    /// 半径と同じ距離で明るさは元の半分になり、離れるほど元の減衰に近づく。
    /// これが無いライトには <see cref="LiliumToonSettings.defaultLightSourceRadius"/> を使う。
    /// 半径の配列をシェーダーへ送るのは <see cref="ToonOutlineRenderFeature"/> のパス。
    /// </summary>
    [ExecuteAlways]
    [DisallowMultipleComponent]
    [RequireComponent(typeof(Light))]
    public class ToonLightSourceRadius : MonoBehaviour
    {
        [SerializeField, Min(0f)]
        [Tooltip("このライトの光源の半径（メートル）。プロジェクト設定（Lilium Toon）の既定の代わりに使う。これより近づいても明るさは増えない。0 で URP のまま 1/d²。小さすぎると頭打ちの明るさが高いままで白飛びが残る（0.3〜1 が目安）")]
        float m_Radius = 0.5f;

        /// <summary>光源の半径（メートル）</summary>
        public float radius
        {
            get => m_Radius;
            set
            {
                m_Radius = Mathf.Max(0f, value);
                if (isActiveAndEnabled)
                    Register();
            }
        }

        static readonly Dictionary<Light, float> s_Radii = new();

        Light m_Light;

        void OnEnable() => Register();

        void OnDisable()
        {
            if (m_Light != null)
                s_Radii.Remove(m_Light);
        }

        void OnValidate()
        {
            if (isActiveAndEnabled)
                Register();
        }

        void Register()
        {
            if (m_Light == null)
                m_Light = GetComponent<Light>();
            if (m_Light != null)
                s_Radii[m_Light] = m_Radius;
        }

        /// <summary>ライトの半径。部品が付いていない・無効なら既定の半径</summary>
        public static float GetRadius(Light light, float defaultRadius)
        {
            if (light == null)
                return 0f;
            return s_Radii.TryGetValue(light, out var r) ? r : defaultRadius;
        }

        /// <summary>
        /// URP が追加ライトを詰める順番（画面に映るライトの順・メインライトだけ飛ばす）で半径を並べる。
        /// シェーダーは GetAdditionalLight と同じ番号で読む。点光源・スポットライト以外は 0（方向光には掛けない）。
        /// </summary>
        public static void FillAdditionalLightRadii<T>(in T visibleLights, int mainLightIndex, float defaultRadius, float[] dst)
            where T : IVisibleLightList
        {
            Array.Clear(dst, 0, dst.Length);
            for (int i = 0, lightIter = 0; i < visibleLights.Count && lightIter < dst.Length; ++i)
            {
                if (i == mainLightIndex)
                    continue;

                var type = visibleLights.GetLightType(i);
                if (type == LightType.Point || type == LightType.Spot)
                    dst[lightIter] = GetRadius(visibleLights.GetLight(i), defaultRadius);
                lightIter++;
            }
        }

        /// <summary>画面に映るライトの一覧（URP の VisibleLight をテストから差し替えるため）</summary>
        public interface IVisibleLightList
        {
            int Count { get; }
            LightType GetLightType(int index);
            Light GetLight(int index);
        }
    }
}
