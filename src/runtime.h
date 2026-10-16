#pragma once
#include "engine.h"
#include "render_config.h"
#include "shader_matcher.h"
#include <wrl/client.h>
#include <atomic>
#include <deque>
#include <mutex>
#include <vector>

namespace goo {
using Microsoft::WRL::ComPtr;

struct Runtime {
    DtIntUtilsHook hook{};
    engine::Functions engine;
    RenderConfig config;
    ShaderMatcher matcher;
    std::array<std::vector<uint8_t>, ProgramCount> shaders;
    std::atomic<bool> enabled{false};
    std::atomic<unsigned> callbacks{0};
    std::mutex pipeline_mutex;
    char failure_message[256]{};
    std::atomic<const char *> failure{nullptr};
    std::mutex warnings_mutex;
    std::deque<std::string> warnings;

    // Called under pipeline_mutex by render threads, or with the hook stopped.
    bool fail(const char *message);
    void warn(const char *message);
};

Runtime &runtime();
ComPtr<ID3D12PipelineState> create_pipeline(ID3D12PipelineState *original,
                                            engine::PipelineArguments &arguments, void *root,
                                            Program program, std::string &error);
void *pipeline_hook(void *context, uint64_t hash, void *cache, void *pass, void *layout, void *root,
                    uint32_t topology, uint32_t target_count, void *target_formats,
                    uint32_t depth_format, char compute, void *flags, uint64_t reserved_a,
                    int reserved_b);
} // namespace goo
