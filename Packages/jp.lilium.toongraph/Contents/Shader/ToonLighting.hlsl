// referanced: Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl


#ifndef LILIUM_TOON_LIGHTING_INCLUDED
#define LILIUM_TOON_LIGHTING_INCLUDED

#include "ClusterLightLoopCompat.hlsl"

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Debug/Debugging3D.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

// 光が当たる側と影の境目、SSS の境目。プロジェクト設定（LiliumToonSettings）から毎フレーム入る
half _ToonShadeThreshold;
half _ToonSubsurfaceThreshold;

// トゥーンランプ（横 = N・L + 影マップのずれ（-1〜1）、縦 = 段階の種類、R = 直接光の強さ、G = 環境光とメインライト（SSS）の倍率）。
// プロジェクト設定（LiliumToonSettings）から毎フレーム入る。
// キーワード _TOON_SHADE_SHIFT のシェーダー（パレット形式）だけが使い、他は _ToonShadeThreshold の 2 階調のまま
TEXTURE2D(_ToonRamp);
SAMPLER(sampler_ToonRamp);

// 1 画素が覆う N・L の幅(width)の中を 4 点読んで平均する。縮小すると段の境目が画素単位で切れてザラつくので、画素 1 つ分だけなだらかにする。
// ライトのループの中でも呼ぶので微分は取らず、読み出しも LOD を指定する
#define TOON_RAMP_MAX_FILTER_WIDTH 0.5

half2 SampleToonRamp(float shadedNdotL, half v, float width)
{
    float u = shadedNdotL * 0.5 + 0.5;
    float offset = min(width, TOON_RAMP_MAX_FILTER_WIDTH) * 0.5 * 0.25;
    half2 sum = SAMPLE_TEXTURE2D_LOD(_ToonRamp, sampler_ToonRamp, float2(u - offset * 1.5, v), 0).rg;
    sum += SAMPLE_TEXTURE2D_LOD(_ToonRamp, sampler_ToonRamp, float2(u - offset * 0.5, v), 0).rg;
    sum += SAMPLE_TEXTURE2D_LOD(_ToonRamp, sampler_ToonRamp, float2(u + offset * 0.5, v), 0).rg;
    sum += SAMPLE_TEXTURE2D_LOD(_ToonRamp, sampler_ToonRamp, float2(u + offset * 1.5, v), 0).rg;
    return sum * half(0.25);
}

// 追加ライトの光源の半径（メートル）。URP の追加ライトと同じ番号で並ぶ。ToonLightSourceRadius の付いた点光源・スポットライトだけ 0 以外。
// ToonOutlineRenderFeature のパスがカメラごとに入れる
float _ToonLightSourceRadius[MAX_VISIBLE_LIGHTS];

// 光源を半径 r の球として扱い、減衰を 1/d² から 1/(d²+r²) にする係数 d²/(d²+r²)。
// 光源の中心が面に近づいても明るさが 1/r² で頭打ちになる。r が 0 なら 1（今のまま）
float ToonLightSourceRadiusFactor(uint i, float3 positionWS)
{
#if USE_CLUSTER_LIGHT_LOOP
    int lightIndex = i;
#else
    int lightIndex = GetPerObjectLightIndex(i);
#endif
    float radius = _ToonLightSourceRadius[lightIndex];
#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
    float4 lightPositionWS = _AdditionalLightsBuffer[lightIndex].position;
#else
    float4 lightPositionWS = _AdditionalLightsPosition[lightIndex];
#endif
    float3 lightVector = lightPositionWS.xyz - positionWS * lightPositionWS.w;
    float distanceSqr = max(dot(lightVector, lightVector), HALF_MIN);
    return distanceSqr / (distanceSqr + radius * radius);
}


///////////////////////////////////////////////////////////////////////////////
// デカール(URP の Decal Projector・DBuffer 方式)
///////////////////////////////////////////////////////////////////////////////

// Toon Lighting サブグラフが受け取る Screen Position(0〜1 に正規化済み・URP の normalizedScreenSpaceUV と同じ)を、
// DBuffer を読む画素の座標(SV_Position と同じ向き)に戻す。URP の TransformNormalizedScreenUV の逆
float4 DecalPositionCS_Toon(float2 normalizedScreenUV)
{
    float2 uv = normalizedScreenUV;
    #if UNITY_UV_STARTS_AT_TOP
    uv.y = (1.0 - uv.y - _ScaleBiasRt.y) / _ScaleBiasRt.x;
    #endif
    return float4(uv * GetScaledScreenParams().xy, 0, 1);
}

// トゥーンの陰影を計算する前に、デカールの色・法線・金属/AO/滑らかさを塗り込む。
// URP Lit ターゲットは自分でもグラフの BaseColor にデカールを塗って PBR で照らす(トゥーンの結果は Emission なので上に足される)。
// それを止めるため、各ランプのファイルの末尾で _DBUFFER を消している(PBRForwardPass.hlsl はグラフの後に読まれる)。
// アウトラインの描き直し(_TOON_OUTLINE)では塗らない。半透明(_SURFACE_TYPE_TRANSPARENT)は URP の仕様で _DBUFFER が付かず塗られない
void ApplyDecal_Toon(float2 normalizedScreenUV, inout half3 albedo, inout half3 specular, inout half3 normalWS,
    inout half metallic, inout half occlusion, inout half smoothness)
{
    #if defined(_DBUFFER) && !defined(_TOON_OUTLINE)
    ApplyDecal(DecalPositionCS_Toon(normalizedScreenUV), albedo, specular, normalWS, metallic, occlusion, smoothness);
    #endif
}




///////////////////////////////////////////////////////////////////////////////
// refarence: Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl
///////////////////////////////////////////////////////////////////////////////

struct SurfaceData_Toon
{
    half3 albedo;
    half3 specular;
    half  metallic;
    half  smoothness;
    half3 normalTS;
    half3 emission;
    half  occlusion;
    half  alpha;
    half  clearCoatMask;
    half  clearCoatSmoothness;

    half toonize;

    half3 sss;
    half subsurface;

    // 光と影の境目を画素ごとにずらす量（NdotL に足す）。キーワード _TOON_SHADE_SHIFT のシェーダーだけが入れる。他は 0
    half shadeShift;
    // トゥーンランプの縦の位置。キーワード _TOON_SHADE_SHIFT のシェーダーだけが入れる。他は 0
    half toonRampV;
};


///////////////////////////////////////////////////////////////////////////////
// refarence: Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl
///////////////////////////////////////////////////////////////////////////////

struct BRDFData_Toon
{
    half3 albedo;
    half3 diffuse;
    half3 specular;
    half reflectivity;
    half perceptualRoughness;
    half roughness;
    half roughness2;
    half grazingTerm;

    // We save some light invariant BRDF terms so we don't have to recompute
    // them in the light loop. Take a look at DirectBRDF function for detailed explaination.
    half normalizationTerm;     // roughness * 4.0 + 2.0
    half roughness2MinusOne;    // roughness^2 - 1.0

    half3 sss;
    half curvature;
    half toonize;
    half occlusion;
    half shadeShift;
    half toonRampV;
#if defined(_TOON_SHADE_SHIFT)
    // 隣の画素との差。トゥーンランプをなだらかにする幅をライトごとに求める(ライトのループの中では微分を取れない)
    float3 normalDdx;
    float3 normalDdy;
    float shadeShiftDdx;
    float shadeShiftDdy;
#endif
};

#if defined(_TOON_SHADE_SHIFT)
// 1 画素が覆う「N・L + 影マップのずれ」の幅
float ToonRampFilterWidth(BRDFData_Toon brdfData, float3 lightDirectionWS)
{
    return abs(dot(brdfData.normalDdx, lightDirectionWS) + brdfData.shadeShiftDdx)
        + abs(dot(brdfData.normalDdy, lightDirectionWS) + brdfData.shadeShiftDdy);
}
#endif

#include "ToonGlobalIllumination.hlsl"



inline void InitializeBRDFDataDirect_Toon(half3 albedo, half3 diffuse, half3 specular, half reflectivity, half oneMinusReflectivity, half smoothness, half occlusion, half3 sss, half subsurface, half toonize, inout half alpha, out BRDFData_Toon outBRDFData)
{
    outBRDFData = (BRDFData_Toon)0;
    outBRDFData.albedo = albedo;
    outBRDFData.diffuse = diffuse;
    outBRDFData.specular = specular;
    outBRDFData.reflectivity = reflectivity;

    outBRDFData.perceptualRoughness = PerceptualSmoothnessToPerceptualRoughness(smoothness);
    outBRDFData.roughness           = max(PerceptualRoughnessToRoughness(outBRDFData.perceptualRoughness), HALF_MIN_SQRT);
    outBRDFData.roughness2          = max(outBRDFData.roughness * outBRDFData.roughness, HALF_MIN);
    outBRDFData.grazingTerm         = saturate(smoothness + reflectivity);
    outBRDFData.normalizationTerm   = outBRDFData.roughness * half(4.0) + half(2.0);
    outBRDFData.roughness2MinusOne  = outBRDFData.roughness2 - half(1.0);

    outBRDFData.toonize = half(1.0) - toonize;
    outBRDFData.sss = sss.rgb * outBRDFData.diffuse;
    outBRDFData.curvature = subsurface;
    outBRDFData.occlusion = occlusion;

    // Input is expected to be non-alpha-premultiplied while ROP is set to pre-multiplied blend.
    // We use input color for specular, but (pre-)multiply the diffuse with alpha to complete the standard alpha blend equation.
    // In shader: Cs' = Cs * As, in ROP: Cs' + Cd(1-As);
    // i.e. we only alpha blend the diffuse part to background (transmittance).
    #if defined(_ALPHAPREMULTIPLY_ON)
        // TODO: would be clearer to multiply this once to accumulated diffuse lighting at end instead of the surface property.
        outBRDFData.diffuse *= alpha;
    #endif
}

// Legacy: do not call, will not correctly initialize albedo property.
inline void InitializeBRDFDataDirect_Toon(half3 diffuse, half3 specular, half reflectivity, half oneMinusReflectivity, half smoothness, half occlusion, half3 sss, half subsurface, half toonize, inout half alpha, out BRDFData_Toon outBRDFData)
{
    InitializeBRDFDataDirect_Toon(half3(0.0, 0.0, 0.0), diffuse, specular, reflectivity, oneMinusReflectivity, smoothness, occlusion, sss, subsurface, toonize, alpha, outBRDFData);
}

// Initialize BRDFData for material, managing both specular and metallic setup using shader keyword _SPECULAR_SETUP.
inline void InitializeBRDFData_Toon(half3 albedo, half metallic, half3 specular, half smoothness, half occlusion, half3 sss, half subsurface, half toonize, inout half alpha, out BRDFData_Toon outBRDFData)
{
#ifdef _SPECULAR_SETUP
    half reflectivity = ReflectivitySpecular(specular);
    half oneMinusReflectivity = half(1.0) - reflectivity;
    half3 brdfDiffuse = albedo * oneMinusReflectivity;
    half3 brdfSpecular = specular;
#else
    half oneMinusReflectivity = OneMinusReflectivityMetallic(metallic);
    half reflectivity = half(1.0) - oneMinusReflectivity;
    half3 brdfDiffuse = albedo * oneMinusReflectivity;
    half3 brdfSpecular = lerp(kDielectricSpec.rgb, albedo, metallic);
#endif

    InitializeBRDFDataDirect_Toon(albedo, brdfDiffuse, brdfSpecular, reflectivity, oneMinusReflectivity, smoothness, occlusion, sss, subsurface, toonize, alpha, outBRDFData);
}

inline void InitializeBRDFData_Toon(inout SurfaceData_Toon surfaceData, out BRDFData_Toon brdfData)
{
    InitializeBRDFData_Toon(surfaceData.albedo, surfaceData.metallic, surfaceData.specular, surfaceData.smoothness, surfaceData.occlusion, surfaceData.sss, surfaceData.subsurface, surfaceData.toonize, surfaceData.alpha, brdfData);
    brdfData.shadeShift = surfaceData.shadeShift;
    brdfData.toonRampV = surfaceData.toonRampV;
}

// Computes the scalar specular term for Minimalist CookTorrance BRDF
// NOTE: needs to be multiplied with reflectance f0, i.e. specular color to complete
half DirectBRDFSpecular_Toon(BRDFData_Toon brdfData, half3 normalWS, half3 lightDirectionWS, half3 viewDirectionWS)
{
    float3 lightDirectionWSFloat3 = float3(lightDirectionWS);
    float3 halfDir = SafeNormalize(lightDirectionWSFloat3 + float3(viewDirectionWS));

    float NoH = saturate(dot(float3(normalWS), halfDir));
    half LoH = half(saturate(dot(lightDirectionWSFloat3, halfDir)));

    // GGX Distribution multiplied by combined approximation of Visibility and Fresnel
    // BRDFspec = (D * V * F) / 4.0
    // D = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2
    // V * F = 1.0 / ( LoH^2 * (roughness + 0.5) )
    // See "Optimizing PBR for Mobile" from Siggraph 2015 moving mobile graphics course
    // https://community.arm.com/events/1155

    // Final BRDFspec = roughness^2 / ( NoH^2 * (roughness^2 - 1) + 1 )^2 * (LoH^2 * (roughness + 0.5) * 4.0)
    // We further optimize a few light invariant terms
    // brdfData.normalizationTerm = (roughness + 0.5) * 4.0 rewritten as roughness * 4.0 + 2.0 to a fit a MAD.
    float d = NoH * NoH * brdfData.roughness2MinusOne + 1.00001f;

    half LoH2 = LoH * LoH;
    half specularTerm = brdfData.roughness2 / ((d * d) * max(0.1h, LoH2) * brdfData.normalizationTerm);

    // begin toonize
    float maxD = 1 * brdfData.roughness2MinusOne + 1.00001f;
    half maxSpecularTerm = brdfData.roughness2 / ((maxD * maxD) * max(0.1h, 1) * brdfData.normalizationTerm);
    specularTerm = Toonize(specularTerm / maxSpecularTerm, 0.1, brdfData.toonize) * maxSpecularTerm;
    // end toonize

    // On platforms where half actually means something, the denominator has a risk of overflow
    // clamp below was added specifically to "fix" that, but dx compiler (we convert bytecode to metal/gles)
    // sees that specularTerm have only non-negative terms, so it skips max(0,..) in clamp (leaving only min(100,...))
#if REAL_IS_HALF
    specularTerm = specularTerm - HALF_MIN;
    // Update: Conservative bump from 100.0 to 1000.0 to better match the full float specular look.
    // Roughly 65504.0 / 32*2 == 1023.5,
    // or HALF_MAX / ((mobile) MAX_VISIBLE_LIGHTS * 2),
    // to reserve half of the per light range for specular and half for diffuse + indirect + emissive.
    specularTerm = clamp(specularTerm, 0.0, 1000.0); // Prevent FP16 overflow on mobiles
#endif
    return specularTerm;
}

#if defined(LIGHTMAP_ON)
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) float2 lmName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT) OUT.xy = lightmapUV.xy * lightmapScaleOffset.xy + lightmapScaleOffset.zw;
    #define OUTPUT_SH4(absolutePositionWS, normalWS, viewDir, OUT, OUT_OCCLUSION)
    #define OUTPUT_SH(normalWS, OUT)
#else
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) half3 shName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT)
    #ifdef USE_APV_PROBE_OCCLUSION
        #define OUTPUT_SH4(absolutePositionWS, normalWS, viewDir, OUT, OUT_OCCLUSION) OUT.xyz = SampleProbeSHVertex(absolutePositionWS, normalWS, viewDir, OUT_OCCLUSION)
    #else
        #define OUTPUT_SH4(absolutePositionWS, normalWS, viewDir, OUT, OUT_OCCLUSION) OUT.xyz = SampleProbeSHVertex(absolutePositionWS, normalWS, viewDir)
    #endif
    // Note: This is the legacy function, which does not support APV.
    // Kept to avoid breaking shaders still calling it (UUM-37723)
    #define OUTPUT_SH(normalWS, OUT) OUT.xyz = SampleSHVertex(normalWS)
#endif


// Referenced: https://johnaustin.io/articles/2020/fast-subsurface-scattering-for-the-unity-urp
half LightingSubsurface(half NdotL, half subsurfaceRadius)
{
    half alpha = subsurfaceRadius;
    //float theta = max(0, NdotL + alpha) - alpha;
    //half normalization_jgt = (2 + alpha) / (2 * (1 + alpha));
    //half wrapped_jgt = (pow(abs((theta + alpha) / (1 + alpha)), 1 + alpha)) * normalization_jgt;

    //half wrapped_valve = 0.25 * (NdotL + 1) * (NdotL + 1);
    half wrapped_simple = (NdotL + alpha) / (1 + alpha);


    return saturate(wrapped_simple);
}

///////////////////////////////////////////////////////////////////////////////
//                      Lighting Functions                                   //
///////////////////////////////////////////////////////////////////////////////
half3 LightingLambert_Toon(half3 lightColor, half3 lightDir, half3 normal)
{
    half NdotL = saturate(dot(normal, lightDir));
    return lightColor * NdotL;
}

half3 LightingSpecular_Toon(half3 lightColor, half3 lightDir, half3 normal, half3 viewDir, half4 specular, half smoothness)
{
    float3 halfVec = SafeNormalize(float3(lightDir) + float3(viewDir));
    half NdotH = half(saturate(dot(normal, halfVec)));
    half modifier = pow(float(NdotH), float(smoothness)); // Half produces banding, need full precision
    // NOTE: In order to fix internal compiler error on mobile platforms, this needs to be float3
    float3 specularReflection = specular.rgb * modifier;
    return lightColor * specularReflection;
}

half3 LightingPhysicallyBased_Toon(BRDFData_Toon brdfData, BRDFData brdfDataClearCoat,
    half3 lightColor, half3 lightDirectionWS, half distanceAttenuation, half shadowAttenuation,
    half3 normalWS, half3 viewDirectionWS,
    half clearCoatMask, bool specularHighlightsOff)
{
    half lightThreshold = 0.01 - HALF_MIN;
    //distanceAttenuation = toonize(distanceAttenuation, lightThreshold, brdfData.toonize);
    half lightAttenuation =  distanceAttenuation * shadowAttenuation;
    half lightAttenuationSSS = distanceAttenuation;

    half NdotL = saturate(dot(normalWS, lightDirectionWS) + brdfData.shadeShift);

    // begin toonize
    half toonizeNdotL = Toonize(NdotL, _ToonShadeThreshold, brdfData.toonize);
#if defined(_TOON_SHADE_SHIFT)
    toonizeNdotL = lerp(SampleToonRamp(dot(normalWS, lightDirectionWS) + brdfData.shadeShift, brdfData.toonRampV, ToonRampFilterWidth(brdfData, lightDirectionWS)).r, toonizeNdotL, brdfData.toonize);
#endif
    half3 radiance = lightColor * (lightAttenuation * toonizeNdotL);
    // end toonize

    // Subsurface scattering
    half NdotLRaw = dot(normalWS, lightDirectionWS);

    half subsurface = Toonize(LightingSubsurface(NdotLRaw, brdfData.curvature*2), _ToonSubsurfaceThreshold, brdfData.toonize);
    half3 sss = brdfData.sss;
    half3 sssRadiance = lightColor * subsurface * saturate(1 - (lightAttenuation * toonizeNdotL)) * lightAttenuationSSS;

    half3 brdf = brdfData.diffuse;
#ifndef _SPECULARHIGHLIGHTS_OFF
    [branch] if (!specularHighlightsOff)
    {
        half specularPower = DirectBRDFSpecular_Toon(brdfData, normalWS, lightDirectionWS, viewDirectionWS);
        brdf += brdfData.specular * specularPower;

#if defined(_CLEARCOAT) || defined(_CLEARCOATMAP)
        // Clear coat evaluates the specular a second timw and has some common terms with the base specular.
        // We rely on the compiler to merge these and compute them only once.
        half brdfCoat = kDielectricSpec.r * DirectBRDFSpecular_Toon(brdfDataClearCoat, normalWS, lightDirectionWS, viewDirectionWS);

            // Mix clear coat and base layer using khronos glTF recommended formula
            // https://github.com/KhronosGroup/glTF/blob/master/extensions/2.0/Khronos/KHR_materials_clearcoat/README.md
            // Use NoV for direct too instead of LoH as an optimization (NoV is light invariant).
            half NoV = saturate(dot(normalWS, viewDirectionWS));
            // Use slightly simpler fresnelTerm (Pow4 vs Pow5) as a small optimization.
            // It is matching fresnel used in the GI/Env, so should produce a consistent clear coat blend (env vs. direct)
            half coatFresnel = kDielectricSpec.x + kDielectricSpec.a * Pow4(1.0 - NoV);

        brdf = brdf * (1.0 - clearCoatMask * coatFresnel) + brdfCoat * clearCoatMask;
#endif // _CLEARCOAT
    }
#endif // _SPECULARHIGHLIGHTS_OFF

    return (brdf * radiance) * brdfData.occlusion + (sss * sssRadiance) * brdfData.occlusion;
}

half3 LightingPhysicallyBased_Toon(BRDFData_Toon brdfData, BRDFData brdfDataClearCoat, Light light, half3 normalWS, half3 viewDirectionWS, half clearCoatMask, bool specularHighlightsOff)
{
    return LightingPhysicallyBased_Toon(brdfData, brdfDataClearCoat, light.color, light.direction, light.distanceAttenuation, light.shadowAttenuation, normalWS, viewDirectionWS, clearCoatMask, specularHighlightsOff);
}

// Backwards compatibility
half3 LightingPhysicallyBased_Toon(BRDFData_Toon brdfData, Light light, half3 normalWS, half3 viewDirectionWS)
{
    #ifdef _SPECULARHIGHLIGHTS_OFF
    bool specularHighlightsOff = true;
#else
    bool specularHighlightsOff = false;
#endif
    const BRDFData noClearCoat = (BRDFData)0;
    return LightingPhysicallyBased_Toon(brdfData, noClearCoat, light, normalWS, viewDirectionWS, 0.0, specularHighlightsOff);
}

half3 LightingPhysicallyBased_Toon(BRDFData_Toon brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS)
{
    Light light;
    light.color = lightColor;
    light.direction = lightDirectionWS;
    light.distanceAttenuation = lightAttenuation;
    light.shadowAttenuation   = 1;
    return LightingPhysicallyBased_Toon(brdfData, light, normalWS, viewDirectionWS);
}

half3 LightingPhysicallyBased_Toon(BRDFData_Toon brdfData, Light light, half3 normalWS, half3 viewDirectionWS, bool specularHighlightsOff)
{
    const BRDFData noClearCoat = (BRDFData)0;
    return LightingPhysicallyBased_Toon(brdfData, noClearCoat, light, normalWS, viewDirectionWS, 0.0, specularHighlightsOff);
}

half3 LightingPhysicallyBased_Toon(BRDFData_Toon brdfData, half3 lightColor, half3 lightDirectionWS, half lightAttenuation, half3 normalWS, half3 viewDirectionWS, bool specularHighlightsOff)
{
    Light light;
    light.color = lightColor;
    light.direction = lightDirectionWS;
    light.distanceAttenuation = lightAttenuation;
    light.shadowAttenuation   = 1;
    return LightingPhysicallyBased_Toon(brdfData, light, viewDirectionWS, specularHighlightsOff, specularHighlightsOff);
}

half3 VertexLighting_Toon(float3 positionWS, half3 normalWS)
{
    half3 vertexLightColor = half3(0.0, 0.0, 0.0);

#ifdef _ADDITIONAL_LIGHTS_VERTEX
    uint lightsCount = GetAdditionalLightsCount();
    uint meshRenderingLayers = GetMeshRenderingLayer();

    LIGHT_LOOP_BEGIN(lightsCount)
        Light light = GetAdditionalLight(lightIndex, positionWS);
        light.distanceAttenuation *= ToonLightSourceRadiusFactor(lightIndex, positionWS);

#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
    {
        half3 lightColor = light.color * light.distanceAttenuation;
        vertexLightColor += LightingLambert(lightColor, light.direction, normalWS);
    }

    LIGHT_LOOP_END
#endif

    return vertexLightColor;
}

struct LightingData_Toon
{
    half3 giColor;
    half3 mainLightColor;
    half3 additionalLightsColor;
    half3 vertexLightingColor;
    half3 emissionColor;
};

half3 CalculateLightingColor_Toon(LightingData lightingData, half3 albedo)
{
    half3 lightingColor = 0;

    if (IsOnlyAOLightingFeatureEnabled())
    {
        return lightingData.giColor; // Contains white + AO
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_GLOBAL_ILLUMINATION))
    {
        lightingColor += lightingData.giColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_MAIN_LIGHT))
    {
        lightingColor += lightingData.mainLightColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_ADDITIONAL_LIGHTS))
    {
        lightingColor += lightingData.additionalLightsColor;
    }

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_VERTEX_LIGHTING))
    {
        lightingColor += lightingData.vertexLightingColor;
    }

    lightingColor *= albedo;

    if (IsLightingFeatureEnabled(DEBUGLIGHTINGFEATUREFLAGS_EMISSION))
    {
        lightingColor += lightingData.emissionColor;
    }

    return lightingColor;
}

half4 CalculateFinalColor_Toon(LightingData lightingData, half alpha)
{
    half3 finalColor = CalculateLightingColor_Toon(lightingData, 1);

    return half4(finalColor, alpha);
}



LightingData CreateLightingData_Toon(InputData inputData, SurfaceData_Toon surfaceData)
{
    LightingData lightingData;

    lightingData.giColor = inputData.bakedGI;
    lightingData.emissionColor = surfaceData.emission;
    lightingData.vertexLightingColor = 0;
    lightingData.mainLightColor = 0;
    lightingData.additionalLightsColor = 0;

    return lightingData;
}




///////////////////////////////////////////////////////////////////////////////
//                      Fragment Functions                                   //
//       Used by ShaderGraph and others builtin renderers                    //
///////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// PBR lighting...
////////////////////////////////////////////////////////////////////////////////
half4 UniversalFragmentPBR_Toon(InputData inputData, SurfaceData_Toon surfaceData, out half3 outlineColor)
{
    #if defined(_SPECULARHIGHLIGHTS_OFF)
    bool specularHighlightsOff = true;
    #else
    bool specularHighlightsOff = false;
    #endif
    BRDFData_Toon brdfData;

    // NOTE: can modify "surfaceData"...
    InitializeBRDFData_Toon(surfaceData, brdfData);
#if defined(_TOON_SHADE_SHIFT)
    brdfData.normalDdx = ddx(float3(inputData.normalWS));
    brdfData.normalDdy = ddy(float3(inputData.normalWS));
    brdfData.shadeShiftDdx = ddx(float(brdfData.shadeShift));
    brdfData.shadeShiftDdy = ddy(float(brdfData.shadeShift));
#endif

    #if defined(DEBUG_DISPLAY)
    half4 debugColor;

    if (CanDebugOverrideOutputColor(inputData, surfaceData, brdfData, debugColor))
    {
        return debugColor;
    }
    #endif

    // Clear-coat calculation...
    BRDFData brdfDataClearCoat = CreateClearCoatBRDFData((SurfaceData)surfaceData, (BRDFData)brdfData);
    half4 shadowMask = CalculateShadowMask(inputData);
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, (SurfaceData)surfaceData);
    uint meshRenderingLayers = GetMeshRenderingLayer();
    Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

    // NOTE: We don't apply AO to the GI here because it's done in the lighting calculation below...
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI);

    LightingData lightingData = CreateLightingData_Toon(inputData, surfaceData);


    lightingData.giColor = GlobalIllumination_Toon(brdfData, brdfDataClearCoat, surfaceData.clearCoatMask,
                                              inputData.bakedGI, aoFactor.indirectAmbientOcclusion, inputData.positionWS,
                                              inputData.normalWS, inputData.viewDirectionWS, inputData.normalizedScreenSpaceUV) * lerp(brdfData.occlusion, 0.5, 0.5);
#ifdef _LIGHT_LAYERS
    if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
#endif
    {
        lightingData.mainLightColor = LightingPhysicallyBased_Toon(brdfData, brdfDataClearCoat,
                                                              mainLight,
                                                              inputData.normalWS, inputData.viewDirectionWS,
                                                              surfaceData.clearCoatMask, specularHighlightsOff);
    }

    //#if defined(_ADDITIONAL_LIGHTS)  // support defferd rendering
    uint pixelLightCount = GetAdditionalLightsCount();

    #if USE_CLUSTER_LIGHT_LOOP
    [loop] for (uint lightIndex = 0; lightIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); lightIndex++)
    {
        CLUSTER_LIGHT_LOOP_SUBTRACTIVE_LIGHT_CHECK

        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_Toon(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    }
    #endif

    LIGHT_LOOP_BEGIN(pixelLightCount)
        Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
        light.distanceAttenuation *= ToonLightSourceRadiusFactor(lightIndex, inputData.positionWS);

#ifdef _LIGHT_LAYERS
        if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
#endif
        {
            lightingData.additionalLightsColor += LightingPhysicallyBased_Toon(brdfData, brdfDataClearCoat, light,
                                                                          inputData.normalWS, inputData.viewDirectionWS,
                                                                          surfaceData.clearCoatMask, specularHighlightsOff);
        }
    LIGHT_LOOP_END
    //#endif


    #if defined(_ADDITIONAL_LIGHTS_VERTEX)
    lightingData.vertexLightingColor += inputData.vertexLighting * brdfData.diffuse;
    #endif

    outlineColor = lightingData.giColor;

#if defined(_TOON_SHADE_SHIFT)
    // 環境光とメインライト(SSS)の倍率はランプの G で決まる。メインライトの N・L に影マップのずれを足した値で引く
    half shadeDarken = lerp(SampleToonRamp(dot(inputData.normalWS, mainLight.direction) + brdfData.shadeShift, brdfData.toonRampV, ToonRampFilterWidth(brdfData, mainLight.direction)).g, half(1.0), brdfData.toonize);
    lightingData.giColor *= shadeDarken;
    lightingData.mainLightColor *= shadeDarken;
#endif

#if REAL_IS_HALF
    // Clamp any half.inf+ to HALF_MAX
    return min(CalculateFinalColor_Toon(lightingData, surfaceData.alpha), HALF_MAX);
#else
    return CalculateFinalColor_Toon(lightingData, surfaceData.alpha);
#endif
    
}

// Deprecated: Use the version which takes "SurfaceData" instead of passing all of these arguments...
half4 UniversalFragmentPBR_Toon(InputData inputData, half3 albedo, half metallic, half3 specular,
    half smoothness, half occlusion, half3 emission, half alpha, half toonize, half3 sss, half subsurface, half shadeShift, out half3 outlineColor)
{
    SurfaceData_Toon surfaceData;

    surfaceData.albedo = albedo;
    surfaceData.specular = specular;
    surfaceData.metallic = metallic;
    surfaceData.smoothness = smoothness;
    surfaceData.normalTS = half3(0, 0, 1);
    surfaceData.emission = emission;
    surfaceData.occlusion = occlusion;
    surfaceData.alpha = alpha;
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 1;

    surfaceData.toonize = toonize;
    surfaceData.sss = sss.rgb * surfaceData.albedo;
    surfaceData.subsurface = subsurface;
    surfaceData.shadeShift = shadeShift;
    surfaceData.toonRampV = 0;

    return UniversalFragmentPBR_Toon(inputData, surfaceData, outlineColor);
}




///////////////////////////////////////////////////////////////////////////////
//                      Fragment Functions                                   //
//       Used by ShaderGraph and others builtin renderers                    //
///////////////////////////////////////////////////////////////////////////////
half4 UniversalFragmentToon(
    InputData inputData, half3 diffuse, half4 sss,
    half metallic, half3 specular, half occlusion, half smoothness, half3 emission, half alpha, 
    half shadowShift, half shadeShift,half shadeToony, 
    half curvature, Texture2D shadeRamp, 
    half toonyLighing, 
    out half3 outlineColor)
{
#if defined(_TOON_SHADE_SHIFT)
    half appliedShadeShift = shadeShift;
#else
    // 他のシェーダーは ShadeShift にそれぞれ別の意味の値を流しているので使わない
    half appliedShadeShift = 0;
#endif
    half4 color = UniversalFragmentPBR_Toon(inputData, diffuse, metallic, specular, smoothness, occlusion, emission, alpha, toonyLighing, sss.rgb, sss.a, appliedShadeShift, outlineColor);
    return color;
}


#endif
