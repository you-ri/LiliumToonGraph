//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
// referenced: MToon Copyright (c) 2018 Masataka SUMI https://github.com/Santarh/MToon
//
#ifndef UNIVERSAL_TOONLIGHTING_SMOOSTHSTEP_INCLUDED
#define UNIVERSAL_TOONLIGHTING_SMOOSTHSTEP_INCLUDED

#if !SHADERGRAPH_PREVIEW

#define SHADEMODEL_RAMP

#include "ToonLighting.hlsl"

// カスタムファンクション
void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView, half3 BakedGI,
    half3 Diffuse, half3 Shade, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision,
    half ShadeShift, half ShadeToony, TEXTURE2D( ShadeRamp),
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
    Color = UniversalFragmentToon(inputData, Diffuse, Shade, 1, Specular, Occlusion, Smoothness, Emmision, 1, ShadeShift, ShadeToony, ShadeRamp, 1).rgb;
}

#else

void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView, half3 BakedGI,
    half3 Diffuse, half3 Shade, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision,
    half ShadeShift, half ShadeToony, Texture2D ShadeRamp,
    out half3 Color)
{
    Color = Diffuse;
}

#endif

#endif