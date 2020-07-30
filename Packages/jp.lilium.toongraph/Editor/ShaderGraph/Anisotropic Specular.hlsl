//
// Reference https://blog.csdn.net/noahzuo/article/details/51162472
// 
#ifndef UNIVERSAL_TOONLIGHTING_ANISOTROPIC_INCLUDED
#define UNIVERSAL_TOONLIGHTING_ANISOTROPIC_INCLUDED



half3 ShiftTangent(half3 T, half3 N, half shift)
{
    half3 shiftedT = T + (shift * N);
    return normalize(shiftedT);
}

half StrandSpecular(half3 T, half3 V, half3 L, half exponent)
{
    half3 H = normalize(L + V);
    half dotTH = dot(T, H);
    half sinTH = sqrt(1.0 - dotTH*dotTH);
    half dirAtten = smoothstep(-1.0, 0.0, dotTH);
    return dirAtten * pow(sinTH, exponent);
}


half HairLighting(half3 tangent, half3 normal, half3 lightDirection, half3 viewDirection, 
                  half specularIntensity, half secondarySpecularIntensity, half primaryShift, half secondaryShift, half primaryExponent, half secondaryExponent)
{
    // shift tangents
    half3 t1 = ShiftTangent(tangent, normal, primaryShift);
    half3 t2 = ShiftTangent(tangent, normal, secondaryShift);

    // specular lighting
    half intensity = StrandSpecular(t1, viewDirection, lightDirection, primaryExponent) * specularIntensity;
    // add second specular term
    intensity += StrandSpecular(t2, viewDirection, lightDirection, secondaryExponent) * secondarySpecularIntensity;

    return intensity;
}

#if !SHADERGRAPH_PREVIEW

void KajiyaKayAnisotropicIntensity_half(
    half3 Normal, half3 Tangent, half3 WorldView, half Shift, half PrimaryExponent, half SecondaryExponent, 
    out half3 Color)
{
    Light mainLight = GetMainLight();

    Color = (HairLighting (Tangent, Normal, mainLight.direction, WorldView, 1, 1, Shift, Shift, PrimaryExponent, SecondaryExponent) * mainLight.distanceAttenuation * mainLight.shadowAttenuation) * mainLight.color;
}

#else

void KajiyaKayAnisotropicIntensity_half(
    half3 Normal, half3 Tangent, half3 WorldView, half Shift, half PrimaryExponent, half SecondaryExponent, 
    out half3 Color)
{
    Color = HairLighting (Tangent, Normal, half3(0, 1, -1), WorldView, 1, 1, Shift, Shift, PrimaryExponent, SecondaryExponent);
}

#endif

#endif