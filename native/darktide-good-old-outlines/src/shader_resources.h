#pragma once
#include <array>
#include <cstdint>
#include <span>
#include <string>
#include <vector>

namespace goo {
// Resource type, register space/range, resource kind and flags from PSV0.
using ShaderResource = std::array<uint32_t, 6>;
bool read_shader_resources(std::span<const uint8_t> bytes, std::vector<ShaderResource> &resources,
                           std::string &error);
bool shader_candidate(std::span<const uint8_t> bytes,
                      std::span<const std::span<const ShaderResource>> contracts, bool &candidate,
                      std::string &error);
} // namespace goo
