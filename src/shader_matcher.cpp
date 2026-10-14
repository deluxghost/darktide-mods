#include "shader_matcher.h"
#include "shader_contracts.generated.h"
#include "shader_resources.h"
#include <filesystem>
#include <vector>

namespace goo {
bool ShaderMatcher::initialize(const char *directory, std::string &error) {
    const auto path =
        std::filesystem::absolute(std::filesystem::path(directory) / "dxcompiler.dll");
    return reader_.initialize(path.wstring(), error);
}

bool ShaderMatcher::identify(void *pass, const engine::Functions &engine, Program &program,
                             std::string &error) {
    const auto *source = engine::read<const uint8_t *>(pass, engine::PixelBytes);
    const auto compressed = engine::read<uint64_t>(pass, engine::PixelCompressedSize);
    const auto expanded = engine::read<uint32_t>(pass, engine::PixelExpandedSize);
    program = Program::Count;
    if (!source && !compressed && !expanded)
        return true;
    if (!source || !compressed || !expanded || !dtintutils_is_readable_range(source, compressed)) {
        error = "Invalid live pixel shader storage";
        return false;
    }
    // Cache content, not storage addresses: resource memory can be reused after unloading.
    const std::string key(reinterpret_cast<const char *>(source), size_t(compressed));
    CachedProgram *cached;
    {
        std::lock_guard<std::mutex> lock(programs_mutex_);
        cached = &programs_.try_emplace(key).first->second;
    }
    std::call_once(cached->initialized, [&] {
        cached->valid =
            inspect(source, compressed, expanded, engine, cached->program, cached->error);
    });
    program = cached->program;
    error = cached->error;
    return cached->valid;
}

bool ShaderMatcher::inspect(const uint8_t *source, uint64_t compressed, uint32_t expanded,
                            const engine::Functions &engine, Program &program, std::string &error) {
    std::vector<uint8_t> bytes(expanded);
    if (engine.decompress(source, intptr_t(compressed), bytes.data(), expanded, 1, 0, 0, nullptr, 0,
                          nullptr, nullptr, nullptr, 0, 3) != expanded) {
        error = "Pixel shader decompression failed";
        return false;
    }
    bool candidate;
    if (!shader_candidate(bytes, ShaderResourceContracts, candidate, error))
        return false;
    if (candidate) {
        std::string text;
        ShaderAnalysis analysis;
        {
            std::lock_guard<std::mutex> lock(reader_mutex_);
            if (!reader_.disassemble(bytes, text, error))
                return false;
        }
        if (!analyze_shader(text, analysis, error) ||
            !identify_shader(analysis, ShaderContracts, program, error))
            return false;
    }
    return true;
}
} // namespace goo
