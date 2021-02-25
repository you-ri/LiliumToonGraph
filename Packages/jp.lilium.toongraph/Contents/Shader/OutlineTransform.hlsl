//
// based on: com.unity.render-pipelines.universal@7.1.2\Editor\ShaderGraph\Includes\PBRForwardPass.hlsl
// referenced: MToon Copyright (c) 2018 Masataka SUMI https://github.com/Santarh/MToon
//
#ifndef LILIUM_OUTLINETRANSFORM
#define LILIUM_OUTLINETRANSFORM

//#define LILIUM_OUTLINE_SCREENSPACE


float4x4 inverse(float4x4 m)
{
    float n11 = m[0][0], n12 = m[1][0], n13 = m[2][0], n14 = m[3][0];
    float n21 = m[0][1], n22 = m[1][1], n23 = m[2][1], n24 = m[3][1];
    float n31 = m[0][2], n32 = m[1][2], n33 = m[2][2], n34 = m[3][2];
    float n41 = m[0][3], n42 = m[1][3], n43 = m[2][3], n44 = m[3][3];

    float t11 = n23 * n34 * n42 - n24 * n33 * n42 + n24 * n32 * n43 - n22 * n34 * n43 - n23 * n32 * n44 + n22 * n33 * n44;
    float t12 = n14 * n33 * n42 - n13 * n34 * n42 - n14 * n32 * n43 + n12 * n34 * n43 + n13 * n32 * n44 - n12 * n33 * n44;
    float t13 = n13 * n24 * n42 - n14 * n23 * n42 + n14 * n22 * n43 - n12 * n24 * n43 - n13 * n22 * n44 + n12 * n23 * n44;
    float t14 = n14 * n23 * n32 - n13 * n24 * n32 - n14 * n22 * n33 + n12 * n24 * n33 + n13 * n22 * n34 - n12 * n23 * n34;

    float det = n11 * t11 + n21 * t12 + n31 * t13 + n41 * t14;
    float idet = 1.0f / det;

    float4x4 ret;

    ret[0][0] = t11 * idet;
    ret[0][1] = (n24 * n33 * n41 - n23 * n34 * n41 - n24 * n31 * n43 + n21 * n34 * n43 + n23 * n31 * n44 - n21 * n33 * n44) * idet;
    ret[0][2] = (n22 * n34 * n41 - n24 * n32 * n41 + n24 * n31 * n42 - n21 * n34 * n42 - n22 * n31 * n44 + n21 * n32 * n44) * idet;
    ret[0][3] = (n23 * n32 * n41 - n22 * n33 * n41 - n23 * n31 * n42 + n21 * n33 * n42 + n22 * n31 * n43 - n21 * n32 * n43) * idet;

    ret[1][0] = t12 * idet;
    ret[1][1] = (n13 * n34 * n41 - n14 * n33 * n41 + n14 * n31 * n43 - n11 * n34 * n43 - n13 * n31 * n44 + n11 * n33 * n44) * idet;
    ret[1][2] = (n14 * n32 * n41 - n12 * n34 * n41 - n14 * n31 * n42 + n11 * n34 * n42 + n12 * n31 * n44 - n11 * n32 * n44) * idet;
    ret[1][3] = (n12 * n33 * n41 - n13 * n32 * n41 + n13 * n31 * n42 - n11 * n33 * n42 - n12 * n31 * n43 + n11 * n32 * n43) * idet;

    ret[2][0] = t13 * idet;
    ret[2][1] = (n14 * n23 * n41 - n13 * n24 * n41 - n14 * n21 * n43 + n11 * n24 * n43 + n13 * n21 * n44 - n11 * n23 * n44) * idet;
    ret[2][2] = (n12 * n24 * n41 - n14 * n22 * n41 + n14 * n21 * n42 - n11 * n24 * n42 - n12 * n21 * n44 + n11 * n22 * n44) * idet;
    ret[2][3] = (n13 * n22 * n41 - n12 * n23 * n41 - n13 * n21 * n42 + n11 * n23 * n42 + n12 * n21 * n43 - n11 * n22 * n43) * idet;

    ret[3][0] = t14 * idet;
    ret[3][1] = (n13 * n24 * n31 - n14 * n23 * n31 + n14 * n21 * n33 - n11 * n24 * n33 - n13 * n21 * n34 + n11 * n23 * n34) * idet;
    ret[3][2] = (n14 * n22 * n31 - n12 * n24 * n31 - n14 * n21 * n32 + n11 * n24 * n32 + n12 * n21 * n34 - n11 * n22 * n34) * idet;
    ret[3][3] = (n12 * n23 * n31 - n13 * n22 * n31 + n13 * n21 * n32 - n11 * n23 * n32 - n12 * n21 * n33 + n11 * n22 * n33) * idet;

    return ret;
}


inline half aspect()
{
    half4 nearUpperRight = mul(inverse(UNITY_MATRIX_P), half4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));
    return abs(nearUpperRight.y / nearUpperRight.x);
}

inline half3 TransformViewToProjection(half3 v)
{
    return mul((float3x3) UNITY_MATRIX_P, v);
}

void TransformOutlineToHClipScreenSpace_half(half3 position, half3 normal, half outlineWidth, half OutlineScaledMaxDistance, out half3 outlinePosition)
{    
    half4 vertex = mul(UNITY_MATRIX_MVP, half4(position, 1.0));
    half3 viewNormal = mul((float3x3) UNITY_MATRIX_MV, normal.xyz);
    half3 clipNormal = TransformViewToProjection(viewNormal.xyz);
    half2 projectedNormal = normalize(clipNormal.xy);
    projectedNormal *= min(vertex.w, OutlineScaledMaxDistance * abs(UNITY_MATRIX_P._m11));
    projectedNormal.x *= aspect();
    vertex.xy += 0.01 * outlineWidth * projectedNormal.xy* saturate(1 - abs(normalize(viewNormal).z));

    outlinePosition = vertex.xyz;
}



void TransformOutlineToHClipScreenSpace_float(float3 position, float3 normal, float outlineWidth, float OutlineScaledMaxDistance, out float3 outlinePosition)
{    
    float4 vertex = mul(UNITY_MATRIX_MVP, float4(position, 1.0));
    float3 viewNormal = mul((float3x3) UNITY_MATRIX_MV, normal.xyz);
    float3 clipNormal = TransformViewToProjection(viewNormal.xyz);
    float2 projectedNormal = normalize(clipNormal.xy);
    projectedNormal *= min(vertex.w, OutlineScaledMaxDistance * abs(UNITY_MATRIX_P._m11));
    projectedNormal.x *= aspect();
    vertex.xy += 0.01 * outlineWidth * projectedNormal.xy* saturate(1 - abs(normalize(viewNormal).z));

    outlinePosition = mul( inverse(UNITY_MATRIX_MVP), vertex).xyz;
}

// アウトライン処理
// スタンダード
void TransformOutline_float(float3 Position, float3 Normal, float OutlineWidth, out float3 OutlinePosition)
{    
    // outline size scale. mm to meter.
    Position.xyz += 0.001 * OutlineWidth * Normal.xyz;

    OutlinePosition = Position;
}


// アウトライン処理
// UTS2互換
void TransformOutlineUTS2_float(float3 Position, float3 Normal, float OutlineWidth, float NearestDistance, float FarthestDistance, out float3 OutlinePosition)
{    
    float4 vertex = mul(unity_ObjectToWorld, half4(Position, 1.0));    
    
    OutlineWidth *= smoothstep(FarthestDistance, NearestDistance, distance(vertex, _WorldSpaceCameraPos));
    
    // outline size scale. mm to meter.
    Position.xyz += 0.001 * OutlineWidth * Normal.xyz;

    OutlinePosition = Position;
}


// アウトライン処理
// MToon互換
void TransformOutlineScaledMaxDistance_float(float3 Position, float3 Normal, float OutlineWidth, float WidthScaledMaxDistance, out float3 OutlinePosition)
{    
    float4 vertex = mul(UNITY_MATRIX_MVP, float4(Position, 1.0));
    
    OutlineWidth *= min(vertex.w * (1 / WidthScaledMaxDistance), 1);
    
    // outline size scale. mm to meter.
    Position.xyz += 0.001 * OutlineWidth * Normal.xyz;

    OutlinePosition = Position;
}


#endif