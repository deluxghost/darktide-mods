#pragma once
#include <array>
#include <string>
#include <string_view>
#include <span>

namespace goo {
enum class Program : size_t { Outline, Combat, Composite, Count };
inline constexpr size_t ProgramCount = static_cast<size_t>(Program::Count);
inline constexpr std::array<const char *, ProgramCount> ProgramNames = {"outline", "combat",
                                                                        "composite"};

struct ShaderContract {
    std::string_view bindings;
    std::string_view instructions;
};

struct ShaderAnalysis {
    Program program = Program::Count;
    std::string bindings;
    std::string instructions;
};

// Canonicalizes decoded DXIL, including resource/signature metadata. It never compiles a shader.
bool analyze_shader(std::string_view disassembly, ShaderAnalysis &result, std::string &error);
bool validate_shader(const ShaderAnalysis &analysis, const ShaderContract &contract,
                     std::string &error);
bool identify_shader(const ShaderAnalysis &analysis, std::span<const ShaderContract> contracts,
                     Program &program, std::string &error);
} // namespace goo
