#pragma once
#include <dtintutils.h>
#include <d3d12.h>
#include <array>
#include <cstdint>
#include <cstring>

namespace goo::engine {
inline constexpr size_t VertexBytes = 0x188;
inline constexpr size_t VertexCompressedSize = 0x190;
inline constexpr size_t PixelBytes = 0x198;
inline constexpr size_t PixelCompressedSize = 0x1a0;
inline constexpr size_t VertexExpandedSize = 0x1f8;
inline constexpr size_t PixelExpandedSize = 0x1fc;
inline constexpr size_t ApplicationRenderer = 0x198;
inline constexpr size_t RendererConfig = 0xd0;
inline constexpr size_t RendererLayers = 0x248;
inline constexpr size_t RendererGenerators = 0x270;
inline constexpr size_t RendererGlobalResources = 0x1c0;
inline constexpr size_t RendererViewports = 0x2e8;
inline constexpr size_t RendererBackendProxy = 0xa8;
inline constexpr size_t RendererBackend = 0x98;
inline constexpr size_t RendererThreaded = 0x164;
inline constexpr size_t BackendCreateContext = 0xa0;
inline constexpr size_t ConfigHeaderSize = 4;
inline constexpr size_t LayoutElements = 8;
inline constexpr size_t LayoutCount = 0;
inline constexpr size_t RasterizerFlags = 0x18;

template <typename T> T read(const void *object, size_t offset) {
    T value;
    std::memcpy(&value, static_cast<const uint8_t *>(object) + offset, sizeof(value));
    return value;
}

struct PipelineArguments {
    std::array<uint8_t, 0x10> reserved{};
    void *pass = nullptr;
    const void *elements = nullptr;
    uint64_t element_count = 0;
    uint32_t topology = 0;
    std::array<uint32_t, 8> target_formats{};
    uint32_t target_count = 0;
    uint32_t depth_format = 0;
    uint8_t rasterizer_flag = 0;
    std::array<uint8_t, 11> padding{};
};
static_assert(sizeof(PipelineArguments) == 0x60);
static_assert(offsetof(PipelineArguments, pass) == 0x10);
static_assert(offsetof(PipelineArguments, target_formats) == 0x2c);
static_assert(offsetof(PipelineArguments, target_count) == 0x4c);
static_assert(offsetof(PipelineArguments, depth_format) == 0x50);
static_assert(offsetof(PipelineArguments, rasterizer_flag) == 0x54);

using Pipeline = void *(*)(void *, uint64_t, void *, void *, void *, void *, uint32_t, uint32_t,
                           void *, uint32_t, char, void *, uint64_t, int);
using BuildDescriptor =
    D3D12_GRAPHICS_PIPELINE_STATE_DESC *(*)(D3D12_GRAPHICS_PIPELINE_STATE_DESC *, void *,
                                            PipelineArguments *);
using Decompress = intptr_t (*)(const void *, intptr_t, void *, intptr_t, int, int, int, void *,
                                intptr_t, void *, void *, void *, intptr_t, int);

struct Functions {
    DtIntUtilsFunction pipeline{};
    size_t hook_length = 0;
    BuildDescriptor build_descriptor = nullptr;
    Decompress decompress = nullptr;
};

struct Symbols {
    DtIntUtilsFunction pipeline{}, config{}, setup{}, generators{}, viewports{}, fence{};
};

bool locate_symbols(const DtIntUtilsModule &image, Symbols &result, char *error, int capacity);
bool locate_functions(Functions &result, char *error, int capacity);
bool function_has_numeric(const DtIntUtilsFunction &function, int64_t value);
bool find_child(const DtIntUtilsModule &image, const DtIntUtilsFunction &parent,
                const std::array<int64_t, 3> &fields, DtIntUtilsFunction &result, char *error,
                int capacity);
uint8_t *locate_config(char *error, int capacity, void **renderer);
} // namespace goo::engine
