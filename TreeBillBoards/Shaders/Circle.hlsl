//***************************************************************************************
// TreeSprite.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//***************************************************************************************

// Defaults for number of lights.
#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 3
#endif

#ifndef NUM_POINT_LIGHTS
    #define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
    #define NUM_SPOT_LIGHTS 0
#endif

// Include structures and functions for lighting.
#include "LightingUtil.hlsl"

Texture2D gDiffuseMap : register(t0);


SamplerState gsamPointWrap        : register(s0);
SamplerState gsamPointClamp       : register(s1);
SamplerState gsamLinearWrap       : register(s2);
SamplerState gsamLinearClamp      : register(s3);
SamplerState gsamAnisotropicWrap  : register(s4);
SamplerState gsamAnisotropicClamp : register(s5);

// Constant data that varies per frame.
cbuffer cbPerObject : register(b0)
{
    float4x4 gWorld;
	float4x4 gTexTransform;
};

// Constant data that varies per material.
cbuffer cbPass : register(b1)
{
    float4x4 gView;
    float4x4 gInvView;
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gViewProj;
    float4x4 gInvViewProj;
    float3 gEyePosW;
    float cbPerObjectPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
    float4 gAmbientLight;

	float4 gFogColor;
	float gFogStart;
	float gFogRange;
	float2 cbPerObjectPad2;

    // Indices [0, NUM_DIR_LIGHTS) are directional lights;
    // indices [NUM_DIR_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHTS) are point lights;
    // indices [NUM_DIR_LIGHTS+NUM_POINT_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHT+NUM_SPOT_LIGHTS)
    // are spot lights for a maximum of MaxLights per object.
    Light gLights[MaxLights];
};

cbuffer cbMaterial : register(b2)
{
	float4   gDiffuseAlbedo;
    float3   gFresnelR0;
    float    gRoughness;
	float4x4 gMatTransform;
};
 
struct VertexIn
{
	float3 PosL  : POSITION;
    float3 NormalL : NORMAL;
    float2 TexC : TEXCOORD;
};

struct VertexOut
{
    float3 PosL : POSITION;
    float3 NormalL : NORMAL;
    float2 TexC : TEXCOORD;
};

struct GeoOut
{
    float3 PosW : POSITION;
	float4 PosH    : SV_POSITION;
    float3 NormalW : NORMAL;
    float2 TexC    : TEXCOORD;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout;

	// Just pass data over to geometry shader.
    vout.PosL = vin.PosL;
    vout.NormalL = vin.NormalL;
    vout.TexC = vin.TexC;

	return vout;
}
 
 // We expand each point into a quad (4 vertices), so the maximum number of vertices
 // we output per geometry shader invocation is 4.
[maxvertexcount(4)]
void GS(line VertexOut gin[2], 
        inout TriangleStream<GeoOut> triStream)
{	
    float3 up = float3(0.0f, 1.0f, 0.0f);
    
	float4 v[4];
	v[0] = float4(gin[0].PosL, 1.0f);
	v[1] = float4(gin[1].PosL, 1.0f);
    v[2] = float4(gin[1].PosL + up * 10.0f, 1.0f);
    v[3] = float4(gin[0].PosL + up * 10.0f, 1.0f);
	
	GeoOut gout;
    gout.PosW = mul(v[1], gWorld).xyz;
    gout.PosH = mul(mul(v[1], gWorld), gViewProj);
    gout.NormalW = gin[0].NormalL;
    gout.TexC = float2(gin[1].TexC.x, 0.0f);
    triStream.Append(gout);
    
    gout.PosW = mul(v[0], gWorld).xyz;
    gout.PosH = mul(mul(v[0], gWorld), gViewProj);
    gout.NormalW = gin[0].NormalL;
    gout.TexC = float2(gin[0].TexC.x, 0.0f);
    triStream.Append(gout);
    
    gout.PosW = mul(v[2], gWorld).xyz;
    gout.PosH = mul(mul(v[2], gWorld), gViewProj);
    gout.NormalW = gin[0].NormalL;
    gout.TexC = float2(gin[1].TexC.x, 1.0f);
    triStream.Append(gout);
   
    gout.PosW = mul(v[3], gWorld).xyz;
    gout.PosH = mul(mul(v[3], gWorld), gViewProj);
    gout.NormalW = gin[0].NormalL;
    gout.TexC = float2(gin[0].TexC.x, 1.0f);
    triStream.Append(gout);
}

float4 PS(GeoOut pin) : SV_Target
{
    float4 diffuseAlbedo = gDiffuseMap.Sample(gsamAnisotropicWrap, pin.TexC) * gDiffuseAlbedo;
	
#ifdef ALPHA_TEST
	// Discard pixel if texture alpha < 0.1.  We do this test as soon 
	// as possible in the shader so that we can potentially exit the
	// shader early, thereby skipping the rest of the shader code.
	clip(diffuseAlbedo.a - 0.1f);
#endif

    // Interpolating normal can unnormalize it, so renormalize it.
    pin.NormalW = normalize(pin.NormalW);

    // Vector from point being lit to eye. 
	float3 toEyeW = gEyePosW - pin.PosW;
	float distToEye = length(toEyeW);
	toEyeW /= distToEye; // normalize

    // Light terms.
    float4 ambient = gAmbientLight*diffuseAlbedo;

    const float shininess = 1.0f - gRoughness;
    Material mat = { diffuseAlbedo, gFresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gLights, mat, pin.PosW,
        pin.NormalW, toEyeW, shadowFactor);

    float4 litColor = ambient + directLight;

#ifdef FOG
	float fogAmount = saturate((distToEye - gFogStart) / gFogRange);
	litColor = lerp(litColor, gFogColor, fogAmount);
#endif

    // Common convention to take alpha from diffuse albedo.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}


