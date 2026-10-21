#include "shader_resources.h"
#include <algorithm>
#include <cstring>
#include <string_view>

namespace goo {
namespace {
constexpr size_t ContainerHeaderSize = 32;
constexpr size_t ResourceRecordSize = sizeof(ShaderResource);

uint32_t integer(std::span<const uint8_t> bytes, size_t offset) {
    uint32_t value;
    std::memcpy(&value, bytes.data() + offset, sizeof(value));
    return value;
}

bool resources_from_psv(std::span<const uint8_t> bytes, std::vector<ShaderResource> &resources) {
    if (bytes.size() < 8)
        return false;
    const auto runtime_size = integer(bytes, 0);
    if (runtime_size > bytes.size() - 8)
        return false;
    const auto count = integer(bytes, 4 + runtime_size);
    if (!count)
        return true;
    const size_t table = size_t(runtime_size) + 12;
    if (table > bytes.size())
        return false;
    const auto stride = integer(bytes, table - 4);
    if (stride != ResourceRecordSize || count > (bytes.size() - table) / stride)
        return false;
    resources.resize(count);
    for (size_t index = 0; index < count; ++index)
        std::memcpy(resources[index].data(), bytes.data() + table + index * stride,
                    ResourceRecordSize);
    std::sort(resources.begin(), resources.end());
    return true;
}
} // namespace

bool read_shader_resources(std::span<const uint8_t> bytes, std::vector<ShaderResource> &resources,
                           std::string &error) {
    resources.clear();
    if (bytes.size() < ContainerHeaderSize || std::memcmp(bytes.data(), "DXBC", 4) ||
        integer(bytes, 24) != bytes.size()) {
        error = "Invalid DXIL container header";
        return false;
    }
    const auto count = integer(bytes, 28);
    if (count > (bytes.size() - ContainerHeaderSize) / sizeof(uint32_t)) {
        error = "Invalid DXIL part table";
        return false;
    }
    bool found = false;
    for (size_t index = 0; index < count; ++index) {
        const auto offset = integer(bytes, ContainerHeaderSize + index * sizeof(uint32_t));
        if (offset > bytes.size() - 8 || integer(bytes, offset + 4) > bytes.size() - offset - 8) {
            error = "Invalid DXIL part extent";
            return false;
        }
        if (std::memcmp(bytes.data() + offset, "PSV0", 4))
            continue;
        if (found ||
            !resources_from_psv(bytes.subspan(offset + 8, integer(bytes, offset + 4)), resources)) {
            error = "Invalid or duplicate PSV0 resource table";
            return false;
        }
        found = true;
    }
    if (!found)
        error = "DXIL container has no PSV0 resource table";
    return found;
}

bool shader_candidate(std::span<const uint8_t> bytes,
                      std::span<const std::span<const ShaderResource>> contracts, bool &candidate,
                      std::string &error) {
    std::vector<ShaderResource> resources;
    if (!read_shader_resources(bytes, resources, error))
        return false;
    candidate = std::any_of(contracts.begin(), contracts.end(), [&](const auto &contract) {
        return std::equal(resources.begin(), resources.end(), contract.begin(), contract.end());
    });
    // Retain explicit diagnostics for known outline fields with changed bindings.
    const std::string_view container(reinterpret_cast<const char *>(bytes.data()), bytes.size());
    candidate = candidate || container.find("outline_thickness") != container.npos ||
                container.find("outline_inner_params") != container.npos;
    return true;
}
} // namespace goo
