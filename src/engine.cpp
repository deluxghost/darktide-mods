#include "engine.h"
#include <windows.h>
#include <algorithm>
#include <cstdio>
#include <vector>

namespace goo::engine {
namespace {
constexpr size_t MaximumDirectCalls = 128;
constexpr size_t HookJumpSize = 14;
constexpr int64_t PipelineCreationFlag = 0x55;
constexpr int64_t DescriptorFieldA = 0x244;
constexpr int64_t DescriptorFieldB = 0x264;
constexpr uint32_t ConfigRootEntries = 26;
} // namespace

bool function_has_numeric(const DtIntUtilsFunction &function, int64_t value) {
    for (size_t offset = 0; offset < function.size;) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction)) {
            return false;
        }
        for (size_t index = 0; index < instruction.operand_count; ++index) {
            const auto &operand = instruction.operands[index];
            if (operand.type == DTINTUTILS_OPERAND_MEMORY && operand.displacement == value) {
                return true;
            }
            if (operand.type == DTINTUTILS_OPERAND_IMMEDIATE && !operand.immediate_is_relative &&
                static_cast<int64_t>(operand.immediate) == value) {
                return true;
            }
        }
        offset += instruction.length;
    }
    return false;
}

bool find_child(const DtIntUtilsModule &image, const DtIntUtilsFunction &parent,
                const std::array<int64_t, 3> &fields, DtIntUtilsFunction &result, char *error,
                int capacity) {
    std::array<const uint8_t *, MaximumDirectCalls> calls{};
    const auto count =
        dtintutils_collect_direct_call_targets(&image, &parent, calls.data(), calls.size());
    if (count > calls.size()) {
        std::snprintf(error, capacity, "Engine child capacity exceeded");
        return false;
    }
    std::vector<uint8_t *> matches;
    for (size_t index = 0; index < count; ++index) {
        DtIntUtilsFunction child{};
        if (!dtintutils_function_containing(&image, calls[index], &child)) {
            continue;
        }
        if (!std::all_of(fields.begin(), fields.end(),
                         [&](auto field) { return function_has_numeric(child, field); })) {
            continue;
        }
        if (std::find(matches.begin(), matches.end(), child.start) == matches.end()) {
            matches.push_back(child.start);
            result = child;
        }
    }
    if (matches.size() != 1) {
        std::snprintf(error, capacity, "Engine child candidates for field 0x%llx: %zu",
                      static_cast<unsigned long long>(fields[0]), matches.size());
        return false;
    }
    return true;
}

namespace {
uint8_t *config_from_slot(const void *slot, void **renderer_result) {
    if (!dtintutils_is_readable_range(slot, sizeof(void *))) {
        return nullptr;
    }
    const auto *app = read<const uint8_t *>(slot, 0);
    if (!dtintutils_is_readable_range(app, ApplicationRenderer + sizeof(void *))) {
        return nullptr;
    }
    const auto *renderer = read<const uint8_t *>(app, ApplicationRenderer);
    if (!dtintutils_is_readable_range(renderer, RendererConfig + sizeof(void *))) {
        return nullptr;
    }
    auto *blob = read<uint8_t *>(renderer, RendererConfig);
    if (!dtintutils_is_readable_range(blob, 16) || read<uint32_t>(blob, 4) != 6 ||
        read<uint32_t>(blob, 8) != 8 || read<uint32_t>(blob, 12) != ConfigRootEntries) {
        return nullptr;
    }
    *renderer_result = const_cast<uint8_t *>(renderer);
    return blob + ConfigHeaderSize;
}
} // namespace

bool locate_symbols(const DtIntUtilsModule &image, Symbols &result, char *error, int capacity) {
    // All locators run on the Lua thread. Cache code addresses, never renderer objects.
    static Symbols cached;
    if (!cached.config.start) {
        const char *anchors[] = {
            "stingray::d3d12_pipeline_state::pipeline_state",
            "Application.render_config",
            "stingray::RenderInterface::setup",
            "resource generator",
            "stingray::RenderInterface::reload_viewport_templates",
            "stingray::RenderInterface::create_fence",
        };
        std::array<DtIntUtilsFunction, std::size(anchors)> functions{};
        if (!dtintutils_find_unique_functions_by_exact_strings(&image, anchors, functions.data(),
                                                               functions.size(), error, capacity))
            return false;
        cached = {functions[0], functions[1], functions[2],
                  functions[3], functions[4], functions[5]};
    }
    result = cached;
    return true;
}

bool locate_functions(Functions &result, char *error, int capacity) {
    const auto library = GetModuleHandleA("oo2core_9_win64.dll");
    result.decompress = reinterpret_cast<Decompress>(
        library ? GetProcAddress(library, "OodleLZ_Decompress") : nullptr);
    if (!result.decompress) {
        std::snprintf(error, capacity, "Loaded Oodle decompressor not found");
        return false;
    }
    DtIntUtilsModule image{};
    Symbols symbols;
    DtIntUtilsFunction creation{}, builder{};
    if (!dtintutils_module_init_current(&image, error, capacity) ||
        !locate_symbols(image, symbols, error, capacity) ||
        !find_child(image, symbols.pipeline,
                    {PipelineCreationFlag, VertexExpandedSize, PixelExpandedSize}, creation, error,
                    capacity) ||
        !find_child(image, creation, {DescriptorFieldA, DescriptorFieldB, VertexBytes}, builder,
                    error, capacity)) {
        return false;
    }
    result.pipeline = symbols.pipeline;
    result.build_descriptor = reinterpret_cast<BuildDescriptor>(builder.start);
    result.hook_length = 0;
    while (result.hook_length < HookJumpSize) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(result.pipeline.start + result.hook_length,
                               result.pipeline.size - result.hook_length, &instruction) ||
            !instruction.length) {
            std::snprintf(error, capacity, "Pipeline entry decode failed");
            return false;
        }
        result.hook_length += instruction.length;
    }
    return true;
}

uint8_t *locate_config(char *error, int capacity, void **renderer_result) {
    DtIntUtilsModule image{};
    Symbols symbols;
    if (!dtintutils_module_init_current(&image, error, capacity) ||
        !locate_symbols(image, symbols, error, capacity)) {
        return nullptr;
    }
    const auto &function = symbols.config;
    std::vector<uint8_t *> matches;
    for (size_t offset = 0; offset < function.size;) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction) ||
            !instruction.length) {
            std::snprintf(error, capacity, "Config locator decode failed");
            return nullptr;
        }
        for (size_t index = 0; index < instruction.operand_count; ++index) {
            const auto &operand = instruction.operands[index];
            if (instruction.mnemonic != DTINTUTILS_MNEMONIC_MOV ||
                operand.type != DTINTUTILS_OPERAND_MEMORY ||
                operand.memory_base != DTINTUTILS_REGISTER_RIP) {
                continue;
            }
            void *renderer;
            auto *config = config_from_slot(
                instruction.address + instruction.length + operand.displacement, &renderer);
            if (config && std::find(matches.begin(), matches.end(), config) == matches.end()) {
                matches.push_back(config);
                *renderer_result = renderer;
            }
        }
        offset += instruction.length;
    }
    if (matches.size() != 1) {
        std::snprintf(error, capacity, "Render config candidates: %zu", matches.size());
        return nullptr;
    }
    return matches[0];
}
} // namespace goo::engine
