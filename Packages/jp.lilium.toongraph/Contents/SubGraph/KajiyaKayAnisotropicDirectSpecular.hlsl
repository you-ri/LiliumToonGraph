//
// Reference https://blog.csdn.net/noahzuo/article/details/51162472
// 
#ifndef LILIUM_KAJIYAKAY_ANISOTROPIC_INCLUDED
#define LILIUM_KAJIYAKAY_ANISOTROPIC_INCLUDED

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

half KajiyaKayAnisotropicDirectSpecular(half3 tangent, half3 normal, half3 lightDirection, half3 viewDirection, 
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

void KajiyaKayAnisotropicDirectSpecular_half(
    half3 LightDirection, half3 Normal, half3 Tangent, half3 WorldView, half Shift, half PrimaryExponent, half SecondaryExponent, 
    out half intensity)
{
    intensity = KajiyaKayAnisotropicDirectSpecular (Tangent, Normal, LightDirection, WorldView, 0.5h, 0.5h, Shift, Shift, PrimaryExponent, SecondaryExponent);
}

#endif