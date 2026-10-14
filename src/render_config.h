#pragma once
#include "render_graph.h"
#include <cstdint>
#include <vector>

namespace goo {
struct RenderConfig {
    uint8_t *target = nullptr;
    std::vector<uint8_t> original;
    std::vector<uint8_t> modified;
    bool applied = false;
    RenderGraph graph;

    const void *snapshot(uint32_t *size, char *error, int capacity);
    bool apply(const void *data, uint32_t size, char *error, int capacity);
    bool restore(char *error, int capacity);
};
} // namespace goo
