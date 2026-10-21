#include "render_graph.h"
#include "engine.h"
#include <algorithm>
#include <cstdio>
#include <cstring>

namespace goo {
namespace {
constexpr size_t MaximumCalls = 128;
constexpr int RegisterRax = 0;
constexpr int RegisterRdx = 2;

bool calls_function(const DtIntUtilsModule &image, const DtIntUtilsFunction &caller,
                    const uint8_t *callee) {
    std::array<const uint8_t *, MaximumCalls> calls{};
    const auto count =
        dtintutils_collect_direct_call_targets(&image, &caller, calls.data(), calls.size());
    return count <= calls.size() &&
           std::find(calls.begin(), calls.begin() + count, callee) != calls.begin() + count;
}

const void *context_allocator_slot(const DtIntUtilsFunction &setup) {
    const void *slot = nullptr;
    const void *previous = nullptr;
    for (size_t offset = 0; offset < setup.size;) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(setup.start + offset, setup.size - offset, &instruction))
            return nullptr;
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_MEMORY &&
            instruction.operands[0].memory_base == RegisterRax &&
            instruction.operands[0].displacement == engine::BackendCreateContext && previous) {
            if (slot && slot != previous)
                return nullptr;
            slot = previous;
        }
        previous = nullptr;
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV && instruction.operand_count >= 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].register_id == RegisterRdx &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
            instruction.operands[1].memory_base == DTINTUTILS_REGISTER_RIP)
            previous =
                instruction.address + instruction.length + instruction.operands[1].displacement;
        offset += instruction.length;
    }
    return slot;
}

bool locate_context_release(const DtIntUtilsModule &image, const DtIntUtilsFunction &setup,
                            const DtIntUtilsFunction &enqueue, DtIntUtilsFunction &release,
                            char *error, int capacity) {
    std::array<const uint8_t *, MaximumCalls> calls{};
    const auto count =
        dtintutils_collect_direct_call_targets(&image, &setup, calls.data(), calls.size());
    if (count > calls.size()) {
        std::snprintf(error, capacity, "Render context call capacity exceeded");
        return false;
    }
    unsigned matches = 0;
    for (size_t index = 0; index < count; ++index) {
        DtIntUtilsFunction function{};
        if (dtintutils_function_containing(&image, calls[index], &function) &&
            function.size < 512 &&
            engine::function_has_numeric(function, engine::RendererThreaded) &&
            engine::function_has_numeric(function, 0x10) &&
            calls_function(image, function, enqueue.start)) {
            release = function;
            ++matches;
        }
    }
    if (matches != 1)
        std::snprintf(error, capacity, "Render context release candidates: %u", matches);
    return matches == 1;
}

bool locate_layer_builders(const DtIntUtilsModule &image, const DtIntUtilsFunction &setup,
                           DtIntUtilsFunction &layers, DtIntUtilsFunction &debug, char *error,
                           int capacity) {
    std::array<const uint8_t *, MaximumCalls> calls{};
    const auto count =
        dtintutils_collect_direct_call_targets(&image, &setup, calls.data(), calls.size());
    if (count > calls.size()) {
        std::snprintf(error, capacity, "Render graph call capacity exceeded");
        return false;
    }
    unsigned matches = 0;
    for (size_t index = 0; index < count; ++index) {
        DtIntUtilsFunction candidate{};
        if (dtintutils_function_containing(&image, calls[index], &candidate) &&
            engine::function_has_numeric(candidate, 0x20d0) &&
            engine::function_has_numeric(candidate, 0x348) &&
            engine::function_has_numeric(candidate, 0x258)) {
            debug = candidate;
            ++matches;
        }
    }
    if (matches != 1) {
        std::snprintf(error, capacity, "Debug layer builder candidates: %u", matches);
        return false;
    }
    const uint8_t *previous = nullptr;
    matches = 0;
    for (size_t offset = 0; offset < setup.size;) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(setup.start + offset, setup.size - offset, &instruction)) {
            std::snprintf(error, capacity, "Render setup decode failed");
            return false;
        }
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL) {
            for (size_t index = 0; index < instruction.operand_count; ++index) {
                const auto &operand = instruction.operands[index];
                if (operand.type != DTINTUTILS_OPERAND_IMMEDIATE || !operand.immediate_is_relative)
                    continue;
                const auto *target = instruction.address + instruction.length +
                                     static_cast<int64_t>(operand.immediate);
                if (target == debug.start && previous &&
                    dtintutils_function_containing(&image, previous, &layers) &&
                    engine::function_has_numeric(layers, 0x348) &&
                    engine::function_has_numeric(layers, 0x28))
                    ++matches;
                previous = target;
            }
        }
        offset += instruction.length;
    }
    if (matches != 1)
        std::snprintf(error, capacity, "Layer builder call chain candidates: %u", matches);
    return matches == 1;
}
} // namespace

bool RenderGraph::locate_functions(char *error, int capacity) {
    DtIntUtilsModule image{};
    engine::Symbols symbols;
    if (!dtintutils_module_init_current(&image, error, capacity) ||
        !engine::locate_symbols(image, symbols, error, capacity))
        return false;
    const auto &setup = symbols.setup;
    const auto &generators = symbols.generators;
    const auto &viewports = symbols.viewports;
    if (!engine::function_has_numeric(setup, engine::RendererLayers) ||
        !engine::function_has_numeric(setup, engine::RendererGenerators) ||
        !engine::function_has_numeric(setup, engine::RendererViewports)) {
        std::snprintf(error, capacity, "Render setup fields changed");
        return false;
    }
    DtIntUtilsFunction layers{}, debug{}, enqueue{}, release{};
    if (!locate_layer_builders(image, setup, layers, debug, error, capacity) ||
        !engine::find_child(image, symbols.fence, {0x100, 0x3c, 8}, enqueue, error, capacity) ||
        !locate_context_release(image, setup, enqueue, release, error, capacity))
        return false;
    std::array<const uint8_t *, MaximumCalls> calls{};
    const auto count =
        dtintutils_collect_direct_call_targets(&image, &setup, calls.data(), calls.size());
    if (count > calls.size() ||
        std::find(calls.begin(), calls.begin() + count, generators.start) ==
            calls.begin() + count ||
        std::find(calls.begin(), calls.begin() + count, viewports.start) == calls.begin() + count) {
        std::snprintf(error, capacity, "Render graph builders are not children of setup");
        return false;
    }
    build_layers_ = reinterpret_cast<BuildLayers>(layers.start);
    add_debug_layer_ = reinterpret_cast<AddDebugLayer>(debug.start);
    build_generators_ = reinterpret_cast<BuildGenerators>(generators.start);
    reload_viewports_ = reinterpret_cast<ReloadViewports>(viewports.start);
    enqueue_ = reinterpret_cast<Enqueue>(enqueue.start);
    release_context_ = reinterpret_cast<ReleaseContext>(release.start);
    context_allocator_slot_ = context_allocator_slot(setup);
    if (!context_allocator_slot_ ||
        !dtintutils_section_for_address(&image, context_allocator_slot_) ||
        !dtintutils_is_readable_range(context_allocator_slot_, sizeof(void *))) {
        std::snprintf(error, capacity, "Render context allocator slot changed");
        return false;
    }
    return true;
}

} // namespace goo
