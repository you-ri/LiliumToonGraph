using System.Collections.Generic;
using NUnit.Framework;
using UnityEngine;
using Lilium.ToonGraph.Runtime;

namespace Lilium.ToonGraph.Tests.Editor
{
    public class ToonLightSourceRadiusTests
    {
        const float k_Default = 0.5f;

        readonly List<GameObject> _created = new();

        [TearDown]
        public void TearDown()
        {
            foreach (var go in _created)
                if (go != null)
                    Object.DestroyImmediate(go);
            _created.Clear();
        }

        Light CreateLight(LightType type)
        {
            var go = new GameObject("TestLight");
            _created.Add(go);
            var light = go.AddComponent<Light>();
            light.type = type;
            return light;
        }

        Light CreateLightWithRadius(LightType type, float radius)
        {
            var light = CreateLight(type);
            light.gameObject.AddComponent<ToonLightSourceRadius>().radius = radius;
            return light;
        }

        // テスト用の画面に映るライトの一覧（URP の VisibleLight の代わり）
        readonly struct FakeVisibleLights : ToonLightSourceRadius.IVisibleLightList
        {
            readonly Light[] _lights;
            readonly LightType[] _types;

            public FakeVisibleLights(params Light[] lights)
            {
                _lights = lights;
                _types = new LightType[lights.Length];
                for (int i = 0; i < lights.Length; i++)
                    _types[i] = lights[i].type;
            }

            public FakeVisibleLights(Light[] lights, LightType[] types)
            {
                _lights = lights;
                _types = types;
            }

            public int Count => _lights.Length;
            public LightType GetLightType(int index) => _types[index];
            public Light GetLight(int index) => _lights[index];
        }

        [Test]
        public void GetRadius_NullLight_ReturnsZero()
        {
            Assert.That(ToonLightSourceRadius.GetRadius(null, k_Default), Is.EqualTo(0f));
        }

        [Test]
        public void GetRadius_WithoutComponent_ReturnsDefault()
        {
            var light = CreateLight(LightType.Point);
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(k_Default));
        }

        [Test]
        public void GetRadius_WithComponent_ReturnsComponentRadius()
        {
            var light = CreateLightWithRadius(LightType.Point, 1.25f);
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(1.25f));
        }

        [Test]
        public void GetRadius_ComponentRadiusZero_ReturnsZero()
        {
            // 0 はそのライトだけ URP のまま 1/d²。既定に戻してはいけない
            var light = CreateLightWithRadius(LightType.Point, 0f);
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(0f));
        }

        [Test]
        public void GetRadius_ComponentDisabled_ReturnsDefault()
        {
            var light = CreateLightWithRadius(LightType.Point, 1.25f);
            light.GetComponent<ToonLightSourceRadius>().enabled = false;
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(k_Default));
        }

        [Test]
        public void GetRadius_ComponentReEnabled_ReturnsComponentRadius()
        {
            var light = CreateLightWithRadius(LightType.Point, 1.25f);
            var component = light.GetComponent<ToonLightSourceRadius>();
            component.enabled = false;
            component.enabled = true;
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(1.25f));
        }

        [Test]
        public void GetRadius_ComponentDestroyed_ReturnsDefault()
        {
            var light = CreateLightWithRadius(LightType.Point, 1.25f);
            Object.DestroyImmediate(light.GetComponent<ToonLightSourceRadius>());
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(k_Default));
        }

        [Test]
        public void Radius_SetWhileEnabled_UpdatesImmediately()
        {
            var light = CreateLightWithRadius(LightType.Point, 1.25f);
            light.GetComponent<ToonLightSourceRadius>().radius = 2f;
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(2f));
        }

        [Test]
        public void Radius_SetWhileDisabled_AppliesOnEnable()
        {
            var light = CreateLightWithRadius(LightType.Point, 1.25f);
            var component = light.GetComponent<ToonLightSourceRadius>();
            component.enabled = false;
            component.radius = 2f;
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(k_Default));

            component.enabled = true;
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(2f));
        }

        [Test]
        public void Radius_Negative_ClampedToZero()
        {
            var light = CreateLightWithRadius(LightType.Point, -1f);
            Assert.That(light.GetComponent<ToonLightSourceRadius>().radius, Is.EqualTo(0f));
            Assert.That(ToonLightSourceRadius.GetRadius(light, k_Default), Is.EqualTo(0f));
        }

        [Test]
        public void Fill_SkipsMainLightAndKeepsAdditionalLightOrder()
        {
            var main = CreateLight(LightType.Directional);
            var pointWithRadius = CreateLightWithRadius(LightType.Point, 1.25f);
            var spot = CreateLight(LightType.Spot);
            var pointNoRadius = CreateLight(LightType.Point);
            var dst = new float[8];

            ToonLightSourceRadius.FillAdditionalLightRadii(
                new FakeVisibleLights(main, pointWithRadius, spot, pointNoRadius), 0, k_Default, dst);

            Assert.That(dst, Is.EqualTo(new[] { 1.25f, k_Default, k_Default, 0f, 0f, 0f, 0f, 0f }));
        }

        [Test]
        public void Fill_MainLightInMiddle_IsSkipped()
        {
            var point0 = CreateLightWithRadius(LightType.Point, 1f);
            var main = CreateLight(LightType.Directional);
            var point1 = CreateLightWithRadius(LightType.Point, 2f);
            var dst = new float[4];

            ToonLightSourceRadius.FillAdditionalLightRadii(new FakeVisibleLights(point0, main, point1), 1, k_Default, dst);

            Assert.That(dst, Is.EqualTo(new[] { 1f, 2f, 0f, 0f }));
        }

        [Test]
        public void Fill_NoMainLight_NothingSkipped()
        {
            var point0 = CreateLightWithRadius(LightType.Point, 1f);
            var point1 = CreateLightWithRadius(LightType.Point, 2f);
            var dst = new float[4];

            ToonLightSourceRadius.FillAdditionalLightRadii(new FakeVisibleLights(point0, point1), -1, k_Default, dst);

            Assert.That(dst, Is.EqualTo(new[] { 1f, 2f, 0f, 0f }));
        }

        [Test]
        public void Fill_NonPunctualLights_TakeSlotWithZero()
        {
            // 方向光・エリアライトにも追加ライトの番号は振られるので、詰めずに 0 で埋める
            var main = CreateLight(LightType.Directional);
            var directional = CreateLightWithRadius(LightType.Directional, 3f);
            var area = CreateLight(LightType.Rectangle);
            var point = CreateLightWithRadius(LightType.Point, 1f);
            var dst = new float[4];

            ToonLightSourceRadius.FillAdditionalLightRadii(
                new FakeVisibleLights(main, directional, area, point), 0, k_Default, dst);

            Assert.That(dst, Is.EqualTo(new[] { 0f, 0f, 1f, 0f }));
        }

        [Test]
        public void Fill_ClearsPreviousValues()
        {
            // 前のカメラの値を残さない
            var main = CreateLight(LightType.Directional);
            var point = CreateLightWithRadius(LightType.Point, 1f);
            var dst = new[] { 9f, 9f, 9f, 9f };

            ToonLightSourceRadius.FillAdditionalLightRadii(new FakeVisibleLights(main, point), 0, k_Default, dst);

            Assert.That(dst, Is.EqualTo(new[] { 1f, 0f, 0f, 0f }));
        }

        [Test]
        public void Fill_MoreLightsThanDestination_Truncates()
        {
            var lights = new[]
            {
                CreateLightWithRadius(LightType.Point, 1f),
                CreateLightWithRadius(LightType.Point, 2f),
                CreateLightWithRadius(LightType.Point, 3f),
                CreateLightWithRadius(LightType.Point, 4f),
            };
            var dst = new float[2];

            Assert.DoesNotThrow(() =>
                ToonLightSourceRadius.FillAdditionalLightRadii(new FakeVisibleLights(lights), -1, k_Default, dst));
            Assert.That(dst, Is.EqualTo(new[] { 1f, 2f }));
        }

        [Test]
        public void Fill_NullLightOfPointType_IsZero()
        {
            var main = CreateLight(LightType.Directional);
            var lights = new FakeVisibleLights(new[] { main, null }, new[] { LightType.Directional, LightType.Point });
            var dst = new float[2];

            ToonLightSourceRadius.FillAdditionalLightRadii(lights, 0, k_Default, dst);

            Assert.That(dst, Is.EqualTo(new[] { 0f, 0f }));
        }

        [Test]
        public void Fill_EmptyList_AllZero()
        {
            var dst = new[] { 9f, 9f };

            ToonLightSourceRadius.FillAdditionalLightRadii(new FakeVisibleLights(new Light[0]), -1, k_Default, dst);

            Assert.That(dst, Is.EqualTo(new[] { 0f, 0f }));
        }
    }
}
