#include "imgui_symbols.h"

#include "dtintutils.h"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <mutex>

namespace imgui_patch
{
namespace
{
constexpr char kDearImguiPrefix[] = "Dear ImGui ";

using ImageSection = DtIntUtilsSection;
using PatternByte = DtIntUtilsPatternByte;

std::mutex g_symbol_mutex;
bool g_symbols_resolved = false;
ResolvedImguiSymbols g_symbols;

bool address_in_section(const ImageSection& section, std::uintptr_t address)
{
    const auto begin = reinterpret_cast<std::uintptr_t>(section.start);
    return address >= begin && address < begin + section.size;
}

bool address_in_any_writable_section(const DtIntUtilsModule& module, std::uintptr_t address)
{
    return dtintutils_is_writable_address(&module, reinterpret_cast<const void*>(address)) != 0;
}

struct TargetReferenceCount
{
    std::uintptr_t target = 0;
    std::uintptr_t first_reference = 0;
    int count = 0;
};

void add_target_reference(std::vector<TargetReferenceCount>* counts, std::uintptr_t target, std::uintptr_t reference)
{
    for (TargetReferenceCount& count : *counts) {
        if (count.target == target) {
            ++count.count;
            return;
        }
    }

    TargetReferenceCount count = {};
    count.target = target;
    count.first_reference = reference;
    count.count = 1;
    counts->push_back(count);
}

bool find_repeated_writable_rip_target(
    const DtIntUtilsModule& module,
    const ImageSection& text_section,
    std::uintptr_t range_start,
    std::uintptr_t range_end,
    std::uintptr_t* target)
{
    if (!address_in_section(text_section, range_start) || !address_in_section(text_section, range_end - 1) || target == nullptr) {
        return false;
    }

    const auto text_address = reinterpret_cast<std::uintptr_t>(text_section.start);
    const std::size_t start_offset = range_start - text_address;
    const std::size_t end_offset = range_end - text_address;
    std::vector<TargetReferenceCount> counts;

    if (end_offset < start_offset + 7) {
        return false;
    }

    for (std::size_t offset = start_offset; offset < end_offset;) {
        const auto instruction_address = text_section.start + offset;
        DtIntUtilsInstruction instruction = {};
        if (!dtintutils_decode(instruction_address, end_offset - offset, &instruction)) {
            ++offset;
            continue;
        }
        for (std::size_t operand_index = 0; operand_index < instruction.operand_count; ++operand_index) {
            const DtIntUtilsOperand& operand = instruction.operands[operand_index];
            if (operand.type == DTINTUTILS_OPERAND_MEMORY && operand.has_absolute &&
                operand.memory_base == DTINTUTILS_REGISTER_RIP &&
                address_in_any_writable_section(module, static_cast<std::uintptr_t>(operand.absolute))) {
                add_target_reference(
                    &counts,
                    static_cast<std::uintptr_t>(operand.absolute),
                    reinterpret_cast<std::uintptr_t>(instruction_address));
            }
        }
        offset += instruction.length;
    }

    std::uintptr_t best_target = 0;
    int candidate_count = 0;
    int best_count = 0;

    for (const TargetReferenceCount& count : counts) {
        if (count.count < 2) {
            continue;
        }

        ++candidate_count;
        if (count.count > best_count) {
            best_count = count.count;
            best_target = count.target;
        }
    }

    if (candidate_count != 1) {
        char message[256] = {};
        std::snprintf(message, sizeof(message), "GImGui storage scan found %d candidates", candidate_count);
        set_last_error(message);
        return false;
    }

    *target = best_target;
    return true;
}

bool contains_bytes(const unsigned char* bytes, std::size_t size, const unsigned char* needle, std::size_t needle_size)
{
    return dtintutils_contains_bytes(bytes, size, needle, needle_size) != 0;
}

using CandidateBodyValidator = bool (*)(const DtIntUtilsFunction& function);

struct CandidateBodyValidatorContext
{
    CandidateBodyValidator validator = nullptr;
};

int validate_candidate_body(
    const DtIntUtilsModule* module,
    const unsigned char* candidate,
    void* opaque_context)
{
    const auto* context = static_cast<const CandidateBodyValidatorContext*>(opaque_context);
    DtIntUtilsFunction function = {};

    if (module == nullptr || context == nullptr || context->validator == nullptr ||
        !dtintutils_function_containing(module, candidate, &function) || function.start != candidate) {
        return false;
    }

    return context->validator(function) ? 1 : 0;
}

bool find_validated_pattern_symbol(
    const DtIntUtilsModule& image,
    const char* name,
    const PatternByte* pattern,
    std::size_t pattern_size,
    CandidateBodyValidator validator,
    std::uintptr_t* address)
{
    const DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_PATTERN(".text", pattern, pattern_size, 1, 0),
        DTINTUTILS_LOCATE_FILTER_FUNCTION_ENTRIES(1, 0),
    };
    const DtIntUtilsLocator locator = {
        name,
        steps,
        sizeof(steps) / sizeof(steps[0]),
    };
    CandidateBodyValidatorContext context = {
        validator,
    };
    const unsigned char* resolved = nullptr;
    char utility_error[512] = {};

    if (address == nullptr || !dtintutils_locate_unique_address_with_validator(
            &image,
            &locator,
            &validate_candidate_body,
            &context,
            &resolved,
            utility_error,
            sizeof(utility_error))) {
        set_last_error(address == nullptr ? "invalid pattern symbol output" : utility_error);
        return false;
    }

    *address = reinterpret_cast<std::uintptr_t>(resolved);
    return true;
}

struct PlatformCallbackAssignment
{
    std::uintptr_t instruction = 0;
    std::uintptr_t function = 0;
    std::uint32_t slot_offset = 0;
};

bool read_platform_callback_assignment(
    const ImageSection& text_section,
    const unsigned char* instruction,
    PlatformCallbackAssignment* assignment)
{
    DtIntUtilsInstruction load_function = {};
    DtIntUtilsInstruction store_callback = {};

    if (instruction == nullptr || assignment == nullptr) {
        return false;
    }
    if (!dtintutils_decode(instruction, 14, &load_function) ||
        load_function.mnemonic != DTINTUTILS_MNEMONIC_LEA || load_function.operand_count != 2 ||
        load_function.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
        load_function.operands[0].size_bits != 64 ||
        load_function.operands[1].type != DTINTUTILS_OPERAND_MEMORY ||
        load_function.operands[1].memory_base != DTINTUTILS_REGISTER_RIP ||
        !load_function.operands[1].has_absolute ||
        !dtintutils_decode(
            instruction + load_function.length,
            14 - load_function.length,
            &store_callback) ||
        store_callback.mnemonic != DTINTUTILS_MNEMONIC_MOV || store_callback.operand_count != 2 ||
        store_callback.operands[0].type != DTINTUTILS_OPERAND_MEMORY ||
        store_callback.operands[0].memory_base != 3 ||
        store_callback.operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
        store_callback.operands[1].register_id != load_function.operands[0].register_id) {
        return false;
    }

    const auto slot_offset = store_callback.operands[0].displacement;
    if (slot_offset <= 0 || static_cast<std::uintptr_t>(slot_offset) >= kContextScanBytes ||
        (slot_offset % static_cast<std::int64_t>(sizeof(std::uintptr_t))) != 0) {
        return false;
    }

    const auto instruction_address = reinterpret_cast<std::uintptr_t>(instruction);
    const auto function = static_cast<std::uintptr_t>(load_function.operands[1].absolute);
    if (!address_in_section(text_section, function)) {
        return false;
    }

    assignment->instruction = instruction_address;
    assignment->function = function;
    assignment->slot_offset = static_cast<std::uint32_t>(slot_offset);
    return true;
}

bool find_platform_clipboard_offsets(
    const ImageSection& text_section,
    std::uintptr_t version_reference,
    std::uintptr_t* get_clipboard_offset,
    std::uintptr_t* set_clipboard_offset)
{
    if (get_clipboard_offset == nullptr || set_clipboard_offset == nullptr ||
        !address_in_section(text_section, version_reference)) {
        return false;
    }

    const auto text_address = reinterpret_cast<std::uintptr_t>(text_section.start);
    const std::size_t reference_offset = version_reference - text_address;
    const std::size_t scan_end = std::min<std::size_t>(text_section.size, reference_offset + 0x200);
    std::vector<PlatformCallbackAssignment> assignments;

    if (scan_end < reference_offset + 14) {
        set_last_error("CreateContext scan range is too small for ImGui platform callback slots");
        return false;
    }

    for (std::size_t offset = reference_offset; offset <= scan_end - 14; ++offset) {
        PlatformCallbackAssignment assignment = {};
        if (read_platform_callback_assignment(
                text_section,
                text_section.start + offset,
                &assignment)) {
            assignments.push_back(assignment);
        }
    }

    std::uintptr_t resolved_get_offset = 0;
    std::uintptr_t resolved_set_offset = 0;
    int candidate_count = 0;

    for (std::size_t index = 0; index + 3 < assignments.size(); ++index) {
        const PlatformCallbackAssignment& first = assignments[index];
        const PlatformCallbackAssignment& second = assignments[index + 1];
        const PlatformCallbackAssignment& third = assignments[index + 2];
        const PlatformCallbackAssignment& fourth = assignments[index + 3];

        if (second.slot_offset != first.slot_offset + sizeof(std::uintptr_t) ||
            third.slot_offset != first.slot_offset + sizeof(std::uintptr_t) * 3 ||
            fourth.slot_offset != first.slot_offset + sizeof(std::uintptr_t) * 5) {
            continue;
        }

        if (fourth.instruction - first.instruction > 0x80) {
            continue;
        }

        ++candidate_count;
        resolved_get_offset = first.slot_offset;
        resolved_set_offset = second.slot_offset;
    }

    if (candidate_count != 1) {
        char message[512] = {};
        int written = std::snprintf(
            message,
            sizeof(message),
            "ImGui platform callback slot scan found %d candidates from %zu assignments",
            candidate_count,
            assignments.size());
        for (std::size_t index = 0;
             index < assignments.size() && index < 12 && written > 0 &&
             static_cast<std::size_t>(written) < sizeof(message);
             ++index) {
            const int appended = std::snprintf(
                message + written,
                sizeof(message) - static_cast<std::size_t>(written),
                " 0x%x",
                assignments[index].slot_offset);
            if (appended <= 0 || static_cast<std::size_t>(appended) >= sizeof(message) - static_cast<std::size_t>(written)) {
                break;
            }
            written += appended;
        }
        set_last_error(message);
        return false;
    }

    *get_clipboard_offset = resolved_get_offset;
    *set_clipboard_offset = resolved_set_offset;
    return true;
}

bool find_add_font_symbol(const DtIntUtilsModule& image, std::uintptr_t* add_font)
{
    static constexpr PatternByte kAddFontPattern[] = {
        {0x40, false}, {0x53, false}, {0x56, false}, {0x57, false}, {0x41, false}, {0x55, false}, {0x41, false}, {0x56, false},
        {0x48, false}, {0x83, false}, {0xec, false}, {0x20, false}, {0x48, false}, {0x83, false}, {0xb9, false}, {0xb0, false},
        {0x02, false}, {0x00, false}, {0x00, false}, {0x00, false}, {0x4c, false}, {0x8b, false}, {0xf2, false}, {0x48, false},
        {0x89, false}, {0x6c, false}, {0x24, false}, {0x50, false}, {0x48, false}, {0x8b, false}, {0xf9, false}, {0x75, false},
        {0x05, false}, {0xe8, false}, {0x00, true}, {0x00, true}, {0x00, true}, {0x00, true}, {0x45, false}, {0x33, false},
        {0xed, false}, {0x4c, false}, {0x89, false}, {0x64, false}, {0x24, false}, {0x58, false}, {0x4c, false}, {0x89, false},
        {0x7c, false}, {0x24, false}, {0x60, false}, {0x41, false}, {0x8d, false}, {0x6d, false}, {0x08, false}, {0x45, false},
        {0x38, false}, {0x6e, false}, {0x35, false}, {0x0f, false}, {0x85, false}, {0x00, true}, {0x00, true}, {0x00, true},
        {0x00, true}, {0x8d, false}, {0x4d, false}, {0x48, false}, {0xff, false}, {0x15, false}, {0x00, true}, {0x00, true},
        {0x00, true}, {0x00, true},
    };

    const std::size_t pattern_size = sizeof(kAddFontPattern) / sizeof(kAddFontPattern[0]);
    const DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_PATTERN(".text", kAddFontPattern, pattern_size, 1, 1),
    };
    const DtIntUtilsLocator locator = {
        "Dear ImGui AddFont",
        steps,
        sizeof(steps) / sizeof(steps[0]),
    };
    const unsigned char* address = nullptr;
    char utility_error[512] = {};

    if (!dtintutils_locate_unique_address(&image, &locator, &address, utility_error, sizeof(utility_error))) {
        set_last_error(utility_error);
        return false;
    }

    *add_font = reinterpret_cast<std::uintptr_t>(address);
    return true;
}

bool find_build_atlas_symbol(const DtIntUtilsModule& image, std::uintptr_t* build_atlas)
{
    static constexpr PatternByte kBuildAtlasPattern[] = {
        {0x40, false}, {0x53, false}, {0x55, false}, {0x56, false}, {0x57, false}, {0x41, false}, {0x54, false},
        {0x48, false}, {0x83, false}, {0xec, false}, {0x20, false}, {0x44, false}, {0x88, false}, {0x41, false},
        {0x51, false}, {0x8b, false}, {0xf2, false}, {0x48, false}, {0x8d, false}, {0x59, false}, {0x52, false},
        {0x48, false}, {0x8b, false}, {0xf9, false}, {0x45, false}, {0x84, false}, {0xc0, false}, {0x74, false},
        {0x00, true}, {0x48, false}, {0x83, false}, {0xb9, false}, {0xb0, false}, {0x02, false}, {0x00, false},
        {0x00, false}, {0x00, false}, {0xc6, false}, {0x03, false}, {0x01, false},
    };
    static constexpr PatternByte kStoreRendererHasTextures[] = {
        {0x44, false}, {0x88, false}, {0x41, false}, {0x51, false},
    };
    static constexpr PatternByte kTexIsBuiltAddress[] = {
        {0x48, false}, {0x8d, false}, {0x59, false}, {0x52, false},
    };
    static constexpr PatternByte kAtlasBuilderCheck[] = {
        {0x48, false}, {0x83, false}, {0xb9, false}, {0xb0, false},
        {0x02, false}, {0x00, false}, {0x00, false}, {0x00, false},
    };
    static constexpr PatternByte kSetTexIsBuilt[] = {
        {0xc6, false}, {0x03, false}, {0x01, false},
    };
    static constexpr PatternByte kStoreFrameCount[] = {
        {0x89, false}, {0xb5, false}, {0xa4, false}, {0x00, false}, {0x00, false}, {0x00, false},
    };
    const DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_PATTERN(
            ".text", kBuildAtlasPattern, sizeof(kBuildAtlasPattern) / sizeof(kBuildAtlasPattern[0]), 1, 0),
        DTINTUTILS_LOCATE_FILTER_PATTERN_NEAR(
            kStoreRendererHasTextures, sizeof(kStoreRendererHasTextures) / sizeof(kStoreRendererHasTextures[0]),
            0, 0x500, 1, 0),
        DTINTUTILS_LOCATE_FILTER_PATTERN_NEAR(
            kTexIsBuiltAddress, sizeof(kTexIsBuiltAddress) / sizeof(kTexIsBuiltAddress[0]), 0, 0x500, 1, 0),
        DTINTUTILS_LOCATE_FILTER_PATTERN_NEAR(
            kAtlasBuilderCheck, sizeof(kAtlasBuilderCheck) / sizeof(kAtlasBuilderCheck[0]), 0, 0x500, 1, 0),
        DTINTUTILS_LOCATE_FILTER_PATTERN_NEAR(
            kSetTexIsBuilt, sizeof(kSetTexIsBuilt) / sizeof(kSetTexIsBuilt[0]), 0, 0x500, 1, 0),
        DTINTUTILS_LOCATE_FILTER_PATTERN_NEAR(
            kStoreFrameCount, sizeof(kStoreFrameCount) / sizeof(kStoreFrameCount[0]), 0, 0x500, 1, 1),
    };
    const DtIntUtilsLocator locator = {
        "Dear ImGui ImFontAtlas build/update",
        steps,
        sizeof(steps) / sizeof(steps[0]),
    };
    const unsigned char* address = nullptr;
    char utility_error[512] = {};

    if (!dtintutils_locate_unique_address(&image, &locator, &address, utility_error, sizeof(utility_error))) {
        set_last_error(utility_error);
        return false;
    }

    *build_atlas = reinterpret_cast<std::uintptr_t>(address);
    return true;
}

bool render_text_candidate_has_expected_body(const DtIntUtilsFunction& function)
{
    const std::size_t scan_size = std::min<std::size_t>(function.size, 0x900);
    const unsigned char* bytes = function.start;

    static constexpr unsigned char kLargeTextLimit[] = {0x48, 0x3d, 0x10, 0x27, 0x00, 0x00};
    static constexpr unsigned char kUtf8AsciiLimit8[] = {0x83, 0xf9, 0x80};
    static constexpr unsigned char kUtf8AsciiLimit32[] = {0x81, 0xf9, 0x80, 0x00, 0x00, 0x00};
    static constexpr unsigned char kNewLineCheck[] = {0x83, 0xf9, 0x0a};
    static constexpr unsigned char kCarriageReturnCheck[] = {0x83, 0xf9, 0x0d};

    return contains_bytes(bytes, scan_size, kLargeTextLimit, sizeof(kLargeTextLimit)) &&
        (contains_bytes(bytes, scan_size, kUtf8AsciiLimit8, sizeof(kUtf8AsciiLimit8)) ||
            contains_bytes(bytes, scan_size, kUtf8AsciiLimit32, sizeof(kUtf8AsciiLimit32))) &&
        contains_bytes(bytes, scan_size, kNewLineCheck, sizeof(kNewLineCheck)) &&
        contains_bytes(bytes, scan_size, kCarriageReturnCheck, sizeof(kCarriageReturnCheck));
}

bool find_render_text_symbol(
    const DtIntUtilsModule& image,
    std::uintptr_t* render_text)
{
    static constexpr PatternByte kRenderTextPattern[] = {
        {0x4c, false}, {0x8b, false}, {0xdc, false}, {0x4d, false}, {0x89, false}, {0x4b, false}, {0x20, false},
        {0xf3, false}, {0x0f, false}, {0x11, false}, {0x54, false}, {0x24, false}, {0x18, false}, {0x49, false},
        {0x89, false}, {0x53, false}, {0x10, false}, {0x49, false}, {0x89, false}, {0x4b, false}, {0x08, false},
        {0x56, false}, {0x41, false}, {0x54, false}, {0x41, false}, {0x57, false}, {0x48, false}, {0x81, false},
        {0xec, false}, {0x00, true}, {0x00, true}, {0x00, true}, {0x00, true},
    };

    const std::size_t pattern_size = sizeof(kRenderTextPattern) / sizeof(kRenderTextPattern[0]);
    return find_validated_pattern_symbol(
        image,
        "Dear ImGui RenderText",
        kRenderTextPattern,
        pattern_size,
        &render_text_candidate_has_expected_body,
        render_text);
}

bool calc_text_size_candidate_has_expected_body(const DtIntUtilsFunction& function)
{
    const std::size_t scan_size = std::min<std::size_t>(function.size, 0x500);
    const unsigned char* bytes = function.start;

    static constexpr unsigned char kNullTextEndStrlenLoop[] = {
        0x48, 0x85, 0xff, 0x75, 0x18, 0x48, 0xc7, 0xc7,
        0xff, 0xff, 0xff, 0xff, 0x0f, 0x1f, 0x44, 0x00,
        0x00, 0x48, 0xff, 0xc7, 0x80, 0x3c, 0x3b, 0x00,
        0x75, 0xf7, 0x48, 0x03, 0xfb,
    };
    static constexpr unsigned char kUtf8AsciiLimit32[] = {0x81, 0xfa, 0x80, 0x00, 0x00, 0x00};
    static constexpr unsigned char kNewLineCheck[] = {0x83, 0xfa, 0x0a};
    static constexpr unsigned char kCarriageReturnCheck[] = {0x83, 0xfa, 0x0d};

    return contains_bytes(bytes, scan_size, kNullTextEndStrlenLoop, sizeof(kNullTextEndStrlenLoop)) &&
        contains_bytes(bytes, scan_size, kUtf8AsciiLimit32, sizeof(kUtf8AsciiLimit32)) &&
        contains_bytes(bytes, scan_size, kNewLineCheck, sizeof(kNewLineCheck)) &&
        contains_bytes(bytes, scan_size, kCarriageReturnCheck, sizeof(kCarriageReturnCheck));
}

bool find_calc_text_size_symbol(
    const DtIntUtilsModule& image,
    std::uintptr_t* calc_text_size)
{
    static constexpr PatternByte kCalcTextSizePattern[] = {
        {0x48, false}, {0x8b, false}, {0xc4, false}, {0x48, false}, {0x89, false}, {0x48, false}, {0x08, false},
        {0x53, false}, {0x56, false}, {0x48, false}, {0x81, false}, {0xec, false}, {0x00, true}, {0x00, true},
        {0x00, true}, {0x00, true}, {0x48, false}, {0x8b, false}, {0x9c, false}, {0x24, false}, {0x00, true},
        {0x00, true}, {0x00, true}, {0x00, true}, {0x48, false}, {0x8b, false}, {0xf2, false}, {0x48, false},
        {0x89, false}, {0x68, false}, {0x10, false}, {0x48, false}, {0x8b, false}, {0xe9, false},
    };

    const std::size_t pattern_size = sizeof(kCalcTextSizePattern) / sizeof(kCalcTextSizePattern[0]);
    return find_validated_pattern_symbol(
        image,
        "Dear ImGui CalcTextSize",
        kCalcTextSizePattern,
        pattern_size,
        &calc_text_size_candidate_has_expected_body,
        calc_text_size);
}

bool add_input_character_candidate_has_expected_body(const DtIntUtilsFunction& function)
{
    const std::size_t scan_size = std::min<std::size_t>(function.size, 0x100);
    const unsigned char* bytes = function.start;

    static constexpr unsigned char kAppAcceptingEventsCheck[] = {
        0x80, 0xb9, 0xe5, 0x0b, 0x00, 0x00, 0x00,
    };
    static constexpr unsigned char kInputEventsQueueLoad[] = {
        0x48, 0x8b, 0x99, 0xe0, 0x00, 0x00, 0x00,
    };
    static constexpr unsigned char kTextEventType[] = {
        0xc7, 0x44, 0x24, 0x20, 0x06, 0x00, 0x00, 0x00,
    };
    static constexpr unsigned char kKeyboardEventSource[] = {
        0xc7, 0x44, 0x24, 0x24, 0x02, 0x00, 0x00, 0x00,
    };

    return contains_bytes(bytes, scan_size, kAppAcceptingEventsCheck, sizeof(kAppAcceptingEventsCheck)) &&
        contains_bytes(bytes, scan_size, kInputEventsQueueLoad, sizeof(kInputEventsQueueLoad)) &&
        contains_bytes(bytes, scan_size, kTextEventType, sizeof(kTextEventType)) &&
        contains_bytes(bytes, scan_size, kKeyboardEventSource, sizeof(kKeyboardEventSource));
}

bool find_add_input_character_symbol(
    const DtIntUtilsModule& image,
    std::uintptr_t* add_input_character)
{
    static constexpr PatternByte kAddInputCharacterPattern[] = {
        {0x85, false}, {0xd2, false}, {0x0f, false}, {0x84, false},
        {0x00, true}, {0x00, true}, {0x00, true}, {0x00, true},
        {0x53, false}, {0x48, false}, {0x83, false}, {0xec, false}, {0x40, false},
    };

    const std::size_t pattern_size = sizeof(kAddInputCharacterPattern) / sizeof(kAddInputCharacterPattern[0]);
    return find_validated_pattern_symbol(
        image,
        "Dear ImGui AddInputCharacter",
        kAddInputCharacterPattern,
        pattern_size,
        &add_input_character_candidate_has_expected_body,
        add_input_character);
}

bool win32_message_handler_candidate_has_expected_body(const DtIntUtilsFunction& function)
{
    const std::size_t scan_size = std::min<std::size_t>(function.size, 0xa20);
    const unsigned char* bytes = function.start;

    static constexpr unsigned char kBackendDataLoad[] = {
        0x48, 0x8b, 0xb3, 0xa0, 0x00, 0x00, 0x00,
    };
    static constexpr unsigned char kMessageLimitCheck[] = {
        0x81, 0xfa, 0x00, 0x02, 0x00, 0x00,
    };
    static constexpr unsigned char kKeyboardCodePageLoad[] = {
        0x8b, 0x4e, 0x2c,
    };
    static constexpr unsigned char kMbcToWideCharSetup[] = {
        0x44, 0x8b, 0xc8, 0x8b, 0xd0, 0x66, 0x89, 0x7d, 0x7f,
    };
    static constexpr unsigned char kInputEventsQueueLoadBody[] = {
        0x48, 0x8b, 0x8b, 0xe0, 0x00, 0x00, 0x00,
    };

    return contains_bytes(bytes, scan_size, kBackendDataLoad, sizeof(kBackendDataLoad)) &&
        contains_bytes(bytes, scan_size, kMessageLimitCheck, sizeof(kMessageLimitCheck)) &&
        contains_bytes(bytes, scan_size, kKeyboardCodePageLoad, sizeof(kKeyboardCodePageLoad)) &&
        contains_bytes(bytes, scan_size, kMbcToWideCharSetup, sizeof(kMbcToWideCharSetup)) &&
        contains_bytes(bytes, scan_size, kInputEventsQueueLoadBody, sizeof(kInputEventsQueueLoadBody));
}

bool find_win32_message_handler_symbol(
    const DtIntUtilsModule& image,
    std::uintptr_t* win32_message_handler)
{
    static constexpr PatternByte kWin32MessageHandlerPattern[] = {
        {0x48, false}, {0x8b, false}, {0xc4, false}, {0x48, false}, {0x89, false},
        {0x58, false}, {0x08, false}, {0x48, false}, {0x89, false}, {0x70, false},
        {0x10, false}, {0x48, false}, {0x89, false}, {0x78, false}, {0x20, false},
        {0x4c, false}, {0x89, false}, {0x40, false}, {0x18, false}, {0x55, false},
        {0x41, false}, {0x54, false}, {0x41, false}, {0x55, false}, {0x41, false},
        {0x56, false}, {0x41, false}, {0x57, false}, {0x48, false}, {0x8d, false},
        {0x68, false}, {0xa9, false}, {0x48, false}, {0x81, false}, {0xec, false},
        {0xa0, false}, {0x00, false}, {0x00, false}, {0x00, false},
    };

    const std::size_t pattern_size = sizeof(kWin32MessageHandlerPattern) / sizeof(kWin32MessageHandlerPattern[0]);
    return find_validated_pattern_symbol(
        image,
        "Dear ImGui Win32 message handler",
        kWin32MessageHandlerPattern,
        pattern_size,
        &win32_message_handler_candidate_has_expected_body,
        win32_message_handler);
}

bool resolve_imgui_symbols_uncached(ResolvedImguiSymbols* symbols)
{
    if (symbols == nullptr) {
        set_last_error("invalid ImGui symbol output");
        return false;
    }

    DtIntUtilsModule image = {};
    char utility_error[512] = {};
    if (!dtintutils_module_init_current(&image, utility_error, sizeof(utility_error))) {
        set_last_error(utility_error);
        return false;
    }

    const auto module_base = reinterpret_cast<std::uintptr_t>(image.base);
    const ImageSection text_section = *image.text;
    const DtIntUtilsLocatorStep create_context_reference_steps[] = {
        DTINTUTILS_LOCATE_STRING_PREFIX(".rdata", kDearImguiPrefix, 1, 1),
        DTINTUTILS_LOCATE_POINTER_SLOTS(1, 1),
        DTINTUTILS_LOCATE_RIP_REFERENCES(DTINTUTILS_MNEMONIC_ANY, ".text", 1, 1),
    };
    DtIntUtilsLocator create_context_reference_locator = {
        "Dear ImGui CreateContext reference",
        create_context_reference_steps,
        sizeof(create_context_reference_steps) / sizeof(create_context_reference_steps[0]),
    };
    const unsigned char* create_context_reference = nullptr;
    if (!dtintutils_locate_unique_address(
            &image,
            &create_context_reference_locator,
            &create_context_reference,
            utility_error,
            sizeof(utility_error))) {
        set_last_error(utility_error);
        return false;
    }

    DtIntUtilsInstruction reference_instruction = {};
    const auto text_end_address = reinterpret_cast<std::uintptr_t>(text_section.start) + text_section.size;
    const auto reference_address = reinterpret_cast<std::uintptr_t>(create_context_reference);
    if (!dtintutils_decode(
            create_context_reference,
            text_end_address - reference_address,
            &reference_instruction)) {
        set_last_error("failed to decode Dear ImGui CreateContext version reference");
        return false;
    }

    std::uintptr_t version_pointer_slot = 0;
    std::size_t slot_operand_count = 0;
    for (std::size_t index = 0; index < reference_instruction.operand_count; ++index) {
        const DtIntUtilsOperand& operand = reference_instruction.operands[index];
        if (operand.type == DTINTUTILS_OPERAND_MEMORY &&
            operand.memory_base == DTINTUTILS_REGISTER_RIP && operand.has_absolute) {
            version_pointer_slot = static_cast<std::uintptr_t>(operand.absolute);
            ++slot_operand_count;
        }
    }
    const ImageSection* version_slot_section = dtintutils_section_for_address(
        &image, reinterpret_cast<const void*>(version_pointer_slot));
    if (slot_operand_count != 1 || version_slot_section == nullptr ||
        (std::strcmp(version_slot_section->name, ".rdata") != 0 &&
         std::strcmp(version_slot_section->name, ".data") != 0) ||
        (version_slot_section->characteristics & IMAGE_SCN_MEM_READ) == 0 ||
        (version_slot_section->characteristics & IMAGE_SCN_MEM_EXECUTE) != 0) {
        set_last_error("Dear ImGui CreateContext reference did not resolve one readable version pointer slot");
        return false;
    }

    std::uintptr_t version_string = 0;
    char version_text[64] = {};
    const ImageSection* rdata_section = dtintutils_section(&image, ".rdata");
    if (!read_value(version_pointer_slot, &version_string) || rdata_section == nullptr ||
        !address_in_section(*rdata_section, version_string) ||
        !read_c_string(version_string, version_text, sizeof(version_text)) ||
        std::strncmp(version_text, kDearImguiPrefix, sizeof(kDearImguiPrefix) - 1) != 0) {
        set_last_error("Dear ImGui version pointer slot did not resolve the expected version string");
        return false;
    }

    DtIntUtilsFunction create_context_function = {};
    if (!dtintutils_function_containing(&image, create_context_reference, &create_context_function)) {
        set_last_error("failed to find Dear ImGui CreateContext function start");
        return false;
    }
    const std::uintptr_t create_context = reinterpret_cast<std::uintptr_t>(create_context_function.start);
    const std::uintptr_t version_pointer_reference = reinterpret_cast<std::uintptr_t>(create_context_reference);

    const std::uintptr_t g_scan_start = create_context;
    std::uintptr_t g_scan_end = version_pointer_reference + 0x100;
    const std::uintptr_t text_end = reinterpret_cast<std::uintptr_t>(text_section.start) + text_section.size;
    if (g_scan_end > text_end) {
        g_scan_end = text_end;
    }

    std::uintptr_t g_imgui_storage = 0;
    if (!find_repeated_writable_rip_target(image, text_section, g_scan_start, g_scan_end, &g_imgui_storage)) {
        return false;
    }

    std::uintptr_t platform_get_clipboard_text_offset = 0;
    std::uintptr_t platform_set_clipboard_text_offset = 0;
    if (!find_platform_clipboard_offsets(
            text_section,
            version_pointer_reference,
            &platform_get_clipboard_text_offset,
            &platform_set_clipboard_text_offset)) {
        return false;
    }

    std::uintptr_t add_font = 0;
    if (!find_add_font_symbol(image, &add_font)) {
        return false;
    }

    std::uintptr_t build_atlas = 0;
    if (!find_build_atlas_symbol(image, &build_atlas)) {
        return false;
    }

    std::uintptr_t calc_text_size = 0;
    if (!find_calc_text_size_symbol(image, &calc_text_size)) {
        return false;
    }

    std::uintptr_t render_text = 0;
    if (!find_render_text_symbol(image, &render_text)) {
        return false;
    }

    std::uintptr_t add_input_character = 0;
    if (!find_add_input_character_symbol(image, &add_input_character)) {
        return false;
    }

    std::uintptr_t win32_message_handler = 0;
    if (!find_win32_message_handler_symbol(image, &win32_message_handler)) {
        return false;
    }

    symbols->module_base = module_base;
    symbols->version_string = version_string;
    symbols->version_pointer_slot = version_pointer_slot;
    symbols->create_context = create_context;
    symbols->g_imgui_storage = g_imgui_storage;
    symbols->add_font = add_font;
    symbols->build_atlas = build_atlas;
    symbols->calc_text_size = calc_text_size;
    symbols->render_text = render_text;
    symbols->add_input_character = add_input_character;
    symbols->win32_message_handler = win32_message_handler;
    symbols->platform_get_clipboard_text_offset = platform_get_clipboard_text_offset;
    symbols->platform_set_clipboard_text_offset = platform_set_clipboard_text_offset;
    return true;
}
}

bool resolve_imgui_symbols(ResolvedImguiSymbols* symbols)
{
    std::lock_guard<std::mutex> guard(g_symbol_mutex);

    if (!g_symbols_resolved) {
        ResolvedImguiSymbols resolved = {};
        if (!resolve_imgui_symbols_uncached(&resolved)) {
            return false;
        }

        g_symbols = resolved;
        g_symbols_resolved = true;
    }

    if (symbols != nullptr) {
        *symbols = g_symbols;
    }

    return true;
}
}
