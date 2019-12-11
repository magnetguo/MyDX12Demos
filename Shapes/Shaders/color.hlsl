//***************************************************************************************
// color.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Transforms and colors geometry.
//***************************************************************************************
 
cbuffer cbPerObject : register(b0)
{
    float w00;
    float w01;
    float w02;
    float w03;
    float w10;
    float w11;
    float w12;
    float w13;
    float w20;
    float w21;
    float w22;
    float w23;
    float w30;
    float w31;
    float w32;
    float w33;
};

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
};

struct VertexIn
{
	float3 PosL  : POSITION;
    float4 Color : COLOR;
};

struct VertexOut
{
	float4 PosH  : SV_POSITION;
    float4 Color : COLOR;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout;
	
	// Transform to homogeneous clip space.
    float4x4 gWorld = float4x4(
                                w00, w01, w02, w03,
                                w10, w11, w12, w13,
                                w20, w21, w22, w23,
                                w30, w31, w32, w33);
    float4 posW = mul(float4(vin.PosL, 1.0f), transpose(gWorld));
    vout.PosH = mul(posW, gViewProj);
	
	// Just pass vertex color into the pixel shader.
    vout.Color = vin.Color;
    
    return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
    return pin.Color;
}


