#include "runtime.h"
#include "good_old_outlines.h"
#include <cstdio>
#include <string>

namespace goo {
namespace {
Runtime state;

bool load_shader(const std::string &path, std::vector<uint8_t> &bytes, char *error, int capacity) {
    auto *file = std::fopen(path.c_str(), "rb");
    if (!file) {
        std::snprintf(error, capacity, "Cannot open shader: %s", path.c_str());
        return false;
    }
    const bool seeked = std::fseek(file, 0, SEEK_END) == 0;
    const auto size = seeked ? std::ftell(file) : -1L;
    if (size <= 0 || std::fseek(file, 0, SEEK_SET)) {
        std::fclose(file);
        std::snprintf(error, capacity, "Invalid shader input: %s", path.c_str());
        return false;
    }
    bytes.resize(size_t(size));
    const bool complete = std::fread(bytes.data(), 1, bytes.size(), file) == bytes.size();
    const int closed = std::fclose(file);
    if (!complete || closed) {
        std::snprintf(error, capacity, "Cannot read shader: %s", path.c_str());
        return false;
    }
    return true;
}

bool load_shaders(const char *directory, char *error, int capacity) {
    const std::string prefix = std::string(directory) + "/";
    for (size_t index = 0; index < ProgramNames.size(); ++index) {
        const auto path = prefix + ProgramNames[index];
        auto &shader = state.shaders[index];
        if (!load_shader(path + ".dxil", shader, error, capacity)) {
            return false;
        }
    }
    return true;
}
} // namespace

Runtime &runtime() {
    return state;
}

bool Runtime::fail(const char *message) {
    if (!failure.load(std::memory_order_relaxed)) {
        std::snprintf(failure_message, sizeof(failure_message), "%s", message);
        failure.store(failure_message, std::memory_order_release);
    }
    enabled.store(false, std::memory_order_release);
    return false;
}

void Runtime::warn(const char *message) {
    std::lock_guard<std::mutex> lock(warnings_mutex);
    warnings.emplace_back(message);
}
} // namespace goo

const void *GoodOldOutlines_GetConfig(uint32_t *size, char *error, int capacity) {
    return goo::runtime().config.snapshot(size, error, capacity);
}

int GoodOldOutlines_ApplyConfig(const void *data, uint32_t size, char *error, int capacity) {
    return goo::runtime().config.apply(data, size, error, capacity);
}

int GoodOldOutlines_RestoreConfig(char *error, int capacity) {
    return goo::runtime().config.restore(error, capacity);
}

int GoodOldOutlines_Start(const char *shader_directory, char *error, int capacity) {
    auto &state = goo::runtime();
    if (state.hook.active) {
        std::snprintf(error, capacity, "Outline hook is already installed");
        return 0;
    }
    if (const auto *failure = state.failure.load(std::memory_order_acquire)) {
        std::snprintf(error, capacity, "Outline runtime failed: %s", failure);
        return 0;
    }
    if (!goo::load_shaders(shader_directory, error, capacity)) {
        return 0;
    }
    if (!state.engine.pipeline.start) {
        goo::engine::Functions functions;
        if (!goo::engine::locate_functions(functions, error, capacity))
            return 0;
        state.engine = functions;
    }
    std::string message;
    if (!state.matcher.initialize(shader_directory, message)) {
        std::snprintf(error, capacity, "%s", message.c_str());
        return 0;
    }
    const auto &entry = state.engine.pipeline;
    return dtintutils_hook_install_exact(&state.hook, entry.start,
                                         reinterpret_cast<void *>(goo::pipeline_hook), entry.start,
                                         state.engine.hook_length, error, capacity);
}

int GoodOldOutlines_SetEnabled(int enabled) {
    auto &state = goo::runtime();
    std::lock_guard<std::mutex> lock(state.pipeline_mutex);
    if (!state.hook.active || (enabled != 0 && enabled != 1) ||
        (enabled && state.failure.load(std::memory_order_acquire))) {
        return 0;
    }
    state.enabled.store(enabled != 0, std::memory_order_release);
    return 1;
}

const char *GoodOldOutlines_GetError(void) {
    return goo::runtime().failure.load(std::memory_order_acquire);
}

int GoodOldOutlines_PollWarning(char *message, int capacity) {
    auto &state = goo::runtime();
    std::lock_guard<std::mutex> lock(state.warnings_mutex);
    if (state.warnings.empty())
        return 0;
    const auto &warning = state.warnings.front();
    if (!message || capacity <= 0 || warning.size() >= size_t(capacity))
        return -1;
    std::memcpy(message, warning.c_str(), warning.size() + 1);
    state.warnings.pop_front();
    return 1;
}

int GoodOldOutlines_Remove(char *error, int capacity) {
    auto &state = goo::runtime();
    state.enabled.store(false, std::memory_order_release);
    if (state.callbacks.load()) {
        std::snprintf(error, capacity, "Runtime callbacks active");
        return 0;
    }
    return !state.hook.active || dtintutils_hook_remove(&state.hook, error, capacity);
}
