struct Data
{
	float3 v1;
};

Buffer<float3> gInputA : register(t0);
RWBuffer<float> gOutput : register(u0);


[numthreads(64, 1, 1)]
void CS(int3 dtid : SV_DispatchThreadID)
{
    gOutput[dtid.x] = length(gInputA[dtid.x]);
}
