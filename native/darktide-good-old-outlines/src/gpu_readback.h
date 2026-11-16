#pragma once
#include <d3d12.h>

namespace goo::gpu_readback {
bool start(ID3D12Device *device, ID3D12Resource *buffer, char *error, int capacity);
bool stop(char *error, int capacity);
void add_composite(ID3D12PipelineState *pipeline);
const char *error();
}
