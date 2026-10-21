#include "shader_ir.h"
#include <algorithm>
#include <cctype>
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

bool identifier_char(char value) {
    return std::isalnum(static_cast<unsigned char>(value)) || value == '_' || value == '.' ||
           value == '$' || value == '-';
}

size_t identifier_end(std::string_view text, size_t first) {
    if (text[first] == '"') {
        const auto end = text.find('"', first + 1);
        return end == text.npos ? text.size() : end + 1;
    }
    auto end = first;
    while (end < text.size() && identifier_char(text[end]))
        ++end;
    return end;
}

std::string clean_line(std::string_view text) {
    std::string result;
    bool quoted = false, space = false;
    for (char value : trim(text)) {
        if (value == '"')
            quoted = !quoted;
        if (!quoted && value == ';')
            break;
        if (!quoted && std::isspace(static_cast<unsigned char>(value))) {
            space = true;
            continue;
        }
        if (space && !result.empty())
            result += ' ';
        space = false;
        result += value;
    }
    return std::string(trim(result));
}

std::vector<std::string> split_fields(std::string_view text, char separator = ',') {
    std::vector<std::string> fields;
    int depth = 0;
    bool quoted = false;
    size_t first = 0;
    for (size_t index = 0; index < text.size(); ++index) {
        const char value = text[index];
        if (value == '"')
            quoted = !quoted;
        if (quoted)
            continue;
        if (value == '(' || value == '[' || value == '{' || value == '<')
            ++depth;
        if (value == ')' || value == ']' || value == '}' || value == '>')
            --depth;
        if (depth == 0 && value == separator) {
            const auto field = trim(text.substr(first, index - first));
            if (!field.empty())
                fields.emplace_back(field);
            first = index + 1;
        }
    }
    const auto field = trim(text.substr(first));
    if (!field.empty())
        fields.emplace_back(field);
    return fields;
}

std::string join_fields(const std::vector<std::string> &fields, std::string_view separator) {
    std::string result;
    for (const auto &field : fields) {
        if (!result.empty())
            result += separator;
        result += field;
    }
    return result;
}

bool execution_root(std::string_view name) {
    // Final DXIL uses dx.* execution roots; these exceptions are reflection/source data.
    return name.starts_with("dx.") && name != "dx.valver" && name != "dx.typeAnnotations" &&
           name != "dx.counters" && !name.starts_with("dx.source.") && !name.starts_with("dx.dbg.");
}

struct Module {
    std::map<std::string, std::string> types, attributes, nodes, roots;
    std::map<std::string, size_t> reflected_names;
    std::vector<std::string> targets, code, declarations;
};

bool parse_module(std::string_view text, Module &module, std::string &error) {
    std::istringstream input{std::string(text)};
    std::string line;
    bool entry_pending = false;
    while (std::getline(input, line)) {
        auto raw = trim(line);
        if (raw.starts_with("; <label>:")) {
            raw.remove_prefix(10);
            line = std::string(raw.substr(0, raw.find_first_not_of("0123456789"))) + ":";
        }
        auto value = clean_line(line);
        if (value.empty() || value.starts_with("source_filename ="))
            continue;
        if (value.starts_with("!") || value.starts_with("attributes #") ||
            value.find(" = type ") != value.npos) {
            const auto equal = value.find(" = ");
            if (equal == value.npos) {
                error = "Invalid DXIL declaration";
                return false;
            }
            auto name = value.substr(0, equal);
            auto body = value.substr(equal + 3);
            auto *definitions = &module.types;
            if (name.starts_with("attributes #")) {
                name.erase(0, 12);
                definitions = &module.attributes;
            } else if (name.starts_with("!")) {
                name.erase(0, 1);
                if (name.empty()) {
                    error = "Empty DXIL metadata name";
                    return false;
                }
                definitions = std::isdigit(static_cast<unsigned char>(name.front()))
                                  ? &module.nodes
                                  : &module.roots;
            } else {
                name.erase(0, 1);
                body.erase(0, 5);
            }
            if (!definitions->emplace(name, body).second) {
                error = "Duplicate DXIL declaration: " + name;
                return false;
            }
            continue;
        }
        if (value.starts_with("target ")) {
            module.targets.push_back(value);
            continue;
        }
        if (value.starts_with("declare ")) {
            module.declarations.push_back(value);
            continue;
        }
        if (value.find("call void @llvm.dbg.") != value.npos)
            continue;
        auto fields = split_fields(value);
        std::erase_if(fields, [](const auto &field) { return field.starts_with("!dbg "); });
        value = join_fields(fields, ", ");
        if (entry_pending) {
            entry_pending = false;
            if (value.ends_with(':'))
                continue;
        }
        if (value.ends_with(':') && value.front() != '%')
            value = "%" + value;
        entry_pending = value.starts_with("define ");
        module.code.push_back(value);
    }
    return true;
}

bool metadata_list(const Module &module, std::string_view reference,
                   std::vector<std::string> &fields, std::string &error) {
    std::string body(reference);
    if (!reference.starts_with("!{")) {
        if (!reference.starts_with('!')) {
            error = "Invalid DXIL metadata reference";
            return false;
        }
        const auto found = module.nodes.find(std::string(reference.substr(1)));
        if (found == module.nodes.end()) {
            error = "Missing DXIL metadata node: " + body;
            return false;
        }
        body = found->second;
    }
    if (!body.starts_with("!{") || !body.ends_with('}')) {
        error = "Invalid DXIL metadata list";
        return false;
    }
    fields = split_fields(std::string_view(body).substr(2, body.size() - 3));
    return true;
}

bool mark_reflected_names(Module &module, std::string &error) {
    for (const auto &[name, body] : module.roots) {
        if (name != "dx.resources" && name != "dx.entryPoints")
            continue;
        std::vector<std::string> roots;
        if (!metadata_list(module, body, roots, error))
            return false;
        for (const auto &root : roots) {
            std::vector<std::string> fields;
            if (!metadata_list(module, root, fields, error))
                return false;
            if (name == "dx.entryPoints") {
                module.reflected_names.emplace(root.substr(1), 1);
                continue;
            }
            for (const auto &group : fields) {
                if (group == "null")
                    continue;
                std::vector<std::string> resources;
                if (!metadata_list(module, group, resources, error))
                    return false;
                for (const auto &resource : resources)
                    module.reflected_names.emplace(resource.substr(1), 2);
            }
        }
    }
    return true;
}

class CanonicalText {
  public:
    CanonicalText(const Module &module, std::string &error) : module_(module), error_(error) {
    }

    std::string rewrite(std::string_view text) {
        std::string result;
        for (size_t offset = 0; offset < text.size();) {
            const char kind = text[offset];
            if (kind == '"') {
                const auto end = identifier_end(text, offset);
                result += text.substr(offset, end - offset);
                offset = end;
                continue;
            }
            const auto first = offset + 1;
            const bool identifier =
                first < text.size() && (((kind == '%' || kind == '@') &&
                                         (identifier_char(text[first]) || text[first] == '"')) ||
                                        ((kind == '!' || kind == '#') &&
                                         std::isdigit(static_cast<unsigned char>(text[first]))));
            if (!identifier) {
                result += kind;
                ++offset;
                continue;
            }
            offset = identifier_end(text, first);
            result += rename(kind, std::string(text.substr(first, offset - first)));
        }
        return result;
    }

    void append(std::string_view text) {
        output += rewrite(text) + "\n";
    }
    void reset_locals() {
        locals_.clear();
    }

    bool finish() {
        for (size_t index = 0; index < metadata_.size(); ++index) {
            const auto name = metadata_[index];
            const auto found = module_.nodes.find(name);
            if (found == module_.nodes.end())
                return fail("Missing DXIL metadata node: !" + name);
            auto body = found->second;
            const auto reflected = module_.reflected_names.find(name);
            if (reflected != module_.reflected_names.end()) {
                std::vector<std::string> fields;
                if (!metadata_list(module_, body, fields, error_))
                    return false;
                if (fields.size() <= reflected->second ||
                    !fields[reflected->second].starts_with("!\""))
                    return fail("Invalid DXIL reflected name");
                fields[reflected->second] = "!\"\"";
                body = "!{" + join_fields(fields, ", ") + "}";
            }
            output += "!" + std::to_string(index) + "=" + rewrite(body) + "\n";
        }
        return valid_;
    }

    bool uses_global(std::string_view name) const {
        return used_globals_.contains(std::string(name));
    }
    std::string output;

  private:
    bool fail(std::string message) {
        valid_ = false;
        error_ = std::move(message);
        return false;
    }

    std::string type_layout(const std::string &name) {
        const auto found = type_layouts_.find(name);
        if (found != type_layouts_.end())
            return found->second;
        if (!active_types_.insert(name).second) {
            fail("Recursive DXIL type: %" + name);
            return {};
        }
        // Driver-visible structure matters; aliases and duplicate reflection types do not.
        auto layout = rewrite(module_.types.at(name));
        active_types_.erase(name);
        type_layouts_.emplace(name, layout);
        return layout;
    }

    std::string rename(char kind, const std::string &name) {
        if (kind == '#') {
            const auto found = module_.attributes.find(name);
            if (found == module_.attributes.end()) {
                fail("Missing DXIL function attributes: #" + name);
                return {};
            }
            const auto &body = found->second;
            if (!body.starts_with('{') || !body.ends_with('}')) {
                fail("Invalid DXIL function attributes");
                return {};
            }
            auto fields = split_fields(std::string_view(body).substr(1, body.size() - 2), ' ');
            std::sort(fields.begin(), fields.end());
            return "{" + join_fields(fields, " ") + "}";
        }
        if (kind == '@') {
            used_globals_.insert(name);
            if (name.starts_with("dx.op.") || name.starts_with("llvm."))
                return "@" + name;
        }
        if (kind == '%') {
            if (module_.types.contains(name))
                return type_layout(name);
            const auto index = locals_.try_emplace(name, locals_.size()).first->second;
            return "%v" + std::to_string(index);
        }
        const auto key = std::make_pair(kind, name);
        const auto found = identifiers_.find(key);
        if (found != identifiers_.end())
            return found->second;
        std::string result;
        if (kind == '!') {
            result = "!" + std::to_string(metadata_.size());
            metadata_.push_back(name);
        } else {
            result = "@g" + std::to_string(globals_++);
        }
        identifiers_.emplace(key, result);
        return result;
    }

    const Module &module_;
    std::string &error_;
    bool valid_ = true;
    size_t globals_ = 0;
    std::map<std::string, size_t> locals_;
    std::map<std::string, std::string> type_layouts_;
    std::set<std::string> active_types_;
    std::map<std::pair<char, std::string>, std::string> identifiers_;
    std::set<std::string> used_globals_;
    std::vector<std::string> metadata_;
};
} // namespace

bool canonical_shader_ir(std::string_view text, ShaderAnalysis &result, std::string &error) {
    Module module;
    if (!parse_module(text, module, error) || !mark_reflected_names(module, error))
        return false;
    CanonicalText properties(module, error), instructions(module, error);
    std::sort(module.targets.begin(), module.targets.end());
    for (const auto &target : module.targets)
        properties.append(target);
    for (const auto &[name, body] : module.roots) {
        if (execution_root(name))
            properties.append("!" + name + "=" + body);
    }
    for (const auto &line : module.code) {
        if (line.starts_with("define "))
            instructions.reset_locals();
        instructions.append(line);
    }
    std::vector<std::string> declarations;
    for (const auto &line : module.declarations) {
        const auto first = line.find('@') + 1;
        const auto end = identifier_end(line, first);
        if (instructions.uses_global(std::string_view(line).substr(first, end - first)))
            declarations.push_back(instructions.rewrite(line));
    }
    std::sort(declarations.begin(), declarations.end());
    for (const auto &line : declarations)
        instructions.output += line + "\n";
    if (!properties.finish() || !instructions.finish())
        return false;
    result.properties = std::move(properties.output);
    result.instructions = std::move(instructions.output);
    return true;
}
} // namespace goo
