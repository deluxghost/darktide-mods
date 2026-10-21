#include "dxil_reader.h"
#include "shader_contract.h"
#include "shader_resources.h"
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <vector>

namespace {
std::vector<uint8_t> read_file(const std::filesystem::path &path) {
    std::ifstream input(path, std::ios::binary);
    if (!input)
        throw std::runtime_error("Cannot open shader: " + path.string());
    return {(std::istreambuf_iterator<char>(input)), {}};
}

goo::ShaderAnalysis analyze(goo::DxilReader &reader, const std::filesystem::path &path) {
    const auto bytes = read_file(path);
    std::string text, error;
    goo::ShaderAnalysis result;
    if (!reader.disassemble(bytes, text, error) || !goo::analyze_shader(text, result, error))
        throw std::runtime_error(path.string() + ": " + error);
    return result;
}

void write_literal(std::ostream &output, std::string_view text) {
    constexpr size_t LiteralChunkSize = 4096;
    for (size_t offset = 0; offset < text.size(); offset += LiteralChunkSize) {
        output << "R\"GOO(" << text.substr(offset, LiteralChunkSize) << ")GOO\"\n";
    }
}

void generate(goo::DxilReader &reader, const std::filesystem::path &directory,
              const char *output_path) {
    std::ofstream output(output_path, std::ios::binary);
    if (!output)
        throw std::runtime_error("Cannot open contract header output");
    output << "#pragma once\n#include \"shader_contract.h\"\n#include "
              "\"shader_resources.h\"\nnamespace goo {\n";
    for (const auto *name : goo::ProgramNames) {
        const auto bytes = read_file(directory / (std::string(name) + ".dxil"));
        std::vector<goo::ShaderResource> resources;
        std::string error;
        if (!goo::read_shader_resources(bytes, resources, error))
            throw std::runtime_error(error);
        output << "inline constexpr std::array<ShaderResource, " << resources.size() << "> " << name
               << "Resources = {{\n";
        for (const auto &resource : resources) {
            output << "{";
            for (const auto value : resource)
                output << value << "u,";
            output << "},\n";
        }
        output << "}};\n";
    }
    output << "inline constexpr std::array<std::span<const ShaderResource>, ProgramCount> "
              "ShaderResourceContracts = {\n";
    for (const auto *name : goo::ProgramNames)
        output << name << "Resources,\n";
    output
        << "};\ninline constexpr std::array<ShaderContract, ProgramCount> ShaderContracts = {{\n";
    for (size_t index = 0; index < goo::ProgramCount; ++index) {
        const auto result =
            analyze(reader, directory / (std::string(goo::ProgramNames[index]) + ".dxil"));
        if (static_cast<size_t>(result.program) != index)
            throw std::runtime_error("Reference shader family differs");
        output << "{\n";
        write_literal(output, result.properties);
        output << ",\n";
        write_literal(output, result.instructions);
        output << "},\n";
    }
    output << "}};\n}\n";
    if (!output)
        throw std::runtime_error("Cannot write contract header");
}

} // namespace

int main(int argc, char **argv) {
    try {
        if (argc != 3)
            throw std::runtime_error("Usage: contracts reference-directory output-header");
        goo::DxilReader reader;
        std::string error;
        const auto library =
            std::filesystem::absolute(std::filesystem::path(argv[0])).parent_path() /
            "dxcompiler.dll";
        if (!reader.initialize(library.wstring(), error))
            throw std::runtime_error(error);
        generate(reader, argv[1], argv[2]);
        return 0;
    } catch (const std::exception &error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
