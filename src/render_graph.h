#pragma once
#include <cstdint>

namespace goo {
struct ConfigValue;

class RenderGraph {
  public:
    bool initialize(void *renderer, const uint8_t *config, uint32_t size, char *error,
                    int capacity);
    // Failure is reported before any engine graph builder runs, allowing config rollback.
    bool rebuild(char *error, int capacity) const;

  private:
    using BuildLayers = void (*)(void *, const ConfigValue *, const ConfigValue *);
    using AddDebugLayer = void (*)(void *);
    using BuildGenerators = void (*)(void *, const ConfigValue *, void *, void *);
    using ReloadViewports = void (*)(void *, const ConfigValue *, void *);
    using Enqueue = void (*)(void *, uint32_t, const void *, uint32_t);
    using ReleaseContext = void (*)(void *, void *);
    BuildLayers build_layers_ = nullptr;
    AddDebugLayer add_debug_layer_ = nullptr;
    BuildGenerators build_generators_ = nullptr;
    ReloadViewports reload_viewports_ = nullptr;
    Enqueue enqueue_ = nullptr;
    ReleaseContext release_context_ = nullptr;
    const void *context_allocator_slot_ = nullptr;
    uint8_t *renderer_ = nullptr;
    const uint8_t *config_ = nullptr;
    uint32_t size_ = 0;
    bool entry(const char *name, ConfigValue &result) const;
    void *create_context(char *error, int capacity) const;
    bool locate_functions(char *error, int capacity);
};
} // namespace goo
