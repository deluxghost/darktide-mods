#include "render_graph.h"
#include "engine.h"
#include <cstdio>
#include <cstring>

namespace goo {
struct ConfigValue {
    const uint8_t *base;
    uint32_t kind;
    uint32_t value;
};
static_assert(sizeof(ConfigValue) == 16);
namespace {
constexpr size_t ConfigEntrySize = 12;
constexpr uint32_t ObjectKind = 6;
constexpr uint32_t ExecuteContextCommand = 0xf;
} // namespace

bool RenderGraph::initialize(void *renderer, const uint8_t *config, uint32_t size, char *error,
                             int capacity) {
    if (!renderer_ && !locate_functions(error, capacity))
        return false;
    renderer_ = static_cast<uint8_t *>(renderer);
    config_ = config;
    size_ = size;
    return true;
}

void *RenderGraph::create_context(char *error, int capacity) const {
    auto *backend = engine::read<void *>(renderer_, engine::RendererBackendProxy);
    if (!backend)
        backend = engine::read<void *>(renderer_, engine::RendererBackend);
    if (!dtintutils_is_readable_range(backend, sizeof(void *)) ||
        !engine::read<uint8_t>(renderer_, engine::RendererThreaded)) {
        std::snprintf(error, capacity, "Render backend or threaded renderer is unavailable");
        return nullptr;
    }
    const auto *vtable = engine::read<const uint8_t *>(backend, 0);
    DtIntUtilsModule image{};
    if (!dtintutils_module_init_current(&image, error, capacity))
        return nullptr;
    const auto *section = dtintutils_section_for_address(&image, vtable);
    if (!section || std::strcmp(section->name, ".rdata") ||
        !dtintutils_is_readable_range(vtable, engine::BackendCreateContext + sizeof(void *))) {
        std::snprintf(error, capacity, "Render backend vtable changed");
        return nullptr;
    }
    const auto address = engine::read<const uint8_t *>(vtable, engine::BackendCreateContext);
    const auto *code = dtintutils_section_for_address(&image, address);
    if (!code || std::strcmp(code->name, ".text")) {
        std::snprintf(error, capacity, "Render context creation method changed");
        return nullptr;
    }
    using CreateContext = void *(*)(void *, void *);
    auto *allocator = engine::read<void *>(context_allocator_slot_, 0);
    if (!dtintutils_is_readable_range(allocator, sizeof(void *))) {
        std::snprintf(error, capacity, "Render context allocator is unavailable");
        return nullptr;
    }
    auto *context = reinterpret_cast<CreateContext>(address)(backend, allocator);
    if (!context)
        std::snprintf(error, capacity, "Render context creation returned null");
    return context;
}

bool RenderGraph::entry(const char *name, ConfigValue &result) const {
    if (size_ < 8 || engine::read<uint32_t>(config_, 0) != ObjectKind)
        return false;
    const auto offset = engine::read<uint32_t>(config_, 4);
    if (offset > size_ - 4)
        return false;
    const auto count = engine::read<uint32_t>(config_, offset);
    if (count > (size_ - offset - 4) / ConfigEntrySize)
        return false;
    for (size_t index = 0; index < count; ++index) {
        const auto child = offset + 4 + index * ConfigEntrySize;
        const auto text = engine::read<uint32_t>(config_, child);
        if (text >= size_ || !std::memchr(config_ + text, 0, size_ - text))
            return false;
        if (std::strcmp(reinterpret_cast<const char *>(config_ + text), name))
            continue;
        result = {config_, engine::read<uint32_t>(config_, child + 4),
                  engine::read<uint32_t>(config_, child + 8)};
        return result.kind == ObjectKind && result.value < size_;
    }
    return false;
}

bool RenderGraph::rebuild(char *error, int capacity) const {
    ConfigValue layers{}, blocks{}, generators{}, viewports{};
    if (!renderer_ || !entry("layer_configs", layers) || !entry("code_blocks", blocks) ||
        !entry("resource_generators", generators) || !entry("viewports", viewports)) {
        std::snprintf(error, capacity, "Render graph config entries changed");
        return false;
    }
    auto *context = create_context(error, capacity);
    if (!context)
        return false;
    // Match the graph-building order in RenderInterface::setup, without applying user settings.
    build_layers_(renderer_ + engine::RendererLayers, &layers, &blocks);
    add_debug_layer_(renderer_);
    build_generators_(renderer_ + engine::RendererGenerators, &generators, context, renderer_);
    reload_viewports_(renderer_, &viewports, renderer_ + engine::RendererGlobalResources);
    const struct {
        uint32_t count;
        uint32_t padding;
        std::array<void *, 8> contexts;
    } command{1, 0, {context}};
    static_assert(sizeof(command) == 72);
    enqueue_(renderer_, ExecuteContextCommand, &command, sizeof(command));
    release_context_(renderer_, context);
    return true;
}
} // namespace goo
