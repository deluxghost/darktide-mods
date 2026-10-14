#include "shader_contract.h"
#include "shader_ir.h"

namespace goo {
namespace {
bool classify(std::string_view header, Program &program, std::string &error) {
    const bool thickness = header.find("outline_thickness;") != header.npos;
    const bool outline =
        thickness && header.find("__BINDLESS_TEX2D_scanline_vertical;") != header.npos;
    const bool combat = thickness && header.find("__BINDLESS_TEX2D_warp_breakup;") != header.npos;
    const bool composite = header.find("outline_inner_params;") != header.npos;
    const unsigned candidates = unsigned(outline) + unsigned(combat) + unsigned(composite);
    if (candidates > 1 || (thickness && !candidates)) {
        error = "Ambiguous or unknown outline resource structure";
        return false;
    }
    if (outline)
        program = Program::Outline;
    if (combat)
        program = Program::Combat;
    if (composite)
        program = Program::Composite;
    return true;
}

} // namespace

bool analyze_shader(std::string_view disassembly, ShaderAnalysis &result, std::string &error) {
    result = {};
    const auto code = disassembly.find("target datalayout");
    if (code == disassembly.npos) {
        error = "DXIL disassembly has no module";
        return false;
    }
    const auto header = disassembly.substr(0, code);
    if (header.find("; Pixel Shader") == header.npos)
        return true;
    return classify(header, result.program, error) &&
           canonical_shader_ir(disassembly.substr(code), result, error);
}

bool validate_shader(const ShaderAnalysis &analysis, const ShaderContract &contract,
                     std::string &error) {
    if (analysis.properties != contract.properties) {
        error = "Shader resource, layout, signature or execution properties changed";
        return false;
    }
    if (analysis.instructions != contract.instructions) {
        error = "Shader instructions or instruction metadata changed";
        return false;
    }
    return true;
}

bool identify_shader(const ShaderAnalysis &analysis, std::span<const ShaderContract> contracts,
                     Program &program, std::string &error) {
    program = Program::Count;
    if (analysis.instructions.empty())
        return true;
    for (size_t index = 0; index < contracts.size(); ++index) {
        if (analysis.properties != contracts[index].properties ||
            analysis.instructions != contracts[index].instructions)
            continue;
        if (program != Program::Count) {
            error = "Ambiguous semantic shader contract";
            return false;
        }
        program = static_cast<Program>(index);
    }
    // A shared interface alone does not identify an algorithm in an unrelated shader.
    if (program != Program::Count || analysis.program == Program::Count)
        return true;
    validate_shader(analysis, contracts[static_cast<size_t>(analysis.program)], error);
    error = std::string(ProgramNames[static_cast<size_t>(analysis.program)]) + ": " + error;
    return false;
}
} // namespace goo
