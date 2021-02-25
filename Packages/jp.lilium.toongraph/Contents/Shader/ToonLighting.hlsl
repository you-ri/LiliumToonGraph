//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
//
#ifndef UNIVERSAL_TOONLIGHTING2_INCLUDED
#define UNIVERSAL_TOONLIGHTING2_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


//TODO: delete
float __ToonyLighting = 0;


SamplerState sampler_LinearClamp
{
    Filter = MIN_MAG_MIP_LINEAR;
    AddressU = Clamp; // of Mirror of Clamp of Border
    AddressV = Clamp; // of Mirror of Clamp of Border
};


inline half3 CameraDirectionWS()
{
    return mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz);
}   

inline half ToonyValue(half value, half oneMinusShadeToony, half threshold = 0.5h)
{
  return 
    lerp(
      value, 
      smoothstep(
        threshold - (oneMinusShadeToony/2), 
        threshold + (oneMinusShadeToony/2), 
        value),
      __ToonyLighting);
}




inline half binarize(half value, half threshold = 0.5h, half minValue = 0, half maxValue = 1)
{
    half toonyValue = smoothstep(threshold, threshold, value);
    toonyValue = clamp(toonyValue, minValue, maxValue);

    return lerp( value, toonyValue, __ToonyLighting);
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

    // toon extend
    half3 base;
    half occlusion;

    half shadow;
    half shadeShift;            // shade shift value -2 ~ 2 default(0)
    half shadeToony;
    half toonyLighting;
#ifdef SHADEMODEL_RAMP    
    Texture2D shadeRamp;
#endif

    // sss extend
    half3 sss;
    half subsurface;
    half curvature;
};

inline void InitializeToonBRDFData(
    half3 albedo, half3 sss, half metallic, half3 specular, half smoothness, half alpha, half occlusion, 
    half shade, half shadeToony, float toonyLighting, Texture2D shadeRamp, half curvature,
    out ToonBRDFData outBRDFData)
{
#ifdef _SPECULAR_SETUP
    half reflectivity = ReflectivitySpecular(specular);
    half oneMinusReflectivity = 1.0 - reflectivity;

    // SpecluarSetup時は非PBRベース
    outBRDFData.diffuse = albedo; //  * (half3(1.0h, 1.0h, 1.0h) - specular);
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

    // Toon Parameters
    outBRDFData.base = outBRDFData.diffuse; // albedo
    outBRDFData.sss = sss.rgb;
    outBRDFData.subsurface = 1;
    outBRDFData.occlusion = occlusion;
    outBRDFData.curvature = curvature;
    outBRDFData.shadow = 1;
    outBRDFData.shadeToony = (1 - shadeToony);
    outBRDFData.shadeShift = shade*2 - 2;           // 0 ~ 2 default(1) > -2 ~ 2 default(0)
    outBRDFData.toonyLighting = toonyLighting;

#ifdef SHADEMODEL_RAMP
    outBRDFData.shadeRamp = shadeRamp;
#endif

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

// Convert toony value (specular use)
inline half ToonyValue(ToonBRDFData brdfData, half value, half maxValue = 1, half threshold = 0.5h)
{
    return lerp(value, smoothstep((threshold / maxValue) - brdfData.shadeToony / 2, (threshold / maxValue) + brdfData.shadeToony / 2, value / maxValue) * maxValue, brdfData.toonyLighting);
}

inline half3 ToonyValue(ToonBRDFData brdfData, half3 value, half3 maxValue = 1, half threshold = 0.5f)
{
    return lerp(value, smoothstep((threshold / maxValue) - brdfData.shadeToony / 2, (threshold / maxValue) + brdfData.shadeToony / 2, value / maxValue) * maxValue, brdfData.toonyLighting);
}


inline float ToonyValue(ToonBRDFData brdfData, float value, float maxValue = 1, half threshold = 0.5h)
{
    return lerp(value, smoothstep((threshold / maxValue) - brdfData.shadeToony / 2, (threshold / maxValue) + brdfData.shadeToony / 2, value / maxValue) * maxValue, brdfData.toonyLighting);
}


inline half3 ToonyShadeValue(ToonBRDFData brdfData, half value)
{
    half shadeShift = brdfData.shadeShift;
    half normalizedValue = saturate((value + shadeShift + 1) / 2); // -1 ~ 1 -> 0 ~ 1
#ifdef SHADEMODEL_RAMP
    half3 toonedValue = SAMPLE_TEXTURE2D_LOD(brdfData.shadeRamp, sampler_LinearClamp, half2(normalizedValue, brdfData.shadeToony), 0);
#else
    /// 微小な数字を足して少しでも差を持たせないと smoothstep が不完全になる
    half3 toonedValue = smoothstep(0.5, brdfData.shadeToony + 0.500001f, normalizedValue);
#endif
    return lerp((half3) value, toonedValue, brdfData.toonyLighting);
}


half3 EnvironmentToon(ToonBRDFData brdfData, half3 indirectDiffuse, half3 indirectSpecular, half fresnelTerm)
{
    half3 c = indirectDiffuse * brdfData.diffuse;

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
half3 DirectToonBDRF(ToonBRDFData brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS, half3 radiance)
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

    // Toony specular with radiance
    // TODO: 最適化
    float maxD = 1 * brdfData.roughness2MinusOne + 1.00001f;
    half maxSpecularTerm = brdfData.roughness2 / ((maxD * maxD) * max(0.1h, 1) * brdfData.normalizationTerm);
    half radiancePower = length(radiance);
    half specularTermWithRadiance = ToonyValue(brdfData, specularTerm*radiancePower, maxSpecularTerm*radiancePower, 4); //TODO: 閾値を4に決め打ちしているが調整する方法が必要

    half3 color = (specularTermWithRadiance * SafeNormalize(radiance) * brdfData.specular) + (brdfData.diffuse * radiance);
    return color;
#else
    return brdfData.diffuse * radiance;
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


half3 GlossyEnvironmentReflectionToon(half3 reflectVector, half perceptualRoughness, half occlusion, half3 viewDirectionWS)
{
#if !defined(_ENVIRONMENTREFLECTIONS_OFF)
    half mip = PerceptualRoughnessToMipmapLevel(lerp(perceptualRoughness, 1, __ToonyLighting)); // トゥーンの場合最大限に粗い反射環境マップを割り当てる

    float3 cameraDirectionWS = mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz); // TODO: 最適化
    half4 encodedIrradiance = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0, samplerunity_SpecCube0, lerp(reflectVector, cameraDirectionWS, __ToonyLighting), mip); // トゥーンの場合サンプリングをカメラの向いている方向に固定する

#if !defined(UNITY_USE_NATIVE_HDR)
    half3 irradiance = DecodeHDREnvironment(encodedIrradiance, unity_SpecCube0_HDR);
#else
    half3 irradiance = encodedIrradiance.rgb;
#endif

    return irradiance;// * occlusion;
#endif // GLOSSY_REFLECTIONS

    return _GlossyEnvironmentColor.rgb;// * occlusion;
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
    half3 irradiance = encodedIrradiance.rgb;
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

    half3 indirectDiffuse = bakedGI;// * occlusion;
    half3 indirectSpecular = GlossyEnvironmentReflectionToon(reflectVector, brdfData.perceptualRoughness, occlusion, viewDirectionWS);

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



// Referenced: https://johnaustin.io/articles/2020/fast-subsurface-scattering-for-the-unity-urp
half LightingSubsurface(float NdotL, half subsurfaceRadius, half toony)
{
    half alpha = subsurfaceRadius + 0.00001h;
    half theta_m = acos(-alpha); // boundary of the lighting function

    float theta = max(0, NdotL + alpha) - alpha;
    half normalization_jgt = (2 + alpha) / (2 * (1 + alpha));
    half wrapped_jgt = (pow(((theta + alpha) / (1 + alpha)), 1 + alpha)) * normalization_jgt;

    wrapped_jgt = binarize(wrapped_jgt, 0, 0, 1);

    //half wrapped_valve = 0.25 * (NdotL + 1) * (NdotL + 1);
    //half wrapped_simple = (NdotL + alpha) / (1 + alpha);

    return wrapped_jgt;
}

half3 LightingSubsurfaceRamp(
     float NdotL, half curvature, Texture2D sssLutTexture)
{
    float u = saturate((NdotL+ 1) / 2);   // -1 ~ 1 > 0 ~ 1

    half3 lut = SAMPLE_TEXTURE2D(sssLutTexture, sampler_LinearClamp, half2(u, curvature));
    return lut;
}


half3 LightingToonySubsurface(
    ToonBRDFData brdfData, 
    half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 lightShadow,
    half3 normalWS)
{
    float NdotL = clamp(dot(normalWS, lightDirectionWS) + brdfData.shadeShift, -1, 1) ;

#ifdef SHADEMODEL_RAMP
    half3 radiance = LightingSubsurfaceRamp (NdotL, brdfData.curvature, brdfData.shadeRamp);
    half3 color = radiance * lightColor * lightAttenuation * lightShadow * brdfData.sss;
    return color;

#else
    half3 radiance = LightingSubsurface(NdotL, brdfData.curvature, __ToonyLighting);
    half3 color = radiance * lightColor * lightAttenuation * lightShadow * brdfData.sss;
    return color;
#endif
}


half3 LightingToonyDirect(
    ToonBRDFData brdfData, 
    half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 lightShadow, 
    half3 normalWS, half3 viewDirectionWS)
{
    float NdotL = saturate(dot(normalWS, lightDirectionWS)); 
    half3 radiance = lightColor * (lightAttenuation * lightShadow * ToonyShadeValue(brdfData, NdotL));
    return DirectToonBDRF(brdfData, normalWS, lightDirectionWS, viewDirectionWS, radiance);
}

half3 LightingToonyBased(ToonBRDFData brdfData, Light light, half3 normalWS, half3 viewDirectionWS)
{
    float NdotL = dot(normalWS, light.direction); 
    half shade = ToonyShadeValue(brdfData, NdotL);
    half shadow = brdfData.shadow * light.shadowAttenuation;

    // TODO: magic number
    shadow = binarize(shadow, 0.2f);

    half subsurface =  (1 - (shade * shadow)) * brdfData.subsurface;

    half3 color = LightingToonyDirect(brdfData, light.color, light.direction, light.distanceAttenuation, shade * shadow, normalWS, viewDirectionWS);// * (1-subsurface);
    color += LightingToonySubsurface(brdfData, light.color, light.direction, light.distanceAttenuation, 1, normalWS) * subsurface;

    return color;
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
half4 UniversalFragmentToon(
    InputData inputData, half3 diffuse, half3 sss,
    half metallic, half3 specular, half occlusion, half smoothness, half3 emission, half alpha, 
    half shadeShift, half shadeToony, 
    half curvature, Texture2D shadeRamp, 
    half toonyLighing, 
    out half3 shadeColor)
{
    ToonBRDFData brdfData;
    InitializeToonBRDFData(diffuse, sss, metallic, specular, smoothness, alpha, occlusion, shadeShift, shadeToony, toonyLighing, shadeRamp, curvature, brdfData);
    __ToonyLighting = toonyLighing; //TODO: ToonBRDFDataに埋め込む
    
    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 indirectDiffuse = inputData.bakedGI;// * occlusion;
    half3 color = GlobalIlluminationToon(brdfData, inputData.bakedGI, brdfData.occlusion, inputData.normalWS, inputData.viewDirectionWS);

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
    color += inputData.vertexLighting * brdfData.diffuse;
#endif
    color *= occlusion;
    color += emission;
    color = max(color, 0);

    shadeColor = indirectDiffuse * brdfData.diffuse + indirectDiffuse * brdfData.sss * (brdfData.curvature);

    return half4(color, alpha);
}

/*

half4 UniversalFragmentPBR(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha)
{
    BRDFData brdfData;
    InitializeBRDFData(albedo, metallic, specular, smoothness, alpha, brdfData);

    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

    half3 color = GlobalIllumination(brdfData, inputData.bakedGI, occlusion, inputData.normalWS, inputData.viewDirectionWS);
    color += LightingPhysicallyBased(brdfData, mainLight, inputData.normalWS, inputData.viewDirectionWS);

#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
        color += LightingPhysicallyBased(brdfData, light, inputData.normalWS, inputData.viewDirectionWS);
    }
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    color += inputData.vertexLighting * brdfData.diffuse;
#endif

    color += emission;
    return half4(color, alpha);
}
*/


#endif
