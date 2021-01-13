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
    half ShadeShift, half ShadeToony, TEXTURE2D(ShadeRamp), half Curvature, half ToonyLighting,
    out half4 Color, out half3 ShadeColor)
{
    InputData inputData = (InputData)0;
    inputData.positionWS = WorldPosition;

    //TODO: _NORMALMAP ディレクティブが無効
#if defined(_NORMALMAP) || 1
    inputData.normalWS = TransformTangentToWorld(Normal, half3x3(WorldTangent.xyz, WorldBitangent.xyz, WorldNormal.xyz));
#else
    inputData.normalWS = Normal;
#endif

    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = SafeNormalize(WorldView);

#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    //TODO: 非対応
    //inputData.shadowCoord = input.shadowCoord;
    inputData.shadowCoord = float4(0, 0, 0, 0);
#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(WorldPosition);
#else
    inputData.shadowCoord = float4(0, 0, 0, 0);
#endif

#if (SHADERPASS == SHADERPASS_FORWARD) || (SHADERPASS == SHADERPASS_GBUFFER)
    float2 lightmapUV = float2(0, 0);
    float3 vertexSH;
    //TODO: lightmapUVを取得する方法を見つけ出して解決する。
    //OUTPUT_LIGHTMAP_UV(IN.uv1, unity_LightmapST, lightmapUV);

    // SHで使う法線をカメラの向いている方向に
    float3 cameraDirectionWS = mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz);
    float3 normalWSBakedGI = lerp(inputData.normalWS, cameraDirectionWS, ToonyLighting);        
    OUTPUT_SH(normalWSBakedGI, vertexSH);
    inputData.bakedGI = SAMPLE_GI(lightmapUV, vertexSH, normalWSBakedGI);
#endif   
    //TODO: 非対応
    //inputData.fogCoord = input.fogFactorAndVertexLight.x;
    //inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.vertexLighting = 0;
    //inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(lightmapUV);

#ifdef _SPECULAR_SETUP
    float3 specular = Specular;
    float metallic = 1;
#else   
    float3 specular = 0;
    float metallic = Specular.r;
#endif

    Color = UniversalFragmentToon(
        inputData, Diffuse, SSS, metallic, Specular, Occlusion, Smoothness, Emmision, Alpha, ShadeShift, ShadeToony, Curvature, ShadeRamp, ToonyLighting, 
        ShadeColor);
}

#else

void ToonLight_half(
    half3 ObjectPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half3 SSS, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadeShift, half ShadeToony, Texture2D ShadeRamp, half Curvature, half ToonyLighting,
    out half4 Color, out half3 ShadeColor)
{
    Color.rgb = Diffuse;
    Color.a = Alpha;
    ShadeColor = (SSS + Diffuse) * 0.5f;
}

#endif

#endif