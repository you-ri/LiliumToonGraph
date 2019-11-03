//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
// referenced: MToon Copyright (c) 2018 Masataka SUMI https://github.com/Santarh/MToon
//
#ifndef UNIVERSAL_TOONLIGHTING2_INCLUDED
#define UNIVERSAL_TOONLIGHTING2_INCLUDED

#if !SHADERGRAPH_PREVIEW

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


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

inline float3 TransformViewToProjection(float3 v)
{
    return mul((float3x3) UNITY_MATRIX_P, v);
}

///////////////////////////////////////////////////////////////////////////////

// GI全天球から均一な値を算出
// TODO: 現状は６方向の平均値をしている。擬似的。
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


///////////////////////////////////////////////////////////////////////////////
//                         Toon BRDF Functions                                    //
///////////////////////////////////////////////////////////////////////////////
#define kDieletricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)

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
    half3 shade; // 影色
    half3 base; // 基本色
    half occlusion;

    half shadeShift;
    half shadeToony;
};


inline void InitializeToonBRDFData(half3 albedo, half3 shade, half metallic, half3 specular, half smoothness, half alpha, half occlusion, half shadeShift, half shadeToony, half3 giColor, out ToonBRDFData outBRDFData)
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

    // Toony Paramaters
    half giLighing = giColor;
    outBRDFData.base = albedo * (half3(1, 1, 1) - (shade * giColor)) * oneMinusReflectivity; // shade から base への色差分
    outBRDFData.shade = shade * oneMinusReflectivity;
    outBRDFData.occlusion = occlusion;
    outBRDFData.shadeToony = (1 - shadeToony);
    outBRDFData.shadeShift = (1 - shadeShift); //  -(outBRDFData.shadeToony / 2);


#ifdef _ALPHAPREMULTIPLY_ON
    outBRDFData.diffuse *= alpha;
    alpha = alpha * oneMinusReflectivity + reflectivity;
#endif
}
/*
inline void InitializeBRDFData(half3 albedo, half metallic, half3 specular, half smoothness, half alpha, out BRDFData outBRDFData)
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

#ifdef _ALPHAPREMULTIPLY_ON
    outBRDFData.diffuse *= alpha;
    alpha = alpha * oneMinusReflectivity + reflectivity;
#endif
}
*/


// トーン調に変換した値を取り出す
inline half ToonyValue(ToonBRDFData brdfData, half value, half maxValue = 1)
{
    return smoothstep(0.5 - brdfData.shadeToony / 2, 0.5 + brdfData.shadeToony / 2, value / maxValue) * maxValue;
//    return smoothstep(0.5 - brdfData.shadeToony / 2, 0.5 + brdfData.shadeToony / 2, value);
}

inline float ToonyValue(ToonBRDFData brdfData, float value, float maxValue = 1)
{
    return smoothstep(0.5 - brdfData.shadeToony / 2, 0.5 + brdfData.shadeToony / 2, value / maxValue) * maxValue;
//    return smoothstep(0.5 - brdfData.shadeToony / 2, 0.5 + brdfData.shadeToony / 2, value);
}

// トーン調に変換した値を取り出す（影色用）
inline half ToonyShadeValue(ToonBRDFData brdfData, half value, half maxValue = 1)
{
    return smoothstep(max(brdfData.shadeShift, 0), min(brdfData.shadeShift + brdfData.shadeToony, 1), value / maxValue) * maxValue;
}


half3 EnvironmentToon(ToonBRDFData brdfData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
{
    // アンビエントは影色と掛け合わせる
    half3 c = indirectDiffuse * brdfData.shade;
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    c += surfaceReduction * indirectSpecular * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
    return c;
}
/*
half3 EnvironmentBRDF(BRDFData brdfData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
{
    half3 c = indirectDiffuse * brdfData.diffuse;
    float surfaceReduction = 1.0 / (brdfData.roughness2 + 1.0);
    c += surfaceReduction * indirectSpecular * lerp(brdfData.specular, brdfData.grazingTerm, fresnelTerm);
    return c;
}
*/


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

    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

    // Toony specular
    float maxD = 1 * brdfData.roughness2MinusOne + 1.00001f;
    half maxSpecularTerm = brdfData.roughness2 / ((maxD * maxD) * max(0.1h, 1) * brdfData.normalizationTerm);
    specularTerm = ToonyValue(brdfData, specularTerm, maxSpecularTerm);

#if defined (SHADER_API_MOBILE) || defined (SHADER_API_SWITCH)
    specularTerm = specularTerm - HALF_MIN;
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif

    half3 color = specularTerm * brdfData.specular + brdfData.base;
    return color;
#else
    return brdfData.base;
#endif

}

/*
half3 DirectBDRF(BRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
{
#ifndef _SPECULARHIGHLIGHTS_OFF
    float3 halfDir = SafeNormalize(float3(lightDirectionWS) + float3(viewDirectionWS));

    float NoH = saturate(dot(normalWS, halfDir));
    half LoH = saturate(dot(lightDirectionWS, halfDir));

    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

#if defined (SHADER_API_MOBILE) || defined (SHADER_API_SWITCH)
    specularTerm = specularTerm - HALF_MIN;
    specularTerm = clamp(specularTerm, 0.0, 100.0); // Prevent FP16 overflow on mobiles
#endif

    half3 color = specularTerm * brdfData.specular + brdfData.diffuse;
    return color;
#else
    return brdfData.diffuse;
#endif
}
*/


half3 GlossyEnvironmentReflectionToon(half3 reflectVector, half perceptualRoughness, half occlusion)
{
#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
    half mip = PerceptualRoughnessToMipmapLevel(1); // 最大限に粗い反射環境マップを割り当てる
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
/*
half3 GlossyEnvironmentReflection(half3 reflectVector, half perceptualRoughness, half occlusion)
{
#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
    half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
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
*/

half3 GlobalIlluminationToon(ToonBRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    // toony fresnel
    fresnelTerm = ToonyValue(brdfData, fresnelTerm);

    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflectionToon(reflectVector, brdfData.perceptualRoughness, occlusion);

    return EnvironmentToon(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}
/*
half3 GlobalIllumination(BRDFData brdfData, half3 bakedGI, half occlusion, half3 normalWS, half3 viewDirectionWS)
{
    half3 reflectVector = reflect(-viewDirectionWS, normalWS);
    half fresnelTerm = Pow4(1.0 - saturate(dot(normalWS, viewDirectionWS)));

    half3 indirectDiffuse = bakedGI * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflection(reflectVector, brdfData.perceptualRoughness, occlusion);

    return EnvironmentBRDF(brdfData, indirectDiffuse, indirectSpecular, fresnelTerm);
}
*/


half3 LightingToonyBased(ToonBRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS)
{
    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half3 radiance = lightColor * lightAttenuation * ToonyShadeValue(brdfData, (NdotL));
    return DirectToonBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;
}

half3 LightingToonyBased(ToonBRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS)
{
    return LightingToonyBased(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS);
}


/*
half3 LightingPhysicallyBased(BRDFData brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS)
{
    half NdotL = saturate(dot(normalWS, lightDirectionWS));
    half3 radiance = lightColor * (lightAttenuation * NdotL);
    return DirectBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS) * radiance;


half3 LightingPhysicallyBased(BRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS)
{
    return LightingPhysicallyBased(brdfData, light.color, light.direction, light.distanceAttenuation * light.shadowAttenuation, normalWS, viewDirectionWS);
}
*/





///////////////////////////////////////////////////////////////////////////////
//                      Fragment Functions                                   //
//       Used by ShaderGraph and others builtin renderers                    //
///////////////////////////////////////////////////////////////////////////////
half4 UniversalFragmentToon(InputData inputData, half3 diffuse, half3 shade,
    half metallic, half3 specular, half occlusion, half smoothness, half3 emission, half alpha, half shadeShift, half shadeToony, half toonyLighing)
{
    ToonBRDFData brdfData;
    InitializeToonBRDFData(diffuse, shade, metallic, specular, smoothness, alpha, occlusion, shadeShift, shadeToony, inputData.bakedGI, brdfData);
    
    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIlluminationToon(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
    color += LightingToonyBased(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS);

#ifdef _ADDITIONAL_LIGHTS
    int pixelLightCount = GetAdditionalLightsCount();
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, inputData.positionWS);
        color += LightingToonyBased(brdfData, light, inputData.normalWS, inputData.viewDirectionWS);
    }
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    color += inputData.vertexLighting * brdfData.base;
#endif
    color += emission;
    return half4(color, alpha);
}


void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView, half3 BakedGI,
    half3 Diffuse, half3 Shade, half3 Normal, half Metalic, half Smoothness, half Occlusion, half3 Emmision,
    half ShadeShift, half ShadeToony,
    out half3 Color)
{
    InputData inputData;
    inputData.positionWS = WorldPosition;
    inputData.normalWS = TransformTangentToWorld(Normal, half3x3(WorldTangent.xyz, WorldBitangent.xyz, WorldNormal.xyz));
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = SafeNormalize(WorldView);
    inputData.fogCoord = 0;
    inputData.vertexLighting = 0;
    inputData.bakedGI = BakedGI;

#if SHADOWS_SCREEN
   half4 clipPos = TransformWorldToHClip(WorldPosition);
   inputData.shadowCoord = ComputeScreenPos(clipPos);
#else
    inputData.shadowCoord = TransformWorldToShadowCoord(WorldPosition);
#endif
//    inputData.shadowCoord = GetShadowCoord(GetVertexPositionInputs(ObjectPosition));

    Color = UniversalFragmentToon(inputData, Diffuse, Shade, Metalic, 0, Occlusion, Smoothness, Emmision, 1, ShadeShift, ShadeToony, 1).rgb;
}
/*
void BuildInputData(Varyings input, float3 normal, out InputData inputData)
{
    inputData.positionWS = input.positionWS;
#ifdef _NORMALMAP
    inputData.normalWS = TransformTangentToWorld(normal,
        half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
#else
    inputData.normalWS = input.normalWS;
#endif
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = SafeNormalize(input.viewDirectionWS);
    inputData.shadowCoord = input.shadowCoord;
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.sh, inputData.normalWS);
}
*/


#else


void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView, half3 BakedGI,
    half3 Diffuse, half3 Shade, half3 Normal, half Metalic, half Smoothness, half Occlusion, half3 Emmision,
    half ShadeShift, half ShadeToony,
    out half3 Color)
{
    Color = Diffuse;
}


#endif




#endif
