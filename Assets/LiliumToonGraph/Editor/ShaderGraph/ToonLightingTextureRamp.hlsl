//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
// referenced: MToon Copyright (c) 2018 Masataka SUMI https://github.com/Santarh/MToon
//
#ifndef UNIVERSAL_TOONLIGHTING_TEXTURERAMP_INCLUDED
#define UNIVERSAL_TOONLIGHTING_TEXTURERAMP_INCLUDED

#if !SHADERGRAPH_PREVIEW

#define SHADEMODEL_RAMP

#include "ToonLighting.hlsl"


// カスタムファンクション
void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half3 Shade, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision,
    half ShadeShift, half ShadeToony, TEXTURE2D( ShadeRamp), half ToonyLighting,
    out half3 Color)
{
    InputData inputData;
    inputData.positionWS = WorldPosition;

    //TODO: _NORMALMAP ディレクティブが無効
#if defined(_NORMALMAP) || 1
    inputData.normalWS = TransformTangentToWorld(Normal, half3x3(WorldTangent.xyz, WorldBitangent.xyz, WorldNormal.xyz));
#else
    inputData.normalWS = Normal;
#endif
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = SafeNormalize(WorldView);

    //TODO: lightmapUVを取得する方法を見つけ出して解決する。
    //OUTPUT_LIGHTMAP_UV(lightmapUV, unity_LightmapST, lightmapUV);
float2 lightmapUV;
float3 vertexSH;
float3 normalWSBakedGI = lerp(inputData.normalWS, float3(0, 0, 0), ToonyLighting);
    
    OUTPUT_SH(normalWSBakedGI, vertexSH);
    inputData.bakedGI = SAMPLE_GI(lightmapUV, vertexSH, normalWSBakedGI);

    inputData.fogCoord = 0;
    inputData.vertexLighting = 0;
    
#if SHADOWS_SCREEN
   half4 clipPos = TransformWorldToHClip(WorldPosition);
   inputData.shadowCoord = ComputeScreenPos(clipPos);
#else
    inputData.shadowCoord = TransformWorldToShadowCoord(WorldPosition);
#endif
    
#ifdef _SPECULAR_SETUP
float3 specular = Specular;
float metallic = 1;
#else   
    float3 specular = 0;
    float metallic = Metallic;
#endif

    Color = UniversalFragmentToon(inputData, Diffuse, Shade, 1, Specular, Occlusion, Smoothness, Emmision, 1, ShadeShift, ShadeToony, ShadeRamp, ToonyLighting).rgb;
}

#else

void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half3 Shade, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision,
    half ShadeShift, half ShadeToony, Texture2D ShadeRamp, half ToonyLighting,
    out half3 Color)
{
    Color = Diffuse;
}

#endif

#endif