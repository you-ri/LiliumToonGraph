//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
// referenced: com.unity.render-pipelines.universal@10.2.2\Editor\ShaderGraph\Includes\PBRForwadPass.hlsl
//
#ifndef UNIVERSAL_TOONLIGHTING_TEXTURERAMP_INCLUDED
#define UNIVERSAL_TOONLIGHTING_TEXTURERAMP_INCLUDED

#ifndef SHADERGRAPH_PREVIEW

#define SHADEMODEL_RAMP

#include "ToonLighting.hlsl"

void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half4 SSS, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadowShift, half ShadeShift, half ShadeToony, TEXTURE2D(ShadeRamp), half Curvature, half ToonyLighting,
    out half4 Color, out half3 ShadeColor)
{
    InputData inputData = (InputData)0;

    Varyings input = (Varyings)0;
    input.positionWS = WorldPosition;
    input.tangentWS = float4(WorldTangent.xyz, 1);
    input.normalWS = WorldNormal;
    //input.fogFactorAndVertexLight = float4(0, 0, 0, 0);
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        input.shadowCoord = float4(0, 0, 0, 0);
    #endif
    #if defined(DYNAMICLIGHTMAP_ON)    
        input.staticLightmapUV = float4(0, 0, 0, 0);
        input.sh = float3(0, 0, 0);
    #endif

    inputData.positionWS = input.positionWS;

#if defined(_NORMALMAP) || defined(_DETAIL)

    float sgn = 1;//WorldTangent.w;      // should be either +1 or -1 TODO: WorldTangent.w の値を取得できないため、１で固定する。
    float3 bitangent = sgn * cross(WorldNormal.xyz, WorldTangent.xyz);
    inputData.normalWS = TransformTangentToWorld(Normal, half3x3(WorldTangent.xyz, bitangent.xyz, WorldNormal.xyz));
#else
    inputData.normalWS = WorldNormal;
#endif
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
//    inputData.viewDirectionWS = SafeNormalize(WorldView);

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = TransformWorldToShadowCoord(WorldPosition); 
    #endif

    //inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    //inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    float3 vertexSH;
    float3 cameraDirectionWS = mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz);
    float3 normalWSBakedGI = lerp(inputData.normalWS, cameraDirectionWS, ToonyLighting);        
    OUTPUT_SH(normalWSBakedGI, vertexSH);

    inputData.vertexLighting = 0;
#if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV.xy, input.sh, normalWSBakedGI);
#else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, vertexSH, normalWSBakedGI);
#endif
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV.xy;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = input.sh;
    #endif
    #endif

#ifdef _SPECULAR_SETUP
    float3 specular = Specular;
    float metallic = 1;
#else   
    float3 specular = 0;
    float metallic = Specular.r;
#endif
    Color = UniversalFragmentToon(
        inputData, Diffuse, SSS, metallic, Specular, Occlusion, Smoothness, Emmision, Alpha, ShadowShift, ShadeShift, ShadeToony, Curvature, ShadeRamp, ToonyLighting, 
        ShadeColor);
}

#else

void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half3 SSS, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadowShift, half ShadeShift, half ShadeToony, Texture2D ShadeRamp,
    half Curvature, half ToonyLighting,
    out half4 Color, out half3 ShadeColor)
{
    Color.rgb = Diffuse;
    Color.a = Alpha;
    ShadeColor = (SSS + Diffuse) * 0.5f;
}

#endif

#endif