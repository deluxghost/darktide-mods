#include "runtime.h"
#include <unordered_map>

namespace goo {
namespace {
struct CachedPipeline {
    explicit CachedPipeline(ID3D12PipelineState *pipeline) : original(pipeline) {
    }
    // Retaining the original PSO prevents address reuse from corrupting this cache.
    ComPtr<ID3D12PipelineState> original;
    ComPtr<ID3D12PipelineState> replacement;
    std::once_flag initialized;
};
thread_local std::unordered_map<ID3D12PipelineState *, ID3D12PipelineState *> thread_pipelines;
std::unordered_map<ID3D12PipelineState *, CachedPipeline> shared_pipelines;
std::mutex shared_pipeline_mutex;

void report_failure(Program program, const std::string &error) {
    if (error.empty())
        return;
    auto &state = runtime();
    // A missing shared composite would hide every successfully replaced outline.
    if (program == Program::Composite) {
        std::lock_guard<std::mutex> lock(state.pipeline_mutex);
        state.fail(error.c_str());
        return;
    }
    state.warn((error + "; original rendering retained for this program").c_str());
}

ComPtr<ID3D12PipelineState> identify_pipeline(ID3D12PipelineState *original,
                                              engine::PipelineArguments &arguments, void *root) {
    auto &state = runtime();
    Program program;
    std::string error;
    if (!state.matcher.identify(arguments.pass, state.engine, program, error)) {
        report_failure(program, error);
        return {};
    }
    if (program == Program::Count)
        return {};
    auto replacement = create_pipeline(original, arguments, root, program, error);
    if (!replacement && !error.empty())
        report_failure(program, std::string(ProgramNames[static_cast<size_t>(program)]) + ": " + error);
    return replacement;
}

ID3D12PipelineState *resolve_pipeline(ID3D12PipelineState *original,
                                      engine::PipelineArguments &arguments, void *root) {
    CachedPipeline *pipeline;
    {
        std::lock_guard<std::mutex> lock(shared_pipeline_mutex);
        const auto entry = shared_pipelines.try_emplace(original, original).first;
        pipeline = &entry->second;
    }
    // Shader compilation must not hold the shared cache lock.
    std::call_once(pipeline->initialized,
                   [&] { pipeline->replacement = identify_pipeline(original, arguments, root); });
    return pipeline->replacement ? pipeline->replacement.Get() : original;
}
} // namespace

void *pipeline_hook(void *context, uint64_t hash, void *cache, void *pass, void *layout, void *root,
                    uint32_t topology, uint32_t target_count, void *target_formats,
                    uint32_t depth_format, char compute, void *flags, uint64_t reserved_a,
                    int reserved_b) {
    auto &state = runtime();
    state.callbacks.fetch_add(1, std::memory_order_acquire);
    auto *result = reinterpret_cast<engine::Pipeline>(state.hook.trampoline)(
        context, hash, cache, pass, layout, root, topology, target_count, target_formats,
        depth_format, compute, flags, reserved_a, reserved_b);
    if (state.enabled.load(std::memory_order_acquire) && !compute) {
        auto *original = static_cast<ID3D12PipelineState *>(result);
        const auto found = thread_pipelines.find(original);
        if (found != thread_pipelines.end()) {
            result = found->second;
        } else {
            engine::PipelineArguments arguments{};
            arguments.pass = pass;
            arguments.topology = topology;
            arguments.target_count = target_count;
            arguments.depth_format = depth_format;
            arguments.rasterizer_flag =
                uint8_t(!flags || engine::read<int32_t>(flags, engine::RasterizerFlags) == 0);
            if (layout) {
                arguments.elements = engine::read<const void *>(layout, engine::LayoutElements);
                arguments.element_count = engine::read<uint32_t>(layout, engine::LayoutCount);
            }
            if (target_count > arguments.target_formats.size() ||
                (target_count && !target_formats)) {
                std::lock_guard<std::mutex> lock(state.pipeline_mutex);
                state.fail("Live target contract changed");
            } else {
                if (target_count) {
                    std::memcpy(arguments.target_formats.data(), target_formats,
                                size_t(target_count) * sizeof(uint32_t));
                }
                result = resolve_pipeline(original, arguments, root);
                thread_pipelines.emplace(original, static_cast<ID3D12PipelineState *>(result));
            }
        }
    }
    state.callbacks.fetch_sub(1, std::memory_order_release);
    return result;
}
} // namespace goo
