#pragma once
#include <cstdint>

namespace goo {
class RenderGraph;

bool configure_layer_buffer(const RenderGraph &graph, uint32_t &index, char *error, int capacity);
}
