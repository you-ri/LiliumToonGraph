//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
// referenced: MToon Copyright (c) 2018 Masataka SUMI https://github.com/Santarh/MToon
//
#ifndef UNIVERSAL_TOONLIGHTING_SMOOSTHSTEP_INCLUDED
#define UNIVERSAL_TOONLIGHTING_SMOOSTHSTEP_INCLUDED


#if !SHADERGRAPH_PREVIEW

#include "ToonLighting.hlsl"

// カスタムファンクション
void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half3 Shade, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadeShift, half ShadeToony, half ToonyLighting,
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
    float3 normalWSBakedGI = lerp(inputData.normalWS, float3(0, 0, 0), ToonyLighting);

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
    float metallic = Metallic;
#endif
    //TODO: shadeRampを必要としないUniversalFragmentToonを作成する。
    TEXTURE2D(shadeRamp);

    Color = UniversalFragmentToon(inputData, Diffuse, Shade, metallic, Specular, Occlusion, Smoothness, Emmision, Alpha, ShadeShift, ShadeToony, shadeRamp, ToonyLighting);
    //Color.rgb = MixFog(Color.rgb, inputData.fogCoord);
    //Color = UniversalFragmentPBR(inputData, Diffuse, metallic, specular, Smoothness, Occlusion, Emmision, Alpha);
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


half4 frag(PackedVaryings packedInput) : SV_TARGET 
{    
    Varyings unpacked = UnpackVaryings(packedInput);
    UNITY_SETUP_INSTANCE_ID(unpacked);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(unpacked);

    SurfaceDescriptionInputs surfaceDescriptionInputs = BuildSurfaceDescriptionInputs(unpacked);
    SurfaceDescription surfaceDescription = SurfaceDescriptionFunction(surfaceDescriptionInputs);

    #if _AlphaClip
        clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
    #endif

    InputData inputData;
    BuildInputData(unpacked, surfaceDescription.Normal, inputData);

    #ifdef _SPECULAR_SETUP
        float3 specular = surfaceDescription.Specular;
        float metallic = 1;
    #else   
        float3 specular = 0;
        float metallic = surfaceDescription.Metallic;
    #endif

    half4 color = UniversalFragmentPBR(
			inputData,
			surfaceDescription.Albedo,
			metallic,
			specular,
			surfaceDescription.Smoothness,
			surfaceDescription.Occlusion,
			surfaceDescription.Emission,
			surfaceDescription.Alpha); 

    color.rgb = MixFog(color.rgb, inputData.fogCoord); 
    return color;
}
*/

#else

void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half3 Shade, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadeShift, half ShadeToony, half ToonyLighting,
    out half4 Color)
{
    Color = float4( Diffuse, Alpha);
}

#endif


#endif