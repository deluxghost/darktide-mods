#include "layer_buffer.h"
#include "render_graph.h"
#include "engine.h"
#include "gpu_readback.h"
#include <algorithm>
#include <array>
#include <cstdio>
#include <vector>

namespace goo {
namespace {
constexpr size_t ResourceManager = 0x308;
constexpr size_t BufferRecords = 0x1d8;
constexpr size_t BufferRecordSize = 0x68;
constexpr size_t Device = 0x1e8;
constexpr size_t CpuDescriptor = 0x40;
constexpr size_t GlobalDescriptor = 0x34;
constexpr size_t DescriptorStride = 0x78;
constexpr size_t GpuHeapCpuStart = 0x90;
constexpr size_t DescriptorAllocate = 0x40;

uint32_t name_hash(const char *text) {
    constexpr uint64_t Multiplier = 0xc6a4a7935bd1e995;
    const auto size = std::strlen(text);
    uint64_t hash = size * Multiplier;
    size_t offset = 0;
    for (; offset + 8 <= size; offset += 8) {
        uint64_t word;
        std::memcpy(&word, text + offset, sizeof(word));
        word *= Multiplier;
        word ^= word >> 47;
        hash = (hash ^ word * Multiplier) * Multiplier;
    }
    uint64_t tail = 0;
    for (size_t i = offset; i < size; ++i)
        tail |= uint64_t(static_cast<uint8_t>(text[i])) << ((i - offset) * 8);
    if (offset != size) hash = (hash ^ tail) * Multiplier;
    hash = (hash ^ (hash >> 47)) * Multiplier;
    hash ^= hash >> 47;
    return uint32_t(hash >> 32);
}

struct BufferFunctions {
    const void *gpu_allocator_slot = nullptr;
    const uint8_t *global_index = nullptr;
};

bool locate_buffer_functions(BufferFunctions &result, char *error, int capacity) {
    DtIntUtilsModule image{};
    DtIntUtilsFunction global{}, gpu_allocate{};
    if (!dtintutils_module_init_current(&image, error, capacity) ||
        !dtintutils_find_unique_function_by_exact_string(&image,
            "stingray::D3D12RenderDevice::global_resource_index", &global, error, capacity) ||
        !dtintutils_find_unique_function_by_exact_string(&image,
            "stingray::D3D12GpuDescriptorAllocator::alloc", &gpu_allocate, error, capacity))
        return false;
    if (!engine::function_has_numeric(global, ResourceManager) ||
        !engine::function_has_numeric(global, BufferRecords) ||
        !engine::function_has_numeric(global, BufferRecordSize)) {
        std::snprintf(error, capacity, "Layer buffer resource layout changed");
        return false;
    }
    result.global_index = global.start;

    std::array<const uint8_t *, 8> strings{};
    const auto strings_count = dtintutils_find_exact_strings(&image,
        "stingray::D3D12DescriptorAllocator::get_cpu_handle", strings.data(), strings.size());
    if (!strings_count || strings_count > strings.size()) {
        std::snprintf(error, capacity, "Descriptor allocator anchor changed");
        return false;
    }
    const auto *text = image.text;
    std::vector<const uint8_t *> builders;
    for (size_t i = 0; i < strings_count; ++i) {
        std::array<const uint8_t *, 128> references{};
        const auto count = dtintutils_find_rip_references(text->start, text->size,
            reinterpret_cast<uintptr_t>(strings[i]), DTINTUTILS_MNEMONIC_LEA,
            references.data(), references.size());
        if (count > references.size()) {
            std::snprintf(error, capacity, "Descriptor allocator reference capacity exceeded");
            return false;
        }
        for (size_t j = 0; j < count; ++j) {
            DtIntUtilsFunction function{};
            if (!dtintutils_function_containing(&image, references[j], &function)) continue;
            if (engine::function_has_numeric(function, Device) &&
                engine::function_has_numeric(function, 0x5c) &&
                engine::function_has_numeric(function, 0x58) &&
                engine::function_has_numeric(function, 0x27) &&
                std::find(builders.begin(), builders.end(), function.start) == builders.end())
                builders.push_back(function.start);
        }
    }
    if (builders.size() != 1) {
        std::snprintf(error, capacity, "Buffer view builder candidates: %zu", builders.size());
        return false;
    }
    DtIntUtilsFunction builder{};
    if (!dtintutils_function_containing(&image, builders[0], &builder)) {
        std::snprintf(error, capacity, "Buffer view builder function is unavailable");
        return false;
    }
    const void *slot = nullptr;
    for (size_t offset = 0; offset < builder.size;) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(builder.start + offset, builder.size - offset, &instruction)) {
            std::snprintf(error, capacity, "Failed to decode buffer view builder at offset 0x%zx", offset);
            return false;
        }
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV && instruction.operand_count >= 2 &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
            instruction.operands[1].memory_base == DTINTUTILS_REGISTER_RIP) {
            const auto *candidate = instruction.address + instruction.length + instruction.operands[1].displacement;
            if (dtintutils_is_writable_address(&image, candidate) &&
                dtintutils_is_readable_range(candidate, sizeof(void *))) {
                auto *allocator = engine::read<void *>(candidate, 0);
                if (dtintutils_is_readable_range(allocator, GpuHeapCpuStart + sizeof(uint64_t))) {
                    auto *table = engine::read<const uint8_t *>(allocator, 0);
                    if (dtintutils_is_readable_range(table, DescriptorAllocate + sizeof(void *)) &&
                        engine::read<const uint8_t *>(table, DescriptorAllocate) == gpu_allocate.start) {
                        if (slot && slot != candidate) {
                            std::snprintf(error, capacity, "Multiple global GPU descriptor allocators");
                            return false;
                        }
                        slot = candidate;
                    }
                }
            }
        }
        offset += instruction.length;
    }
    if (!slot) {
        std::snprintf(error, capacity, "Global GPU descriptor allocator was not found");
        return false;
    }
    result.gpu_allocator_slot = slot;
    return true;
}
}

void *RenderGraph::backend() const {
    return renderer_ ? engine::read<void *>(renderer_, engine::RendererBackendProxy) : nullptr;
}

const void *RenderGraph::layer_buffer(char *error, int capacity) const {
    if (!renderer_) {
        std::snprintf(error, capacity, "Outline render graph has not been initialized");
        return nullptr;
    }
    const auto *registry = renderer_ + engine::RendererGenerators;
    const auto count = engine::read<uint32_t>(registry, 0x50);
    const auto *entries = engine::read<const uint8_t *>(registry, 0x58);
    if (!dtintutils_is_readable_range(entries, size_t(count) * 16)) {
        std::snprintf(error, capacity, "Outline generator registry is unavailable");
        return nullptr;
    }
    const void *found = nullptr;
    for (uint32_t i = 0; i < count; ++i) {
        if (engine::read<uint32_t>(entries, size_t(i) * 16) != name_hash("goo_outline_layers_prepare"))
            continue;
        const auto *generator = engine::read<const uint8_t *>(entries, size_t(i) * 16 + 8);
        if (!dtintutils_is_readable_range(generator, 0x20) || engine::read<uint32_t>(generator, 8) != 2)
            break;
        const auto *modifiers = engine::read<const uint8_t *>(generator, 0x10);
        if (!dtintutils_is_readable_range(modifiers, sizeof(void *))) break;
        const auto *modifier = engine::read<const uint8_t *>(modifiers, 0);
        if (!dtintutils_is_readable_range(modifier, 0x28) ||
            engine::read<uint32_t>(modifier, 8) != 0x14 ||
            engine::read<uint32_t>(modifier, 0x18) != name_hash("goo_outline_layers"))
            break;
        const auto *descriptor = engine::read<const uint8_t *>(modifier, 0x20);
        if (!dtintutils_is_readable_range(descriptor, 64) ||
            engine::read<uint32_t>(descriptor, 0) != 15 ||
            engine::read<uint32_t>(descriptor, 0x1c) != 4)
            break;
        if (found) {
            std::snprintf(error, capacity, "Multiple layered outline buffers exist");
            return nullptr;
        }
        found = descriptor;
    }
    if (!found) std::snprintf(error, capacity, "Layered outline buffer was not found in the compiled graph");
    return found;
}

bool configure_layer_buffer(const RenderGraph &graph, uint32_t &index, char *error, int capacity) {
    const auto *descriptor = graph.layer_buffer(error, capacity);
    if (!descriptor) return false;
    BufferFunctions functions;
    if (!locate_buffer_functions(functions, error, capacity)) return false;
    auto *backend = graph.backend();
    if (!dtintutils_is_readable_range(backend, ResourceManager + sizeof(void *))) {
        std::snprintf(error, capacity, "Layer buffer render backend is unavailable");
        return false;
    }
    const auto *vtable = engine::read<const uint8_t *>(backend, 0);
    DtIntUtilsModule image{};
    if (!dtintutils_module_init_current(&image, error, capacity)) return false;
    bool device_matches = false;
    for (size_t i = 0; dtintutils_is_readable_range(vtable + i * sizeof(void *), sizeof(void *)); ++i) {
        const auto *method = engine::read<const uint8_t *>(vtable, i * sizeof(void *));
        if (!dtintutils_is_executable_address(&image, method)) break;
        if (method == functions.global_index) { device_matches = true; break; }
    }
    const auto handle = engine::read<uint32_t>(descriptor, 4);
    if (!device_matches || (handle >> 26 & 31) != 15) {
        std::snprintf(error, capacity, "Layer buffer device or resource type changed");
        return false;
    }
    auto *manager = engine::read<uint8_t *>(backend, ResourceManager);
    if (!dtintutils_is_readable_range(manager, BufferRecords + sizeof(void *))) {
        std::snprintf(error, capacity, "Layer buffer resource manager is unavailable");
        return false;
    }
    const auto slot = handle & 0x3fffff;
    const auto count = engine::read<uint32_t>(manager, 0x50);
    const auto *lookup = engine::read<const uint8_t *>(manager, 0x58);
    const auto *entry = lookup + size_t(slot) * 8;
    if (slot >= count || !dtintutils_is_readable_range(entry, 8) ||
        engine::read<uint32_t>(entry, 4) != handle || engine::read<uint32_t>(entry, 0) == UINT32_MAX) {
        std::snprintf(error, capacity, "Layer buffer handle is not in the live resource table");
        return false;
    }
    const auto number = engine::read<uint32_t>(entry, 0);
    auto *records = engine::read<uint8_t *>(manager, BufferRecords);
    auto *record = records + size_t(number) * BufferRecordSize;
    if (!dtintutils_is_readable_range(record, BufferRecordSize) ||
        engine::read<uint32_t>(record, 0x50) != engine::read<uint32_t>(descriptor, 0x18) ||
        (engine::read<uint32_t>(record, 0x58) & 3) != 3) {
        std::snprintf(error, capacity, "Layer buffer GPU record is unavailable or differs from its descriptor");
        return false;
    }
    auto *wrapper = engine::read<const uint8_t *>(record, 0);
    if (!dtintutils_is_readable_range(wrapper, 16)) {
        std::snprintf(error, capacity, "Layer buffer GPU resource is unavailable");
        return false;
    }
    auto *resource = engine::read<ID3D12Resource *>(wrapper, 8);
    auto *device = engine::read<ID3D12Device *>(backend, Device);
    if (!dtintutils_is_readable_range(resource, sizeof(void *)) ||
        !dtintutils_is_readable_range(device, sizeof(void *))) {
        std::snprintf(error, capacity, "Layer buffer D3D12 resource or device is unavailable");
        return false;
    }
    auto *allocator = engine::read<const uint8_t *>(functions.gpu_allocator_slot, 0);
    if (!dtintutils_is_readable_range(allocator, GpuHeapCpuStart + sizeof(uint64_t))) {
        std::snprintf(error, capacity, "Layer buffer GPU descriptor allocator is unavailable");
        return false;
    }
    const auto stride = device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    const auto first = engine::read<uint32_t>(record, GlobalDescriptor);
    const auto cpu = engine::read<uint64_t>(record, CpuDescriptor);
    const auto gpu_heap_cpu_start = engine::read<uint64_t>(allocator, GpuHeapCpuStart);
    if (stride != engine::read<uint32_t>(allocator, DescriptorStride) || !cpu || !gpu_heap_cpu_start ||
        resource->GetDesc().Dimension != D3D12_RESOURCE_DIMENSION_BUFFER) {
        std::snprintf(error, capacity, "Layer buffer descriptor heap or resource dimension changed");
        return false;
    }
    const auto gpu_cpu = gpu_heap_cpu_start + uint64_t(first) * stride;
    D3D12_SHADER_RESOURCE_VIEW_DESC srv{};
    srv.Format = DXGI_FORMAT_R32G32B32A32_UINT;
    srv.ViewDimension = D3D12_SRV_DIMENSION_BUFFER;
    srv.Shader4ComponentMapping = D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING;
    const auto words = engine::read<uint32_t>(descriptor, 0x18) / uint32_t(sizeof(uint32_t));
    srv.Buffer.NumElements = words / 4;
    device->CreateShaderResourceView(resource, &srv, {cpu});
    device->CopyDescriptorsSimple(1, {gpu_cpu}, {cpu}, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    D3D12_UNORDERED_ACCESS_VIEW_DESC uav{};
    uav.Format = DXGI_FORMAT_R32_UINT;
    uav.ViewDimension = D3D12_UAV_DIMENSION_BUFFER;
    uav.Buffer.NumElements = words;
    device->CreateUnorderedAccessView(resource, nullptr, &uav, {cpu + stride});
    device->CopyDescriptorsSimple(1, {gpu_cpu + stride}, {cpu + stride}, D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    index = first + 1;
    return gpu_readback::start(device, resource, error, capacity);
}
}
