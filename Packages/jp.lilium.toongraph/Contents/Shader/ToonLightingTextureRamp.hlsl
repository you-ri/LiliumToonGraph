//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
// referenced: MToon Copyright (c) 2018 Masataka SUMI https://github.com/Santarh/MToon
//
#ifndef UNIVERSAL_TOONLIGHTING_TEXTURERAMP_INCLUDED
#define UNIVERSAL_TOONLIGHTING_TEXTURERAMP_INCLUDED

#if !SHADERGRAPH_PREVIEW

#define SHADEMODEL_RAMP

#include "ToonLighting.hlsl"


void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half4 Shade, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadeShift, half ShadeToony, TEXTURE2D(ShadeRamp), half ToonyLighting,
    out half4 Color)
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
    float3 cameraDirectionWS = mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz);
    float3 normalWSBakedGI = lerp(inputData.normalWS, cameraDirectionWS, ToonyLighting);        // カメラの向いている方向に法線を統一

    OUTPUT_SH(normalWSBakedGI, vertexSH);
    inputData.bakedGI = SAMPLE_GI(lightmapUV, vertexSH, normalWSBakedGI);
     
    //TODO: 値を設定する
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
    float metallic = Specular.r;
#endif

    Color = UniversalFragmentToon(inputData, Diffuse, Shade, metallic, Specular, Occlusion, Smoothness, Emmision, Alpha, ShadeShift, ShadeToony, ShadeRamp, ToonyLighting);
}

#else

void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half4 Shade, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadeShift, half ShadeToony, Texture2D ShadeRamp, half ToonyLighting,
    out half4 Color)
{
    Color.rgb = Diffuse;
    Color.a = Alpha;
}

#endif

#endif