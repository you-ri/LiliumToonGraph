//
// based on: com.unity.render-pipelines.universal@7.1.2\Editor\ShaderGraph\Includes\PBRForwardPass.hlsl
//
void BuildInputData(Varyings input, float3 normal, out InputData inputData)
{
    inputData.positionWS = input.positionWS;
#ifdef _NORMALMAP
    inputData.normalWS = TransformTangentToWorld(normal,
        half3x3(input.tangentWS.xyz, input.bitangentWS.xyz, input.normalWS.xyz));
#else
    inputData.normalWS = input.normalWS;
#endif
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = SafeNormalize(input.viewDirectionWS);
    inputData.shadowCoord = input.shadowCoord;
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.sh, inputData.normalWS);
}

PackedVaryings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    output = BuildVaryings(input);
    PackedVaryings packedOutput = (PackedVaryings)0;
    packedOutput = PackVaryings(output);
    return packedOutput;
}

half4 frag(PackedVaryings packedInput) : SV_TARGET 
{    
    Varyings unpacked = UnpackVaryings(packedInput);
    UNITY_SETUP_INSTANCE_ID(unpacked);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(unpacked);

    SurfaceDescriptionInputs surfaceDescriptionInputs = BuildSurfaceDescriptionInputs(unpacked);
    SurfaceDescription surfaceDescription = SurfaceDescriptionFunction(surfaceDescriptionInputs);

    #if _AlphaClip
        clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
    #endif

    InputData inputData;
    BuildInputData(unpacked, surfaceDescription.Normal, inputData);

    #ifdef _SPECULAR_SETUP
        float3 specular = surfaceDescription.Specular;
        float metallic = 1;
    #else   
        float3 specular = 0;
        float metallic = surfaceDescription.Metallic;
    #endif

    // 均一なGI情報を取得
    inputData.bakedGI = SAMPLE_OMNIDIRECTIONAL_GI(inputData.lightmapUV, unpacked.sh);

    half4 color = UniversalFragmentToon(
			inputData,
			surfaceDescription.Albedo,
			surfaceDescription.Shade,
			metallic,
			specular,
			surfaceDescription.Occlusion,
			surfaceDescription.Smoothness,
			surfaceDescription.Emission,
			surfaceDescription.Alpha,
			surfaceDescription.ShadeShift,
			surfaceDescription.ShadeToony,
            surfaceDescription.ToonyLighting);

    // PBR カラー計算
    // TODO: UniversalFragmentToonに統合。
    Light mainLight = GetMainLight(inputData.shadowCoord);
    half lighing = dot(inputData.normalWS, mainLight.direction) * mainLight.shadowAttenuation * mainLight.distanceAttenuation;
    half3 giLighinting = inputData.bakedGI;
    half3 sssEmmisionColor = ((surfaceDescription.Shade - surfaceDescription.Albedo) * giLighinting * surfaceDescription.Occlusion) * (1 - lighing);
    half4 pbrColor = UniversalFragmentPBR(
			inputData,
			surfaceDescription.Albedo / (1 - specular),
			metallic,
			specular,
			surfaceDescription.Smoothness,
			surfaceDescription.Occlusion,
			surfaceDescription.Emission + sssEmmisionColor,
			surfaceDescription.Alpha); 

    color = lerp(pbrColor, color, surfaceDescription.ToonyLighting);
    color.rgb = MixFog(color.rgb, inputData.fogCoord); 
    return color;
}
