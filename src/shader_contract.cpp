#include "shader_contract.h"
#include <cctype>
#include <functional>
#include <map>
#include <set>
#include <sstream>
#include <vector>

namespace goo {
namespace {
std::string_view trim(std::string_view text) {
    const auto first = text.find_first_not_of(" \t\r\n");
    if (first == text.npos)
        return {};
    return text.substr(first, text.find_last_not_of(" \t\r\n") - first + 1);
}

std::string compact(std::string_view text) {
    std::string result;
    bool quoted = false, space = false;
    for (char value : trim(text)) {
        if (value == '"')
            quoted = !quoted;
        if (!quoted && std::isspace(static_cast<unsigned char>(value))) {
            space = true;
            continue;
        }
        if (space && !result.empty())
            result += ' ';
        space = false;
        result += value;
    }
    return result;
}

using Rename = std::function<std::string(char, std::string_view)>;

bool identifier_char(char value) {
    return std::isalnum(static_cast<unsigned char>(value)) || value == '_' || value == '.' ||
           value == '$' || value == '-';
}

std::string rewrite_ids(std::string_view line, const Rename &rename) {
    std::string result;
    bool quoted = false;
    for (size_t offset = 0; offset < line.size();) {
        const char value = line[offset];
        if (value == '"')
            quoted = !quoted;
        const bool numbered = (value == '!' || value == '#') && offset + 1 < line.size() &&
                              std::isdigit(static_cast<unsigned char>(line[offset + 1]));
        const bool local = value == '%' && offset + 1 < line.size() &&
                           (identifier_char(line[offset + 1]) || line[offset + 1] == '"');
        if (!quoted && (numbered || local)) {
            const auto first = ++offset;
            if (line[offset] == '"') {
                ++offset;
                while (offset < line.size() && line[offset] != '"')
                    ++offset;
                if (offset < line.size())
                    ++offset;
            } else {
                while (offset < line.size() && identifier_char(line[offset]))
                    ++offset;
            }
            result += value;
            result += rename(value, line.substr(first, offset - first));
        } else {
            result += value;
            ++offset;
        }
    }
    return compact(result);
}

bool classify(std::string_view header, Program &program, std::string &error) {
    if (header.find("; Pixel Shader") == header.npos)
        return true;
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

bool canonical_ir(std::string_view text, ShaderAnalysis &result, std::string &error) {
    std::map<std::string, std::string> nodes, roots;
    std::vector<std::string> instructions;
    std::set<std::string> types;
    std::istringstream input{std::string(text)};
    std::string line;
    bool entry_pending = false;
    while (std::getline(input, line)) {
        auto value = trim(line);
        if (value.starts_with("; <label>:")) {
            entry_pending = false;
            value.remove_prefix(10);
            instructions.emplace_back(
                "%" + std::string(value.substr(0, value.find_first_not_of("0123456789"))) + ":");
            continue;
        }
        if (value.empty() || value.front() == ';' || value.starts_with("source_filename ="))
            continue;
        const auto comment = value.find(';');
        if (comment != value.npos)
            value = trim(value.substr(0, comment));
        const bool label = value.ends_with(':') && value.find(' ') == value.npos;
        if (entry_pending) {
            if (!label)
                instructions.emplace_back("%0:");
            entry_pending = false;
        }
        if (value.starts_with("define ")) {
            instructions.emplace_back(value);
            entry_pending = true;
            continue;
        }
        const auto type = value.find(" = type ");
        if (type != value.npos && value.front() == '%')
            types.emplace(value.substr(1, type - 1));
        if (label && value.front() != '%') {
            instructions.emplace_back("%" + std::string(value));
            continue;
        }
        if (value.starts_with("!")) {
            const auto equal = value.find(" = ");
            if (equal == value.npos) {
                error = "Invalid DXIL metadata declaration";
                return false;
            }
            const auto name = std::string(value.substr(1, equal - 1));
            const auto body = std::string(value.substr(equal + 3));
            if (std::isdigit(static_cast<unsigned char>(name.front())))
                nodes.emplace(name, body);
            else if (name != "llvm.ident" && name != "dx.valver")
                roots.emplace(name, body);
        } else {
            instructions.emplace_back(value);
        }
    }
    std::map<std::pair<char, std::string>, size_t> identifiers;
    std::map<char, size_t> next_identifier;
    std::vector<std::string> metadata_order;
    bool valid = true;
    const Rename rename = [&](char kind, std::string_view name) {
        if (kind == '%' && types.contains(std::string(name)))
            return std::string(name);
        const auto key = std::make_pair(kind, std::string(name));
        const auto found = identifiers.find(key);
        if (found != identifiers.end())
            return std::to_string(found->second);
        const size_t index = next_identifier[kind]++;
        identifiers.emplace(key, index);
        if (kind == '!') {
            if (!nodes.contains(key.second))
                valid = false;
            metadata_order.push_back(key.second);
        }
        return std::to_string(index);
    };
    for (const auto &instruction : instructions) {
        auto &output =
            instruction.starts_with("target ") || instruction.find(" = type ") != instruction.npos
                ? result.bindings
                : result.instructions;
        output += rewrite_ids(instruction, rename) + "\n";
    }
    for (const auto &[name, body] : roots)
        result.bindings += "!" + name + "=" + rewrite_ids(body, rename) + "\n";
    // Traversal order, rather than original metadata numbers, defines the metadata graph.
    for (size_t index = 0; index < metadata_order.size(); ++index) {
        const auto found = nodes.find(metadata_order[index]);
        if (found == nodes.end()) {
            error = "Missing DXIL metadata node";
            return false;
        }
        result.bindings +=
            "!" + std::to_string(index) + "=" + rewrite_ids(found->second, rename) + "\n";
    }
    if (!valid)
        error = "Invalid DXIL metadata reference";
    return valid;
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
    if (!classify(header, result.program, error))
        return false;
    if (header.find("; Pixel Shader") == header.npos)
        return true;
    return canonical_ir(disassembly.substr(code), result, error);
}

bool validate_shader(const ShaderAnalysis &analysis, const ShaderContract &contract,
                     std::string &error) {
    if (analysis.bindings != contract.bindings) {
        error = "Shader resource bindings, buffer layout or input/output signature changed";
        return false;
    }
    if (analysis.instructions != contract.instructions) {
        error = "Shader instructions or semantic metadata changed";
        return false;
    }
    return true;
}

bool identify_shader(const ShaderAnalysis &analysis, std::span<const ShaderContract> contracts,
                     Program &program, std::string &error) {
    program = Program::Count;
    if (analysis.instructions.empty())
        return true;
    Program candidate = analysis.program;
    for (size_t index = 0; index < contracts.size(); ++index) {
        if (analysis.bindings != contracts[index].bindings)
            continue;
        candidate = static_cast<Program>(index);
        if (analysis.instructions != contracts[index].instructions)
            continue;
        if (program != Program::Count) {
            error = "Ambiguous semantic shader contract";
            return false;
        }
        program = static_cast<Program>(index);
    }
    if (program != Program::Count || candidate == Program::Count)
        return true;
    validate_shader(analysis, contracts[static_cast<size_t>(candidate)], error);
    error = std::string(ProgramNames[static_cast<size_t>(candidate)]) + ": " + error;
    return false;
}
} // namespace goo
