#ifndef LILIUM_TRANSLUCENT_NCLUDED
#define LILIUM_TRANSLUCENT_NCLUDED

//
// Reference: https://www.alanzucconi.com/2017/08/30/fast-subsurface-scattering-1/
//
//#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"

inline half ToonyValue(half value, half oneMinusShadeToony, half toonyLighting, half threshold = 0.5h)
{
  return 
    lerp(
      value, 
      smoothstep(
        threshold - (oneMinusShadeToony/2), 
        threshold + (oneMinusShadeToony/2), 
        value),
      toonyLighting);
}


inline half3 LightingToon(
  half3 V, half3 N, half3 LightDirection, half3 LightColor, half LightDistanceAtten, 
  half _Distortion, half _Power, half _Scale, half thickness, half _Ambient,
  half shadeToony, half toonyLighting)
{
  // --- Translucency ---
  half3 L = LightDirection;

  half3 H = normalize(L + N * _Distortion);
  half VdotH = saturate(dot(V, -H));
  half ToonedVdotH = ToonyValue(VdotH, shadeToony, toonyLighting);
  half intensity = pow(ToonedVdotH, _Power) * _Scale;

  half3 I = LightColor * LightDistanceAtten * (intensity + _Ambient) * thickness; 
  return I;
}

#include "mainlight.hlsl"

void TranslucentLighting_half (
  half3 WorldPos, half3 ViewDir, half3 Normal, half3 _Ambient, 
  half thickness, half _Distortion, half _Power, half _Scale,
  half shadeToony, half toonyLighting,
  out half3 Color)
{

  half3 LightDirection;
  half3 LightColor;
  half LightDistanceAtten;
  half LightShadowAtten;
  MainLight_half(WorldPos,  LightDirection,  LightColor,  LightDistanceAtten,  LightShadowAtten);

  half3 color;
  color = LightingToon(
    ViewDir, Normal, LightDirection, LightColor, LightDistanceAtten, 
    _Distortion, _Power, _Scale, 
    thickness, _Ambient,
    1-shadeToony, toonyLighting);

#ifdef _ADDITIONAL_LIGHTS
    int pixelLightCount = GetAdditionalLightsCount();
    for (int i = 0; i < pixelLightCount; ++i)
    {
        Light light = GetAdditionalLight(i, WorldPos);
        color += LightingToon(
          ViewDir, Normal, light.direction, light.color, light.distanceAttenuation,
          _Distortion, _Power, _Scale, 
          thickness, _Ambient,
          1-shadeToony, toonyLighting);
    }
#endif

  Color = color;
}

/*
inline fixed4 LightingStandardTranslucent(SurfaceOutputStandard s, fixed3 viewDir, UnityGI gi)
{
    // Original colour
    fixed4 pbr = LightingStandard(s, viewDir, gi);
    
    // --- Translucency ---
    float3 L = gi.light.dir;
    float3 V = viewDir;
    float3 N = s.Normal;
    
    float3 H = normalize(L + N * _Distortion);
    float VdotH = pow(saturate(dot(V, -H)), _Power) * _Scale;
    float3 I = _Attenuation * (VdotH + _Ambient) * thickness;
    
    // Final add
    pbr.rgb = pbr.rgb + gi.light.color * I;
    return pbr;
}
*/

#endif