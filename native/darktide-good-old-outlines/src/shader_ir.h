#pragma once
#include "shader_contract.h"

namespace goo {
bool canonical_shader_ir(std::string_view text, ShaderAnalysis &result, std::string &error);
} // namespace goo
