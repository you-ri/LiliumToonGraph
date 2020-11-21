#ifndef LILIUM_TOONSTYLEZE_NCLUDED
#define LILIUM_TOONSTYLEZE_NCLUDED


// o = s + l
// base = albedo
// shade = sss*s + albedo*s
//----------------
// sss = shade/s - albedo;



// nl ... normal intensity
// dl ... direct light intensity
// il ... indirect light intensity
//----------------
// nl = dl + il
// albedo = shade/dl - sss
// shade = sss*dl + albedo*dl
//----------------
// base = sss*s + albedo*nl;
// sss = shade/s - albedo;
//----------------
// sss = (base - albedo*il) / dl
// albedo = (shade/dl) - ((abledo2 - albedo*il) / dl)
// albedo = (shade - (base - albedo*il)) / dl
// albedo = (shade - base + albedo*il) / dl
// albedo = (shade - base) / dl + albedo*il / dl
// albedo - albedo*il / dl = (shade - base) / dl
// (1-il/dl) * albedo  = (shade - base) / dl
// albedo = (shade - base) / dl / (1-il/dl)


//
void ToonStylizing_half(half3 Base, half3 Shade, half3 AmibentReference, out half3 Albedo, out half3 SSS)
{
    half il = AmibentReference.r;
    half dl = FastSRGBToLinear(1 - FastLinearToSRGB(il)); 

    Albedo = Base; //(Shade - Base) / dl / (1-il/dl);
    SSS =  Shade - AmibentReference;
    //Albedo = Base;
    //SSS = half3(0, 0, 1);
}

void ToonStylizing_float(float3 Base, float3 Shade, float3 AmibentReference, out float3 Albedo, out float3 SSS)
{
    float il = AmibentReference.r;
    float dl = FastSRGBToLinear(1 - FastLinearToSRGB(il)); 

    Albedo = (Shade - Base) / dl / (1-il/dl);
    SSS = Shade/il - Albedo;
    Albedo = Base;
} 

#endif