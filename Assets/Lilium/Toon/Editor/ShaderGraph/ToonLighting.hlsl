#ifndef LIGHTWEIGHT_TOONLIGHTING_INCLUDED
#define LIGHTWEIGHT_TOONLIGHTING_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.lightweight/ShaderLibrary/Lighting.hlsl"


///////////////////////////////////////////////////////////////////////////////

inline float3 TransformViewToProjection(float3 v) {
    return mul((float3x3)UNITY_MATRIX_P, v);
}

float4 TransformOutlineToHClipScreenSpace(float3 position, float3 normal, float outlineWidth)
{
    //float outlineTex = tex2Dlod(_OutlineWidthTexture, float4(TRANSFORM_TEX(v.texcoord, _MainTex), 0, 0)).r;
    half _OutlineScaledMaxDistance = 1;

    float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
    float aspect = abs(nearUpperRight.y / nearUpperRight.x);
    float4 vertex = TransformObjectToHClip(position);
    float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, normal.xyz);
    float3 clipNormal = TransformViewToProjection(viewNormal.xyz);
    float2 projectedNormal = normalize(clipNormal.xy);
    projectedNormal *= min(vertex.w, _OutlineScaledMaxDistance);
    projectedNormal.x *= aspect;
    vertex.xy += 0.01 * outlineWidth * projectedNormal.xy;
    return vertex;
}

float4 TransformOutlineToHClipWorldSpace(float3 vertex, float3 normal, half outlineWidth)
{
    float3 worldNormalLength = length(mul((float3x3)transpose(unity_WorldToObject), normal));
    float3 outlineOffset = 0.01 * outlineWidth * worldNormalLength * normal;
    return TransformObjectToHClip(vertex + outlineOffset);
}


///////////////////////////////////////////////////////////////////////////////
half3 LightingToon(half3 lightColor, half3 lightDir, half3 normal, half shadeShift, half shadeToony)
{
    half lightIntensity = dot(normal, lightDir);
	lightIntensity = lightIntensity * 0.5 + 0.5; // from [-1, +1] to [0, 1]
    //lightIntensity = lightIntensity * (1.0 - receiveShadow * (1.0 - (atten * 0.5 + 0.5))); // receive shadow
    lightIntensity = lightIntensity; // darker
    lightIntensity = lightIntensity * 2.0 - 1.0; // from [0, 1] to [-1, +1]
    lightIntensity = smoothstep(shadeShift, shadeShift + (1.0 - shadeToony), lightIntensity); // shade & tooned
    //lightIntensity = lightIntensity * (1.0 - receiveShadow * (1.0 - (atten))); // receive shadow 落ちる影に関してはトーン処理しないほうが綺麗になるので、トーン化の後に処理
	return lightIntensity * lightColor;
}

half3 ToonyIntensity(half3 lightDir, half3 normal, half shadeShift, half shadeToony)
{
    half lightIntensity = dot(normal, lightDir);
    lightIntensity = lightIntensity * 0.5 + 0.5; // from [-1, +1] to [0, 1]
    lightIntensity = lightIntensity * 2.0 - 1.0; // from [0, 1] to [-1, +1]
    lightIntensity = smoothstep(shadeShift, shadeShift + (1.0 - shadeToony), lightIntensity); // shade & tooned
    return lightIntensity;
}

half4 LightweightFragmentToon(InputData inputData, half3 lightBakedGI, half3 diffuse, half3 shade, half4 specularGloss, half shininess, half3 emission, half alpha, half shadeShift, half shadeToony)
{
    Light mainLight = GetMainLight(inputData.shadowCoord);
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, half4(0, 0, 0, 0));

	//half toonyIntensity = ToonyIntensity(mainLight.direction, inputData.normalWS, shadeShift, shadeToony);
    float shadow = (mainLight.distanceAttenuation * mainLight.shadowAttenuation);
    half3 attenuatedLightColor = mainLight.color;// *(mainLight.distanceAttenuation * mainLight.shadowAttenuation);
    float lighing = ToonyIntensity(mainLight.direction, inputData.normalWS, shadeShift, shadeToony) * shadow;
    half3 shadeColor = inputData.bakedGI * shade;// +LightingToon(attenuatedLightColor, mainLight.direction, inputData.normalWS, shadeShift, shadeToony);
    half3 lightColor = lightBakedGI + attenuatedLightColor;
    half3 diffuseColor = lerp(shadeColor, lightColor, lighing);
    //half3 diffuseColor = attenuatedLightColor * toonyIntensity + shade * inputData.bakedGI;
    half3 specularColor = LightingSpecular(attenuatedLightColor, mainLight.direction, inputData.normalWS, inputData.viewDirectionWS, specularGloss, shininess);

#ifdef _ADDITIONAL_LIGHTS
    int pixelLightCount = GetAdditionalLightsCount();
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, inputData.positionWS);
        half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
        diffuseColor += LightingToon(attenuatedLightColor, light.direction, inputData.normalWS, shadeShift, shadeToony);
        specularColor += LightingSpecular(attenuatedLightColor, light.direction, inputData.normalWS, inputData.viewDirectionWS, specularGloss, shininess);
    }
#endif

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    diffuseColor += inputData.vertexLighting;
#endif

    half3 finalColor = diffuseColor * diffuse + emission;

#if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
    finalColor += specularColor;
#endif

    return half4(finalColor, alpha);
}
#endif
