//
//
#ifndef UNIVERSAL_TOONLIGHTING_ANISOTROPIC_INCLUDED
#define UNIVERSAL_TOONLIGHTING_ANISOTROPIC_INCLUDED

#if !SHADERGRAPH_PREVIEW


// カスタムファンクション
void AnisotropicSpecular_half(
    half4 AnisoDir, half AnisoOffset, half Gloss, half3 Normal, half3 WorldView, half3 Specular,
    out half4 Color)
{
    Light mainLight = GetMainLight();

    half3 h = normalize(normalize(mainLight.direction) + normalize(WorldView));
    float NdotL = saturate(dot(Normal, mainLight.direction));
    
    half HdotA = dot(normalize(Normal + AnisoDir.rgb), h);
    float aniso = max(0, sin(radians((HdotA + AnisoOffset) * 180)));
    
    float spec = saturate(dot(Normal, h));
    spec = saturate(pow(lerp(spec, aniso, 1), Gloss * 128));

    Color.rgb = (mainLight.color * spec * Specular); // * (1 * 2);
    Color.a = 1;
}


#else

// カスタムファンクション
void AnisotropicSpecular_half(
    half4 AnisoDir, half AnisoOffset, half Gloss, half3 Normal, half3 WorldView, half3 Specular,
    out half4 Color)
{
    Color = half4(Specular, 0);
}

#endif

#endif