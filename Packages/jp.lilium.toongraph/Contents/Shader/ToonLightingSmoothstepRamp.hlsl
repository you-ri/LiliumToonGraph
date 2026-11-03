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
    //-- InitializeInputData() --

    InputData inputData = (InputData)0;
    SurfaceData_Toon surfaceData = (SurfaceData_Toon)0;

    Varyings input = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    input.positionWS = WorldPosition;
    // ScreenPosition はシェーダーグラフの Screen Position(Default)= 0〜1 に正規化済みの画面座標。
    // 画素の座標ではないので、画素が要る所(APV のノイズなど)のために画素へ戻しておく
    input.positionCS = float4(ScreenPosition.xy * GetScaledScreenParams().xy, ScreenPosition.z, 1);
    input.tangentWS = float4(WorldTangent.xyz, 1);
    input.normalWS = WorldNormal;
    inputData.tangentToWorld = half3x3(WorldTangent.xyz, WorldBitangent.xyz, WorldNormal.xyz);

    inputData.positionWS = input.positionWS;

    surfaceData.normalTS = Normal;

    #ifdef _NORMALMAP
        // IMPORTANT! If we ever support Flip on double sided materials ensure bitangent and tangent are NOT flipped.
        float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
        float3 bitangent = crossSign * cross(input.normalWS.xyz, input.tangentWS.xyz);

        #if _NORMAL_DROPOFF_TS
            inputData.normalWS = TransformTangentToWorld(Normal, inputData.tangentToWorld);
            // TransformTangentToWorld(surfaceDescription.NormalTS, inputData.tangentToWorld);
        #elif _NORMAL_DROPOFF_OS
            //inputData.normalWS = TransformObjectToWorldNormal(surfaceDescription.NormalOS);
        #elif _NORMAL_DROPOFF_WS
            //inputData.normalWS = surfaceDescription.NormalWS;
        #endif
    #else
        inputData.normalWS = input.normalWS;
    #endif
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
//    inputData.viewDirectionWS = SafeNormalize(WorldView);

    
    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
        inputData.shadowCoord = input.shadowCoord;              //TODO: shadowCoordの初期化が必要
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif
    //inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    
    // Forward+ はこの値で画面の区画を引いて、届く光と反射プローブの一覧を得る。
    // 以前は正規化済みの値をさらに画面サイズで割っていて、どの画素も画面の隅の区画を引いていた
    // (隅の区画に届かない点光源が当たらず、カメラが動くと付いたり消えたりした)
    inputData.normalizedScreenSpaceUV = ScreenPosition.xy;

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

    inputData.positionCS = input.positionCS;
    // -- InitializeInputData() -- 

    float3 vertexSH;
    float3 cameraDirectionWS = mul((float3x3)UNITY_MATRIX_M, transpose(mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V)) [2].xyz);
    float3 normalWSBakedGI = lerp(inputData.normalWS, cameraDirectionWS, ToonyLighting);        
    OUTPUT_SH(normalWSBakedGI, vertexSH);
    //OUTPUT_SH4(vertexInput.positionWS, normalWS.xyz, GetWorldSpaceNormalizeViewDir(vertexInput.positionWS), output.sh, output.probeOcclusion);

    
    //input.sh = vertexSH;

#ifdef _SPECULAR_SETUP
    float3 specular = Specular;
    float metallic = 1;
#else   
    float3 specular = 0;
    float metallic = Specular.r;
#endif

    // デカールを塗り込む(陰影の前)
    {
        half3 decalNormal = inputData.normalWS;
        half3 decalSpecular = specular;
        half decalMetallic = metallic;
        ApplyDecal_Toon(ScreenPosition.xy, Diffuse, decalSpecular, decalNormal, decalMetallic, Occlusion, Smoothness);
        inputData.normalWS = decalNormal;
        specular = decalSpecular;
        metallic = decalMetallic;
    }


    // -- InitializeBakedGIData() --
    #if defined(DYNAMICLIGHTMAP_ON)
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.dynamicLightmapUV.xy, vertexSH, normalWSBakedGI);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
    #elif !defined(LIGHTMAP_ON) && (defined(PROBE_VOLUMES_L1) || defined(PROBE_VOLUMES_L2))
    inputData.bakedGI = SAMPLE_GI(vertexSH,
        GetAbsolutePositionWS(inputData.positionWS),
        normalWSBakedGI,
        inputData.viewDirectionWS,
        input.positionCS.xy,
        input.probeOcclusion,
        inputData.shadowMask);
    #else
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, vertexSH, normalWSBakedGI);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);
    #endif
    // -- InitializeBakedGIData() --

    TEXTURE2D(ShadeRamp);


    surfaceData.albedo = Diffuse;
    surfaceData.specular = Specular;
    surfaceData.metallic = metallic;
    surfaceData.smoothness = Smoothness;
    surfaceData.normalTS = Normal;
    surfaceData.emission = Emmision;
    surfaceData.occlusion = Occlusion;
    surfaceData.alpha = Alpha;
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 1;

    surfaceData.toonize = ToonyLighting;
    surfaceData.sss = SSS.rgb * surfaceData.albedo;
    surfaceData.subsurface = SSS.a;
#if defined(_TOON_SHADE_SHIFT)
    // 影マップで光と影の境目をずらす。他のシェーダーは ShadeShift に別の意味の値を流しているので、このキーワードのシェーダーだけ
    surfaceData.shadeShift = ShadeShift;
    // このキーワードのシェーダーは Shade Toony の入力でトゥーンランプの縦の位置を渡す(他に使っていない入力)
    surfaceData.toonRampV = ShadeToony;
#endif

    Color = UniversalFragmentPBR_Toon(inputData, surfaceData, ShadeColor);
}


#else

void ToonLight_half(
    half3 ScreenPosition, half3 WorldPosition, half3 WorldNormal, half3 WorldTangent, half3 WorldBitangent, half3 WorldView,
    half3 Diffuse, half4 SSS, half3 Normal, half3 Specular, half Smoothness, half Occlusion, half3 Emmision, half Alpha,
    half ShadowShift, half ShadeShift, half ShadeToony,
    half Curvature,
    half ToonyLighting, 
    out half4 Color, out half3 ShadeColor)
{
    Color = float4(Diffuse, Alpha);
    ShadeColor = (SSS + Diffuse) * 0.5f;
}


#endif

// URP Lit ターゲットが自分でデカールを塗るのを止める(塗るのは上の ToonLight_half の中だけ。理由は ToonLighting.hlsl の ApplyDecal_Toon)。
// カスタム関数のファイルはグラフの前に、URP の PBRForwardPass.hlsl(#if defined(_DBUFFER) でデカールを塗る)はグラフの後に読まれる
#undef _DBUFFER


#endif