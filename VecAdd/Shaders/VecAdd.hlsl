struct Data
{
	float3 v1;
};

ConsumeStructuredBuffer<Data> gInputA : register(t0);
AppendStructuredBuffer<float> gOutput : register(u0);


[numthreads(64, 1, 1)]
void CS(int3 dtid : SV_DispatchThreadID)
{
    Data data = gInputA.Consume();
    float length = length(data.v1);
    gOutput.Append(length);
}
