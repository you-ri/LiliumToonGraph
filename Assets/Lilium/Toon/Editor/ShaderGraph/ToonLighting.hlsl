//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
// referenced: MToon Copyright (c) 2018 Masataka SUMI https://github.com/Santarh/MToon
//
#ifndef UNIVERSAL_TOONLIGHTING_INCLUDED
#define UNIVERSAL_TOONLIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"



inline half3 lerp3(half3 one, half3 two, half3 three, float value)
{
    half3 v = lerp(two, three, max(value - 1, 0));
    v = lerp(one, v, min(value, 1));
    return v;
}

inline half lerpToony(half value, half shift, half toony)
{
    value = value * 2.0 - 1.0; // from [0, 1] to [-1, +1]
    value = smoothstep(shift, shift + (1.0 - toony), value); // shade & tooned
    return value;
}


inline half3 rgb2hsv(half3 c)
{
    half4 K = half4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    half4 p = lerp(half4(c.bg, K.wz), half4(c.gb, K.xy), step(c.b, c.g));
    half4 q = lerp(half4(p.xyw, c.r), half4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return half3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

inline half3 hsv2rgb(half3 c)
{
    half4 K = half4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    half3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

inline float3 TransformViewToProjection(float3 v) {
    return mul((float3x3)UNITY_MATRIX_P, v);
}

///////////////////////////////////////////////////////////////////////////////
//                         Toon BRDF Functions                                    //
///////////////////////////////////////////////////////////////////////////////
struct ToonBRDFData
{
    half3 diffuse;
    half3 specular;
    half perceptualRoughness;
    half roughness;
    half roughness2;
    half grazingTerm;

    // We save some light invariant BRDF terms so we don't have to recompute
    // them in the light loop. Take a look at DirectBRDF function for detailed explaination.
    half normalizationTerm; // roughness * 4.0 + 2.0
    half roughness2MinusOne; // roughness² - 1.0

    // toony extend
    half3 shade;  // 影色
    half3 base; // 基本色

    half shadeShift;
    half shadeToony;
};

inline void InitializeToonBRDFData(half3 albedo, half3 shade, half metallic, half3 specular, half smoothness, half alpha, half shadeShift, half shadeToony, half3 gi, out ToonBRDFData outBRDFData)
{
#ifdef _SPECULAR_SETUP
    half reflectivity = ReflectivitySpecular(specular);
    half oneMinusReflectivity = 1.0 - reflectivity;

    outBRDFData.diffuse = albedo * (half3(1.0h, 1.0h, 1.0h) - specular);
    outBRDFData.specular = specular;
#else

    half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
    half reflectivity = 1.0 - oneMinusReflectivity;

    outBRDFData.diffuse = albedo * oneMinusReflectivity;
    outBRDFData.specular = lerp(kDieletricSpec.rgb, albedo, metallic);
#endif

    outBRDFData.grazingTerm = saturate(smoothness + reflectivity);
    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
    outBRDFData.roughness = max(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness), HALF_MIN);
    outBRDFData.roughness2 = outBRDFData.roughness * outBRDFData.roughness;

    outBRDFData.normalizationTerm = outBRDFData.roughness * 4.0h + 2.0h;
    outBRDFData.roughness2MinusOne = outBRDFData.roughness2 - 1.0h;

    outBRDFData.base = albedo * (half3(1, 1, 1) - (shade * gi));
    outBRDFData.shade = shade;
    outBRDFData.shadeShift = (1 - shadeShift);
    outBRDFData.shadeToony = shadeToony;

#ifdef _ALPHAPREMULTIPLY_ON
    outBRDFData.diffuse *= alpha;
    alpha = alpha * oneMinusReflectivity + reflectivity;
#endif
}

// トーン階調で減衰した値を取り出す
inline half ToonyValue(ToonBRDFData brdfData, half value)
{
    //value = value * 2.0 - 1.0; // from [0, 1] to [-1, +1]
    value = smoothstep(brdfData.shadeShift, brdfData.shadeShift + (1.0 - brdfData.shadeToony), value); // shade & tooned
    return value;
}

// トーン階調で減衰した値を取り出す
inline float ToonyValue(ToonBRDFData brdfData, float value)
{
    //value = value * 2.0 - 1.0; // from [0, 1] to [-1, +1]
    value = smoothstep(brdfData.shadeShift, brdfData.shadeShift + (1.0 - brdfData.shadeToony), value); // shade & tooned
    return value;
}



half3 EnvironmentToon(ToonBRDFData brdfData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
{
    // アンビエントは影色と掛け合わせる
    half3 c = indirectDiffuse * brdfData.shade;
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    c += surfaceReduction * indirectSpecular  * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
    return c;
}




// Based on Minimalist CookTorrance BRDF
// Implementation is slightly different from original derivation: http://www.thetenthplanet.de/archives/255
//
// * NDF [Modified] GGX
// * Modified Kelemen and Szirmay-​Kalos for Visibility term
// * Fresnel approximated with 1/LdotH
half3 DirectToonBDRF(ToonBRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
{
#ifndef _SPECULARHIGHLIGHTS_OFF
    float3 halfDir = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));

    float NoH = saturate(dot(normalWS, halfDir));
    half LoH = saturate(dot(lightDirectionWS, halfDir));

    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // BRDFspec = (D * V * F) / 4.0
    // D = roughness² / ( NoH² * (roughness² - 1) + 1 )²
    // V * F = 1.0 / ( LoH² * (roughness + 0.5) )
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155

    // Final BRDFspec = roughness² / ( NoH² * (roughness² - 1) + 1 )² * (LoH² * (roughness + 0.5) * 4.0)
    // We further optimize a few light invariant terms
    // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

    float maxD = brdfData.roughness2MinusOne + 1.00001f;
    half maxSpecularTerm = brdfData.roughness2 / ((maxD * maxD) * brdfData.normalizationTerm);

    // Toony specular
    specularTerm = ToonyValue(brdfData, specularTerm / maxSpecularTerm) * maxSpecularTerm;

    // On platforms where half actually means something, the denominator has a risk of overflow
    // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
    // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
#if defined (SHADER_API_MOBILE) || defined (SHADER_API_SWITCH)
    specularTerm = specularTerm - HALF_MIN;
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif

    half3 color = specularTerm * brdfData.specular + brdfData.base;
    return color;
#else
    return brdfData.diffuse;
#endif

}



half3 GlossyEnvironmentReflectionToon(half3 reflectVector, half perceptualRoughness, half occlusion)
{
#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
    half mip = PerceptualRoughnessToMipmapLevel(1);     // 最大限に粗い反射環境マップを割り当てる
    half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, reflectVector, mip);

#if !defined(UNITY_USE_NATIVE_HDR)
    half3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
#else
    half3 irradiance = encodedIrradiance.rbg;
#endif

    return irradiance * occlusion;
#endif // GLOSSY_REFLECTIONS

    return _GlossyEnvironmentColor.rgb * occlusion;
}


half3 GlobalIlluminationToon(ToonBRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflectionToon(reflectVector, brdfData.perceptualRoughness, occlusion);

    return EnvironmentToon(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}


half3 LightingToonyBased(ToonBRDFData brdfData, Light light, InputData inputData, half3 normalWS, half3 viewDirectionWS)
{
    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
    half3 lightDirectionWS = light.direction;

    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half3 radiance = light.color * ToonyValue(brdfData, (lightAttenuation * NdotL));
    return DirectToonBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
}




///////////////////////////////////////////////////////////////////////////////
//                      Fragment Functions                                   //
//       Used by ShaderGraph and others builtin renderers                    //
///////////////////////////////////////////////////////////////////////////////
half4 UniversalFragmentToon(InputData inputData, half3 diffuse, half3 shade,
    half metallic, half3 specular, half occlusion, half smoothness, half3 emission, half alpha, half shadeShift, half shadeToony)
{
    BRDFData brdfData2;
    InitializeBRDFData(diffuse, metallic, specular, smoothness, alpha, brdfData2);

    ToonBRDFData brdfData;
    InitializeToonBRDFData(diffuse, shade, metallic, specular, smoothness, alpha, shadeShift, shadeToony, inputData.bakedGI, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIlluminationToon(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
    color += LightingToonyBased(brdfData, mainLight, inputData, inputData.normalWS, inputData.viewDirectionWS);

#ifdef _ADDITIONAL_LIGHTS
    int pixelLightCount = GetAdditionalLightsCount();
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, inputData.positionWS);
        color += LightingToonyBased(brdfData, light, inputData, inputData.normalWS, inputData.viewDirectionWS);
    }
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    color += inputData.vertexLighting * brdfData.diffuse;
#endif

    color += emission;
    return half4(color, alpha);
}

// GIの全天からの平均値を算出
// TODO: 高速化
#ifdef LIGHTMAP_ON
#define SAMPLE_OMNIDIRECTIONAL_GI(lmName, shName) SampleOminidirectionalLightmap(lmName)
#else
#define SAMPLE_OMNIDIRECTIONAL_GI(lmName, shName) SampleOmnidirectionalSHPixel(shName)
#endif

float3 SampleOminidirectionalLightmap(float2 lightmapUV)
{
    float3 gi = float3(0, 0, 0);

    gi += SampleLightmap(lightmapUV, half3(1, 0, 0));
    gi += SampleLightmap(lightmapUV, half3(-1, 0, 0));
    gi += SampleLightmap(lightmapUV, half3(0, 1, 0));
    gi += SampleLightmap(lightmapUV, half3(0, -1, 0));
    gi += SampleLightmap(lightmapUV, half3(0, 0, 1));
    gi += SampleLightmap(lightmapUV, half3(0, 0, -1));
    return gi / 6;
}

float3 SampleOmnidirectionalSHPixel(half3 vertexSH)
{
    float3 gi = float3(0, 0, 0);

    gi += SampleSHPixel(vertexSH, half3(1, 0, 0));
    gi += SampleSHPixel(vertexSH, half3(-1, 0, 0));
    gi += SampleSHPixel(vertexSH, half3(0, 1, 0));
    gi += SampleSHPixel(vertexSH, half3(0, -1, 0));
    gi += SampleSHPixel(vertexSH, half3(0, 0, 1));
    gi += SampleSHPixel(vertexSH, half3(0, 0, -1));
    return gi / 6;
}

///////////////////////////////////////////////////////////////////////////////

float4 TransformOutlineToHClipScreenSpace(float3 position, float3 normal, float outlineWidth)
{
    //float outlineTex = tex2Dlod(_OutlineWidthTexture, float4(TRANSFORM_TEX(v.texcoord, _MainTex), 0, 0)).r;
    half _OutlineScaledMaxDistance = 10;


    float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
    float aspect = abs(nearUpperRight.y / nearUpperRight.x);
    float4 vertex = TransformObjectToHClip(position);
    float3 viewNormal = mul((float3x3) UNITY_MATRIX_IT_MV, normal.xyz);
    float3 clipNormal = TransformViewToProjection(viewNormal.xyz);
    float2 projectedNormal = normalize(clipNormal.xy);
    projectedNormal *= min(vertex.w, _OutlineScaledMaxDistance);
    projectedNormal.x *= aspect;
    vertex.xy += 0.01 * outlineWidth * projectedNormal.xy;

    // 少し奥方向に移動しないとアーティファクトが発生することがある
    //vertex.z += -0.00002 / vertex.w;
    return vertex;
}

float4 TransformOutlineToHClipWorldSpace(float3 vertex, float3 normal, half outlineWidth)
{
    float3 worldNormalLength = length(mul((float3x3) transpose(unity_WorldToObject), normal));
    float3 outlineOffset = 0.01 * outlineWidth * worldNormalLength * normal;
    return TransformObjectToHClip(vertex + outlineOffset);
}

#endif
