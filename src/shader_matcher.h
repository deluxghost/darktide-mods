#pragma once
#include "dxil_reader.h"
#include "engine.h"
#include "shader_contract.h"
#include <mutex>
#include <unordered_map>

namespace goo {
class ShaderMatcher {
  public:
    bool initialize(const char *directory, std::string &error);
    bool identify(void *pass, const engine::Functions &engine, Program &program,
                  std::string &error);

  private:
    struct CachedProgram {
        std::once_flag initialized;
        Program program = Program::Count;
        bool valid = false;
        std::string error;
    };
    std::mutex programs_mutex_;
    std::mutex reader_mutex_;
    std::unordered_map<std::string, CachedProgram> programs_;
    DxilReader reader_;
    bool inspect(const uint8_t *source, uint64_t compressed, uint32_t expanded,
                 const engine::Functions &engine, Program &program, std::string &error);
};
} // namespace goo
