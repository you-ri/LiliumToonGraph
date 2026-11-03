using System.Reflection;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.Rendering;

namespace Lilium.ToonGraph.Tests.Editor
{
    public class LiliumToonSettingsTests
    {
        [Test]
        public void Defaults()
        {
            // LiliumToonGlobals / ToonOutlineRenderFeature の「設定が無いときの既定値」と揃えておくこと
            var settings = new LiliumToonSettings();
            Assert.That(settings.shadeThreshold, Is.EqualTo(0.1f));
            Assert.That(settings.subsurfaceThreshold, Is.EqualTo(0.5f));
            Assert.That(settings.toonRamp, Is.Null);
            Assert.That(settings.lightSourceRadiusEnabled, Is.True);
            Assert.That(settings.defaultLightSourceRadius, Is.EqualTo(0.5f));
        }

        [Test]
        public void DefaultLightSourceRadius_Negative_ClampedToZero()
        {
            var settings = new LiliumToonSettings();
            settings.defaultLightSourceRadius = -1f;
            Assert.That(settings.defaultLightSourceRadius, Is.EqualTo(0f));
        }

        [Test]
        public void Globals_ReflectProjectSettings()
        {
            Assume.That(GraphicsSettings.TryGetRenderPipelineSettings<LiliumToonSettings>(out var settings),
                "URP のグローバル設定に Lilium Toon が無い");

            // LiliumToonGlobals は internal なので反射で呼ぶ。設定は読むだけで書き換えない
            var globals = typeof(LiliumToonSettings).Assembly.GetType("LiliumToonGlobals", true);
            globals.GetMethod("Apply", BindingFlags.Static | BindingFlags.NonPublic).Invoke(null, null);

            Assert.That(Shader.GetGlobalFloat("_ToonShadeThreshold"), Is.EqualTo(settings.shadeThreshold));
            Assert.That(Shader.GetGlobalFloat("_ToonSubsurfaceThreshold"), Is.EqualTo(settings.subsurfaceThreshold));
            // ランプが未設定なら灰色（白だと影が消えたことに気づきにくい）
            Texture expectedRamp = settings.toonRamp != null ? settings.toonRamp : Texture2D.grayTexture;
            Assert.That(Shader.GetGlobalTexture("_ToonRamp"), Is.EqualTo(expectedRamp));
        }
    }
}
