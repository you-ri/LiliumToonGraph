#ifndef LILIUM_TOONSTYLEZE_NCLUDED
#define LILIUM_TOONSTYLEZE_NCLUDED

// o = s + l
// albedo = sss*s + base*o;
// shade = sss*s + base*s
// sss = shade/s - base;
//----------------
//----------------
// base = shade/s - sss
// sss = (albedo - base*l) / s
// base = (shade/s) - ((abled - base*l) / s)
// base = (shade - (albedo - base*l)) / s
// base = (shade - albedo + base*l) / s
// base = (shade - albedo) / s + base*l / s
// base - base*l / s = (shade - albedo) / s
// (1-l/s) * base  = (shade - albedo) / s
// base = (shade - albedo) / s / (1-l/s)


//
void ToonStylizing_half(half3 Base, half3 Shade, half3 AmibentReference, out half3 Albedo, out half3 SSS)
{
    half l = AmibentReference.r;
    half s = FastSRGBToLinear(1 - FastLinearToSRGB(l)); 

    Albedo = (Shade.rgb - Base) / s / (1-(s+l)/s);
    SSS = Shade.rgb/s - Albedo;
}

void ToonStylizing_float(float3 Base, float3 Shade, float3 AmibentReference, out float3 Albedo, out float3 SSS)
{
    float l = AmibentReference.r;
    float s = FastSRGBToLinear(1 - FastLinearToSRGB(l)); 

    Albedo = (Shade.rgb - Base) / s / (1-(s+l)/s);
    SSS = Shade.rgb/s - Albedo;
} 

#endif