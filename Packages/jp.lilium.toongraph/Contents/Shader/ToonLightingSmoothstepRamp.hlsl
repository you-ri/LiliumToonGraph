//
// referenced: com.unity.render-pipelines.lightweight@5.6.1\ShaderLibrary\Lighting.hlsl
// referenced: com.unity.render-pipelines.universal@10.2.2\Editor\ShaderGraph\Includes\PBRForwardPass.hlsl
//
#ifndef UNIVERSAL_TOONLIGHTING_SMOOSTHSTEP_INCLUDED
#define UNIVERSAL_TOONLIGHTING_SMOOSTHSTEP_INCLUDED

#pragma multi_compile _ _TOON_OUTLINE 

#ifndef SHADERGRAPH_PREVIEW

#include "ToonLighting.hlsl"

void TransformScreenUV_Toon(inout float2 uv, float screenHeight)
{
    #if UNITY_UV_STARTS_AT_TOP
    uv.y = screenHeight - (uv.y * _ScaleBiasRt.x + _ScaleBiasRt.y * screenHeight);
    #endif
}

void TransformScreenUV_Toon(inout float2 uv)
{
    #if UNITY_UV_STARTS_AT_TOP
    TransformScreenUV_Toon(uv, GetScaledScreenParams().y);
    #endif
}

void TransformNormalizedScreenUV_Toon(inout float2 uv)
{
    #if UNITY_UV_STARTS_AT_TOP
    TransformScreenUV_Toon(uv, 1.0);
    #endif
}

float2 GetNormalizedScreenSpaceUV_Toon(float4 positionCS)
{
    //positionCS.xy = positionCS.xy /= positionCS.w;
    float2 normalizedScreenSpaceUV = positionCS.xy * rcp(GetScaledScreenParams().xy);
    TransformNormalizedScreenUV_Toon(normalizedScreenSpaceUV);
    return normalizedScreenSpaceUV;
}


void ToonLight_half(
    half3 ScreenPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half4 SSS, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadowShift, half ShadeShift, half ShadeToony,
    half Curvature,
    half ToonyLighting, 
    out half4 Color, out half3 ShadeColor)
{
    InputData inputData = (InputData)0;

    Varyings input = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    input.positionWS = WorldPosition;
    input.positionCS = TransformWorldToHClip(input.positionWS);
    input.tangentWS = float4(WorldTangent.xyz, 1);
    input.normalWS = WorldNormal;

    #if defined(_PARALLAXMAP)
    #if defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
        half3 viewDirTS = input.viewDirTS;
    #else
        half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
        half3 viewDirTS = GetViewDirectionTangentSpace(input.tangentWS, input.normalWS, viewDirWS);
    #endif
        ApplyPerPixelDisplacement(viewDirTS, input.uv);
    #endif


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
    inputData.normalWS = NormalizeNormalPerPixel(WorldNormal);
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
//    inputData.viewDirectionWS = SafeNormalize(WorldView);

    float3 vertexSH;
    float3 cameraDirectionWS = mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz);
    float3 normalWSBakedGI = lerp(inputData.normalWS, cameraDirectionWS, ToonyLighting);        
    OUTPUT_SH(normalWSBakedGI, vertexSH);

    
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif
    #ifdef _ADDITIONAL_LIGHTS_VERTEX
    //inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactorAndVertexLight.x);
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    #else
    //inputData.fogCoord = InitializeInputDataFog(float4(input.positionWS, 1.0), input.fogFactor);
    #endif

    inputData.normalizedScreenSpaceUV = ScreenPosition.xy; //GetNormalizedScreenSpaceUV_Toon(input.positionCS);

    #if defined(DEBUG_DISPLAY)
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.dynamicLightmapUV = input.dynamicLightmapUV;
    #endif
    #if defined(LIGHTMAP_ON)
    inputData.staticLightmapUV = input.staticLightmapUV;
    #else
    inputData.vertexSH = vertexSH;
    #endif
    #if defined(USE_APV_PROBE_OCCLUSION)
    inputData.probeOcclusion = input.probeOcclusion;
    #endif
    #endif    


    // InitializeBakedGIData()
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV.xy, input.sh, normalWSBakedGI);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
    #elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
    inputData.bakedGI = SAMPLE_GI(vertexSH,
        GetAbsolutePositionWS(inputData.positionWS),
        normalWSBakedGI,
        inputData.viewDirectionWS,normalWSBakedGI
        input.positionCS.xy,
        input.probeOcclusion,
        inputData.shadowMask);
    #else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, vertexSH, normalWSBakedGI);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
    #endif

#ifdef _SPECULAR_SETUP
    float3 specular = Specular;
    float metallic = 1;
#else   
    float3 specular = 0;
    float metallic = Specular.r;
#endif
    TEXTURE2D(ShadeRamp);

    Color = half4( input.positionCS.x, input.positionCS.y, 1, 1);
    Color = half4( inputData.normalizedScreenSpaceUV.x, inputData.normalizedScreenSpaceUV.y, 0, 1);
    ShadeColor = Color.rgb;
    //return;

    Color = UniversalFragmentToon(
        inputData, Diffuse, SSS, metallic, Specular, Occlusion, Smoothness, Emmision, Alpha, 
        ShadowShift, ShadeShift, ShadeToony, Curvature, ShadeRamp, ToonyLighting, 
        ShadeColor);
}


#else

void ToonLight_half(
    half3 ScreenPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half3 SSS, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadowShift, half ShadeShift, half ShadeToony,
    half Curvature,
    half ToonyLighting, 
    out half4 Color, out half3 ShadeColor)
{
    Color = float4(Diffuse, Alpha);
    ShadeColor = (SSS + Diffuse) * 0.5f;
}


#endif


#endif