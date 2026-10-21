#include "realms_internal.h"

#include <algorithm>
#include <array>
#include <charconv>
#include <cstdio>
#include <cstring>
#include <initializer_list>
#include <iterator>

namespace realms {

bool write_error(char *buffer, int capacity, const char *message) {
    if (buffer != nullptr && capacity > 0) {
        std::snprintf(buffer, static_cast<size_t>(capacity), "%s", message);
    }

    return false;
}

bool write_formatted_error(char *buffer, int capacity, const char *format, unsigned long value) {
    if (buffer != nullptr && capacity > 0) {
        std::snprintf(buffer, static_cast<size_t>(capacity), format, value);
    }

    return false;
}

bool decode_absolute_target(const uint8_t *address, DtIntUtilsMnemonic mnemonic, const uint8_t **target, char *error,
                            int error_capacity) {
    DtIntUtilsInstruction instruction{};

    if (!dtintutils_decode(address, 15, &instruction) || instruction.mnemonic != mnemonic) {
        return write_error(error, error_capacity, "Darktide instruction did not match the expected operation");
    }

    const uint8_t *resolved = nullptr;
    size_t resolved_count = 0;

    for (size_t index = 0; index < instruction.operand_count; ++index) {
        const DtIntUtilsOperand &operand = instruction.operands[index];

        if (operand.has_absolute) {
            resolved = reinterpret_cast<const uint8_t *>(operand.absolute);
            ++resolved_count;
        }
    }

    if (resolved_count != 1) {
        return write_error(error, error_capacity, "Darktide instruction did not have one absolute target");
    }

    *target = resolved;
    return true;
}

namespace {

constexpr size_t kMaximumSemanticFunctionSize = 0x4000;

bool semantic_error(const char *description, char *error, int error_capacity) {
    if (error != nullptr && error_capacity > 0) {
        std::snprintf(error, static_cast<size_t>(error_capacity), "%s semantic contract did not match", description);
    }
    return false;
}

bool resolve_function_entry(const void *target, size_t maximum_size, DtIntUtilsFunction *function) {
    return target != nullptr && dtintutils_is_executable_address(&g_module, target) &&
           dtintutils_function_containing(&g_module, target, function) && function->start == target &&
           function->size != 0 && function->size <= maximum_size;
}

bool function_has_field_offset(const DtIntUtilsFunction &function, int64_t field_offset) {
    size_t offset = 0;
    while (offset < function.size) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction) ||
            instruction.length == 0) {
            ++offset;
            continue;
        }

        for (size_t index = 0; index < instruction.operand_count; ++index) {
            const DtIntUtilsOperand &operand = instruction.operands[index];

            if (operand.type == DTINTUTILS_OPERAND_MEMORY && operand.displacement == field_offset) {
                return true;
            }
        }

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_ADD && instruction.operand_count >= 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            static_cast<int64_t>(instruction.operands[1].immediate) == field_offset) {
            return true;
        }

        offset += instruction.length;
    }
    return false;
}

size_t count_field_offsets(const DtIntUtilsFunction &function, std::initializer_list<int64_t> offsets) {
    size_t count = 0;
    for (const int64_t offset : offsets) {
        count += function_has_field_offset(function, offset) ? 1u : 0u;
    }
    return count;
}

bool function_has_numeric_value(const DtIntUtilsFunction &function, int64_t value) {
    size_t offset = 0;
    while (offset < function.size) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction) ||
            instruction.length == 0) {
            ++offset;
            continue;
        }
        for (size_t index = 0; index < instruction.operand_count; ++index) {
            const DtIntUtilsOperand &operand = instruction.operands[index];
            if ((operand.type == DTINTUTILS_OPERAND_MEMORY && operand.displacement == value) ||
                (operand.type == DTINTUTILS_OPERAND_IMMEDIATE && !operand.immediate_is_relative &&
                 static_cast<int64_t>(operand.immediate) == value)) {
                return true;
            }
        }
        offset += instruction.length;
    }
    return false;
}

size_t count_direct_calls(const DtIntUtilsFunction &function, const uint8_t *target = nullptr) {
    size_t count = 0;
    size_t offset = 0;
    while (offset < function.size) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction) ||
            instruction.length == 0) {
            ++offset;
            continue;
        }
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count >= 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            instruction.operands[0].has_absolute &&
            (target == nullptr || instruction.operands[0].absolute == reinterpret_cast<uintptr_t>(target))) {
            ++count;
        }
        offset += instruction.length;
    }
    return count;
}

size_t count_indirect_calls_with_displacement(const DtIntUtilsFunction &function, int64_t displacement) {
    size_t count = 0;
    size_t offset = 0;
    while (offset < function.size) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction) ||
            instruction.length == 0) {
            ++offset;
            continue;
        }
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count >= 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_MEMORY &&
            instruction.operands[0].displacement == displacement) {
            ++count;
        }
        offset += instruction.length;
    }
    return count;
}

bool validate_read_bits_profile(const DtIntUtilsFunction &function) {
    return function.size <= 0x500 && count_field_offsets(function, {0x08, 0x10, 0x14, 0x18, 0x1c}) == 5 &&
           count_direct_calls(function) == 0;
}

bool validate_add_member_profile(const DtIntUtilsFunction &function) {
    return function.size <= 0x1000 && count_field_offsets(function, {0x70, 0x5a8, 0x5b0, 0x660}) == 4;
}

bool validate_destroy_member_profile(const DtIntUtilsFunction &function) {
    return function.size <= 0x300 && count_field_offsets(function, {0x38, 0x40, 0x50, 0x58}) == 4 &&
           count_indirect_calls_with_displacement(function, 0x98) >= 2;
}

bool validate_routed_listener_common_profile(const DtIntUtilsFunction &function) {
    return function.size <= 0x400 && function_has_field_offset(function, 0x3f2) &&
           function_has_numeric_value(function, 0x2d0) && function_has_numeric_value(function, 0x390) &&
           count_direct_calls(function) >= 1;
}

bool validate_send_address_profile(const DtIntUtilsFunction &function) {
    return function.size <= 0x300 && count_field_offsets(function, {0x60, 0x68, 0xa8}) == 3 &&
           count_direct_calls(function) >= 1;
}

bool locate_destroy_after_add(const DtIntUtilsFunction &caller, const uint8_t *add_call,
                              DestroyLobbyMemberFunction *destroy_member, char *error, int error_capacity) {
    DtIntUtilsInstruction add_instruction{};
    if (!dtintutils_decode(add_call, static_cast<size_t>(caller.start + caller.size - add_call), &add_instruction)) {
        return write_error(error, error_capacity, "Could not decode the add-member call site");
    }

    const uint8_t *cursor = add_call + add_instruction.length;
    const uint8_t *scan_end = std::min<const uint8_t *>(caller.start + caller.size, cursor + 96);
    std::array<const uint8_t *, 8> candidates{};
    size_t candidate_count = 0;
    while (cursor < scan_end) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(cursor, static_cast<size_t>(scan_end - cursor), &instruction) ||
            instruction.length == 0) {
            ++cursor;
            continue;
        }
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count >= 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            instruction.operands[0].has_absolute) {
            const auto *target = reinterpret_cast<const uint8_t *>(instruction.operands[0].absolute);
            DtIntUtilsFunction function{};
            if (resolve_function_entry(target, 0x300, &function) && validate_destroy_member_profile(function)) {
                bool duplicate = false;
                for (size_t index = 0; index < candidate_count; ++index) {
                    duplicate = duplicate || candidates[index] == target;
                }
                if (!duplicate) {
                    if (candidate_count == candidates.size()) {
                        return write_error(error, error_capacity,
                                           "Too many destructor candidates followed the add-member call");
                    }
                    candidates[candidate_count++] = target;
                }
            }
        }
        cursor += instruction.length;
    }

    if (candidate_count != 1) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected one lobby-member destructor after add-member, found %zu", candidate_count);
        }
        return false;
    }

    *destroy_member = reinterpret_cast<DestroyLobbyMemberFunction>(const_cast<uint8_t *>(candidates[0]));
    return true;
}

bool locate_destroy_from_add_contexts(const uint8_t *add_member, DestroyLobbyMemberFunction *destroy_member,
                                      char *error, int error_capacity) {
    if (g_module.text == nullptr) {
        return write_error(error, error_capacity, "Darktide executable text section is unavailable");
    }

    constexpr size_t kMaximumDirectCallSites = 16;
    DestroyLobbyMemberFunction resolved_destroy = nullptr;
    size_t direct_call_count = 0;
    size_t semantic_context_count = 0;
    size_t offset = 0;

    while (offset < g_module.text->size) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(g_module.text->start + offset, g_module.text->size - offset, &instruction) ||
            instruction.length == 0) {
            ++offset;
            continue;
        }

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count >= 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE && instruction.operands[0].has_absolute &&
            instruction.operands[0].absolute == reinterpret_cast<uintptr_t>(add_member)) {
            ++direct_call_count;

            if (direct_call_count > kMaximumDirectCallSites) {
                return write_error(error, error_capacity,
                                   "Darktide add-lobby-member direct-call set exceeded its bound");
            }

            DtIntUtilsFunction caller{};
            DestroyLobbyMemberFunction candidate_destroy = nullptr;

            if (dtintutils_function_containing(&g_module, instruction.address, &caller) &&
                locate_destroy_after_add(caller, instruction.address, &candidate_destroy, nullptr, 0)) {
                resolved_destroy = candidate_destroy;
                ++semantic_context_count;
            }
        }

        offset += instruction.length;
    }

    if (semantic_context_count != 1) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected one add/destroy lobby-member context, found %zu from %zu direct calls",
                          semantic_context_count, direct_call_count);
        }
        return false;
    }

    *destroy_member = resolved_destroy;
    return true;
}

} // namespace

bool validate_engine_function(const void *target, EngineFunctionRole role, const char *description, char *error,
                              int error_capacity) {
    DtIntUtilsFunction function{};
    if (!resolve_function_entry(target, kMaximumSemanticFunctionSize, &function)) {
        return semantic_error(description, error, error_capacity);
    }

    bool valid = false;
    switch (role) {
        case EngineFunctionRole::RegisterSystemListener:
            valid = function.size <= 0x400 && function_has_field_offset(function, 0x3f0) &&
                    function_has_numeric_value(function, 0x240) && function_has_numeric_value(function, 0x300) &&
                    count_direct_calls(function) >= 1;
            break;
        case EngineFunctionRole::RemoveListener:
            valid = function.size <= 0x1000 && function_has_field_offset(function, 0x3f0) &&
                    count_field_offsets(function, {0x248, 0x278, 0x2a8, 0x2d8}) >= 3;
            break;
        case EngineFunctionRole::IsPeerConnected:
            valid = function.size <= 0x800 && count_field_offsets(function, {0xd0, 0x100}) == 2 &&
                    count_direct_calls(function) >= 1;
            break;
        case EngineFunctionRole::AcceptChannel:
            valid = function.size <= 0x1000 && count_indirect_calls_with_displacement(function, 0x80) >= 1 &&
                    count_direct_calls(function) >= 1;
            break;
        case EngineFunctionRole::SendChannel:
            valid = function.size <= 0x1000 && function_has_field_offset(function, 0x1c0) &&
                    count_direct_calls(function) >= 1;
            break;
    }

    return valid || semantic_error(description, error, error_capacity);
}

bool validate_routed_listener_methods(const void *register_channel, const void *register_peer, char *error,
                                      int error_capacity) {
    DtIntUtilsFunction channel_function{};
    DtIntUtilsFunction peer_function{};
    if (!resolve_function_entry(register_channel, 0x200, &channel_function) ||
        !resolve_function_entry(register_peer, 0x200, &peer_function)) {
        return semantic_error("Darktide routed-listener wrappers", error, error_capacity);
    }

    std::array<const uint8_t *, 2> channel_targets{};
    std::array<const uint8_t *, 2> peer_targets{};
    const size_t channel_count = dtintutils_collect_direct_call_targets(&g_module, &channel_function,
                                                                        channel_targets.data(), channel_targets.size());
    const size_t peer_count = dtintutils_collect_direct_call_targets(&g_module, &peer_function, peer_targets.data(),
                                                                     peer_targets.size());
    DtIntUtilsFunction common_function{};
    if (channel_count != 1 || peer_count != 1 || channel_targets[0] != peer_targets[0] ||
        !resolve_function_entry(channel_targets[0], 0x400, &common_function) ||
        !validate_routed_listener_common_profile(common_function)) {
        return semantic_error("Darktide routed-listener wrappers", error, error_capacity);
    }
    return true;
}

bool validate_send_address_method(const void *target, char *error, int error_capacity) {
    DtIntUtilsFunction implementation{};
    if (resolve_function_entry(target, 0x300, &implementation) && validate_send_address_profile(implementation)) {
        return true;
    }

    const uint8_t *resolved = nullptr;
    if (target == nullptr || !dtintutils_is_executable_address(&g_module, target) ||
        !dtintutils_is_readable_range(target, 15) ||
        !decode_absolute_target(static_cast<const uint8_t *>(target), DTINTUTILS_MNEMONIC_OTHER, &resolved, error,
                                error_capacity) ||
        !resolve_function_entry(resolved, 0x300, &implementation) || !validate_send_address_profile(implementation)) {
        return semantic_error("Darktide WAN explicit-address send", error, error_capacity);
    }
    return true;
}

bool locate_lobby_member_helpers(AddLobbyMemberFunction *add_member, DestroyLobbyMemberFunction *destroy_member,
                                 char *error, int error_capacity) {
    DtIntUtilsFunction add_function{};
    if (!dtintutils_find_unique_function_by_exact_string(
            &g_module, "Failed to get address to %llx so the member cannot be added", &add_function, error,
            error_capacity > 0 ? static_cast<size_t>(error_capacity) : 0)) {
        return false;
    }
    if (!validate_add_member_profile(add_function)) {
        semantic_error("Darktide add-lobby-member", error, error_capacity);
        return false;
    }

    if (!locate_destroy_from_add_contexts(add_function.start, destroy_member, error, error_capacity)) {
        return false;
    }
    *add_member = reinterpret_cast<AddLobbyMemberFunction>(add_function.start);
    return true;
}

bool locate_read_bits(ReadBitsFunction *read_bits, char *error, int error_capacity) {
    const char *anchors[] = {
        "Broken packet from %llx detected when parsing channel id",
        "Channel id not invalid in connection-less packet from %llx",
        "Broken packet from %llx detected when parsing chunk size",
    };
    DtIntUtilsFunction anchor_functions[std::size(anchors)]{};
    if (!dtintutils_find_unique_functions_by_exact_strings(
            &g_module, anchors, anchor_functions, std::size(anchors), error,
            error_capacity > 0 ? static_cast<size_t>(error_capacity) : 0)) {
        return false;
    }
    for (size_t index = 1; index < std::size(anchor_functions); ++index) {
        if (anchor_functions[index].start != anchor_functions[0].start) {
            return write_error(error, error_capacity,
                               "Darktide connectionless error anchors resolved to different functions");
        }
    }

    const DtIntUtilsFunction &dispatcher = anchor_functions[0];
    std::array<const uint8_t *, 64> targets{};
    std::array<size_t, 64> frequencies{};
    size_t target_count = 0;
    size_t offset = 0;
    while (offset < dispatcher.size) {
        DtIntUtilsInstruction instruction{};
        if (!dtintutils_decode(dispatcher.start + offset, dispatcher.size - offset, &instruction) ||
            instruction.length == 0) {
            ++offset;
            continue;
        }
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count >= 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            instruction.operands[0].has_absolute) {
            const auto *target = reinterpret_cast<const uint8_t *>(instruction.operands[0].absolute);
            size_t index = 0;
            while (index < target_count && targets[index] != target) {
                ++index;
            }
            if (index == target_count) {
                if (target_count == targets.size()) {
                    return write_error(error, error_capacity,
                                       "Darktide connectionless dispatcher had too many direct call targets");
                }
                targets[target_count++] = target;
            }
            ++frequencies[index];
        }
        offset += instruction.length;
    }

    const uint8_t *candidate = nullptr;
    size_t candidate_count = 0;
    for (size_t index = 0; index < target_count; ++index) {
        DtIntUtilsFunction function{};
        if (frequencies[index] >= 3 && resolve_function_entry(targets[index], 0x500, &function) &&
            validate_read_bits_profile(function)) {
            candidate = targets[index];
            ++candidate_count;
        }
    }
    if (candidate_count != 1) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected one BitReader target in the connectionless dispatcher, found %zu",
                          candidate_count);
        }
        return false;
    }

    *read_bits = reinterpret_cast<ReadBitsFunction>(const_cast<uint8_t *>(candidate));
    return true;
}

bool locate_registered_wrappers(const char *binding_name, const uint8_t **wrappers, size_t wrapper_capacity,
                                size_t *wrapper_count, char *error, int error_capacity) {
    const uint8_t *binding_reference = nullptr;
    const DtIntUtilsLocatorStep binding_steps[] = {
        DTINTUTILS_LOCATE_EXACT_STRING(binding_name, 1, 1),
        DTINTUTILS_LOCATE_RIP_REFERENCES(DTINTUTILS_MNEMONIC_LEA, ".text", 1, 1),
    };
    const DtIntUtilsLocator binding_locator{
        "Realms registered network binding",
        binding_steps,
        std::size(binding_steps),
    };

    if (!dtintutils_locate_unique_address(&g_module, &binding_locator, &binding_reference, error,
                                          error_capacity > 0 ? static_cast<size_t>(error_capacity) : 0)) {
        return false;
    }

    DtIntUtilsFunction registration_function{};

    if (!dtintutils_function_containing(&g_module, binding_reference, &registration_function)) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity), "Could not resolve the %s registration function",
                          binding_name);
        }

        return false;
    }

    const uint8_t *cursor = binding_reference;
    const uint8_t *function_end = registration_function.start + registration_function.size;
    const size_t scan_size = std::min<size_t>(96, static_cast<size_t>(function_end - binding_reference));
    const uint8_t *scan_end = binding_reference + scan_size;
    std::array<const uint8_t *, 8> candidates{};
    size_t candidate_count = 0;

    while (cursor < scan_end) {
        DtIntUtilsInstruction instruction{};

        if (!dtintutils_decode(cursor, static_cast<size_t>(function_end - cursor), &instruction) ||
            instruction.length == 0) {
            if (error != nullptr && error_capacity > 0) {
                std::snprintf(error, static_cast<size_t>(error_capacity),
                              "Failed to decode the %s registration sequence", binding_name);
            }

            return false;
        }

        if (cursor > binding_reference && instruction.mnemonic == DTINTUTILS_MNEMONIC_LEA) {
            for (size_t i = 0; i < instruction.operand_count; ++i) {
                const DtIntUtilsOperand &operand = instruction.operands[i];

                if (operand.has_absolute &&
                    dtintutils_is_executable_address(&g_module, reinterpret_cast<const void *>(operand.absolute))) {
                    const auto *resolved = reinterpret_cast<const uint8_t *>(operand.absolute);
                    bool duplicate = false;
                    for (size_t candidate_index = 0; candidate_index < candidate_count; ++candidate_index) {
                        duplicate = duplicate || candidates[candidate_index] == resolved;
                    }
                    if (!duplicate) {
                        if (candidate_count == candidates.size()) {
                            return write_error(error, error_capacity,
                                               "Binding registration exposed too many wrapper candidates");
                        }
                        candidates[candidate_count] = resolved;
                        ++candidate_count;
                    }
                }
            }
        }

        cursor += instruction.length;
    }

    size_t resolved_count = 0;

    for (size_t index = 0; index < candidate_count; ++index) {
        DtIntUtilsFunction function{};

        if (!resolve_function_entry(candidates[index], kMaximumSemanticFunctionSize, &function)) {
            continue;
        }
        if (resolved_count == wrapper_capacity) {
            return write_error(error, error_capacity, "Binding registration exposed too many function entries");
        }

        wrappers[resolved_count] = candidates[index];
        ++resolved_count;
    }

    if (resolved_count == 0) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected at least one %s wrapper function, found %zu executable candidates",
                          binding_name, candidate_count);
        }

        return false;
    }

    *wrapper_count = resolved_count;
    return true;
}

namespace {

size_t collect_manager_slot_candidates(const DtIntUtilsFunction &function, int64_t expected_field,
                                       const uint8_t **results, size_t result_capacity) {
    size_t result_count = 0;
    size_t offset = 0;
    while (offset < function.size) {
        DtIntUtilsInstruction load{};
        if (!dtintutils_decode(function.start + offset, function.size - offset, &load) || load.length == 0) {
            ++offset;
            continue;
        }

        const DtIntUtilsOperand *destination = load.operand_count >= 1 ? &load.operands[0] : nullptr;
        const DtIntUtilsOperand *source = load.operand_count >= 2 ? &load.operands[1] : nullptr;
        if (load.mnemonic == DTINTUTILS_MNEMONIC_MOV && destination != nullptr && source != nullptr &&
            destination->type == DTINTUTILS_OPERAND_REGISTER && source->type == DTINTUTILS_OPERAND_MEMORY &&
            source->memory_base == DTINTUTILS_REGISTER_RIP && source->has_absolute &&
            dtintutils_is_writable_address(&g_module, reinterpret_cast<const void *>(source->absolute))) {
            const int loaded_register = destination->register_id;
            const uint8_t *cursor = load.address + load.length;
            const uint8_t *end = std::min<const uint8_t *>(function.start + function.size, cursor + 48);
            size_t instructions_left = 6;
            bool field_used = false;
            while (cursor < end && instructions_left-- != 0) {
                DtIntUtilsInstruction use{};
                if (!dtintutils_decode(cursor, static_cast<size_t>(end - cursor), &use) || use.length == 0) {
                    break;
                }
                for (size_t index = 0; index < use.operand_count; ++index) {
                    const DtIntUtilsOperand &operand = use.operands[index];
                    if (operand.type == DTINTUTILS_OPERAND_MEMORY && operand.memory_base == loaded_register &&
                        operand.displacement == expected_field) {
                        field_used = true;
                    }
                }
                if (field_used || dtintutils_instruction_writes_register(&use, loaded_register)) {
                    break;
                }
                cursor += use.length;
            }

            if (field_used) {
                const auto *slot = reinterpret_cast<const uint8_t *>(source->absolute);
                bool duplicate = false;
                for (size_t index = 0; index < result_count; ++index) {
                    duplicate = duplicate || results[index] == slot;
                }
                if (!duplicate) {
                    if (result_count >= result_capacity) {
                        return result_capacity + 1;
                    }
                    results[result_count] = slot;
                    ++result_count;
                }
            }
        }
        offset += load.length;
    }
    return result_count;
}

} // namespace

bool locate_network_manager_slot(char *error, int error_capacity) {
    char utility_error[512]{};

    if (!dtintutils_module_init_current(&g_module, utility_error, sizeof(utility_error))) {
        return write_error(error, error_capacity, utility_error);
    }

    std::array<const uint8_t *, 8> join_wrappers{};
    size_t join_wrapper_count = 0;

    if (!locate_registered_wrappers("join_lan_lobby", join_wrappers.data(), join_wrappers.size(),
                                    &join_wrapper_count, error, error_capacity)) {
        return false;
    }

    std::array<const uint8_t *, 8> leave_wrappers{};
    size_t leave_wrapper_count = 0;

    if (!locate_registered_wrappers("leave_lan_lobby", leave_wrappers.data(), leave_wrappers.size(),
                                    &leave_wrapper_count, error, error_capacity)) {
        return false;
    }

    std::array<const uint8_t *, 32> join_slots{};
    std::array<const uint8_t *, 32> leave_slots{};
    size_t join_count = 0;
    size_t leave_count = 0;

    const auto collect_slots = [&](const std::array<const uint8_t *, 8> &wrappers, size_t wrapper_count,
                                   int64_t expected_field, std::array<const uint8_t *, 32> &slots,
                                   size_t *slot_count) {
        for (size_t wrapper_index = 0; wrapper_index < wrapper_count; ++wrapper_index) {
            DtIntUtilsFunction function{};
            if (!resolve_function_entry(wrappers[wrapper_index], kMaximumSemanticFunctionSize, &function)) {
                continue;
            }

            std::array<const uint8_t *, 8> candidates{};
            const size_t candidate_count = collect_manager_slot_candidates(
                function, expected_field, candidates.data(), candidates.size());
            if (candidate_count > candidates.size()) {
                return false;
            }

            for (size_t candidate_index = 0; candidate_index < candidate_count; ++candidate_index) {
                const uint8_t *candidate = candidates[candidate_index];
                bool duplicate = false;
                for (size_t slot_index = 0; slot_index < *slot_count; ++slot_index) {
                    duplicate = duplicate || slots[slot_index] == candidate;
                }
                if (!duplicate) {
                    if (*slot_count == slots.size()) {
                        return false;
                    }
                    slots[*slot_count] = candidate;
                    ++*slot_count;
                }
            }
        }

        return true;
    };

    if (!collect_slots(join_wrappers, join_wrapper_count, kConnectionOffset, join_slots, &join_count) ||
        !collect_slots(leave_wrappers, leave_wrapper_count, kNetworkManagerLanClientOffset, leave_slots,
                       &leave_count)) {
        return write_error(error, error_capacity, "Network binding wrappers exposed too many manager-slot candidates");
    }

    const uint8_t *manager_slot = nullptr;
    size_t shared_count = 0;
    for (size_t join_index = 0; join_index < join_count; ++join_index) {
        for (size_t leave_index = 0; leave_index < leave_count; ++leave_index) {
            if (join_slots[join_index] == leave_slots[leave_index]) {
                manager_slot = join_slots[join_index];
                ++shared_count;
            }
        }
    }
    if (shared_count != 1 || !dtintutils_is_readable_range(manager_slot, sizeof(void *))) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity),
                          "Expected one shared network-manager slot from LAN bindings, found %zu "
                          "(join wrappers=%zu slots=%zu, leave wrappers=%zu slots=%zu)",
                          shared_count, join_wrapper_count, join_count, leave_wrapper_count, leave_count);
        }
        return false;
    }

    g_network_manager_slot = manager_slot;
    return true;
}

bool ensure_initialized(char *error, int error_capacity) {
    if (g_initialized) {
        return true;
    }

    if (!locate_network_manager_slot(error, error_capacity)) {
        return false;
    }

    g_initialized = true;
    return true;
}

bool read_pointer(const uint8_t *location, void **value, const char *description, char *error, int error_capacity) {
    if (!dtintutils_is_readable_range(location, sizeof(void *))) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity), "%s location is unreadable", description);
        }

        return false;
    }

    std::memcpy(value, location, sizeof(void *));

    if (*value == nullptr) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity), "%s is not initialized", description);
        }

        return false;
    }

    return true;
}

bool current_network_manager(void **manager, char *error, int error_capacity) {
    if (!ensure_initialized(error, error_capacity)) {
        return false;
    }

    return read_pointer(g_network_manager_slot, manager, "Darktide network manager", error, error_capacity);
}

bool current_connection(void **connection, IsPeerConnectedFunction *is_peer_connected,
                        RegisterSystemListenerFunction *register_system_listener,
                        RemoveListenerFunction *remove_listener, char *error, int error_capacity) {
    void *manager = nullptr;

    if (!current_network_manager(&manager, error, error_capacity)) {
        return false;
    }

    if (!read_pointer(static_cast<const uint8_t *>(manager) + kConnectionOffset, connection, "Darktide Connection",
                      error, error_capacity)) {
        return false;
    }

    void *vtable_pointer = nullptr;

    if (!read_pointer(static_cast<const uint8_t *>(*connection), &vtable_pointer, "Darktide Connection vtable", error,
                      error_capacity)) {
        return false;
    }

    const auto *vtable = static_cast<const uint8_t *>(vtable_pointer);
    const DtIntUtilsSection *vtable_section = dtintutils_section_for_address(&g_module, vtable);

    if (vtable_section == nullptr || (vtable_section->characteristics & IMAGE_SCN_MEM_READ) == 0 ||
        (vtable_section->characteristics & IMAGE_SCN_MEM_WRITE) != 0 ||
        !dtintutils_is_readable_range(vtable, kIsPeerConnectedSlot + sizeof(void *))) {
        return write_error(error, error_capacity, "Darktide Connection vtable failed section validation");
    }

    void *is_connected_target = nullptr;
    void *register_listener_target = nullptr;
    void *remove_listener_target = nullptr;
    std::memcpy(&is_connected_target, vtable + kIsPeerConnectedSlot, sizeof(void *));
    std::memcpy(&register_listener_target, vtable + kRegisterSystemListenerSlot, sizeof(void *));
    std::memcpy(&remove_listener_target, vtable + kRemoveListenerSlot, sizeof(void *));

    if (!validate_engine_function(register_listener_target, EngineFunctionRole::RegisterSystemListener,
                                  "Darktide register-system-listener", error, error_capacity) ||
        !validate_engine_function(remove_listener_target, EngineFunctionRole::RemoveListener,
                                  "Darktide remove-listener", error, error_capacity) ||
        !validate_engine_function(is_connected_target, EngineFunctionRole::IsPeerConnected,
                                  "Darktide is-peer-connected", error, error_capacity)) {
        return false;
    }

    if (is_peer_connected != nullptr) {
        *is_peer_connected = reinterpret_cast<IsPeerConnectedFunction>(is_connected_target);
    }
    if (register_system_listener != nullptr) {
        *register_system_listener = reinterpret_cast<RegisterSystemListenerFunction>(register_listener_target);
    }
    if (remove_listener != nullptr) {
        *remove_listener = reinterpret_cast<RemoveListenerFunction>(remove_listener_target);
    }
    return true;
}

bool parse_hex_id(const char *text, uint64_t *value, const char *description, char *error, int error_capacity) {
    if (text == nullptr || std::strlen(text) != 16) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity), "%s must contain exactly 16 hexadecimal digits",
                          description);
        }

        return false;
    }

    uint64_t parsed = 0;
    const auto result = std::from_chars(text, text + 16, parsed, 16);

    if (result.ec != std::errc{} || result.ptr != text + 16) {
        if (error != nullptr && error_capacity > 0) {
            std::snprintf(error, static_cast<size_t>(error_capacity), "%s could not be parsed", description);
        }

        return false;
    }

    *value = parsed;
    return true;
}

bool resolve_binary_connection(BinaryConnectionMethods *methods, char *error, int error_capacity) {
    if (!current_connection(&methods->connection, &methods->is_connected, nullptr, &methods->remove_listener,
                            error, error_capacity) ||
        !read_pointer(static_cast<const uint8_t *>(methods->connection), &methods->vtable,
                      "Binary Connection vtable", error, error_capacity)) {
        return false;
    }

    const auto *vtable = static_cast<const uint8_t *>(methods->vtable);
    void *register_channel = nullptr;
    void *register_peer = nullptr;
    void *send = nullptr;
    void *buffer_left = nullptr;
    constexpr size_t kReliableBufferLeftSlot = 0x198;
    if (!read_pointer(vtable + kRegisterChannelSystemListenerSlot, &register_channel, "Binary channel listener",
                      error, error_capacity) ||
        !read_pointer(vtable + kRegisterPeerSystemListenerSlot, &register_peer, "Binary peer listener", error,
                      error_capacity) ||
        !read_pointer(vtable + kSendChannelSlot, &send, "Binary channel send", error, error_capacity) ||
        !read_pointer(vtable + kReliableBufferLeftSlot, &buffer_left, "Reliable buffer query", error,
                      error_capacity) ||
        !validate_routed_listener_methods(register_channel, register_peer, error, error_capacity) ||
        !validate_engine_function(send, EngineFunctionRole::SendChannel, "Binary channel send", error,
                                  error_capacity) ||
        !locate_read_bits(&methods->read_bits, error, error_capacity)) {
        return false;
    }

    auto direct_target = [&](const void *caller, std::initializer_list<int64_t> values,
                             DtIntUtilsFunction *result) {
        DtIntUtilsFunction function{};
        if (!resolve_function_entry(caller, kMaximumSemanticFunctionSize, &function)) {
            return false;
        }
        std::array<const uint8_t *, 32> targets{};
        const size_t count = dtintutils_collect_direct_call_targets(&g_module, &function, targets.data(),
                                                                   targets.size());
        size_t matches = 0;
        for (size_t index = 0; index < count && index < targets.size(); ++index) {
            DtIntUtilsFunction candidate{};
            if (!resolve_function_entry(targets[index], kMaximumSemanticFunctionSize, &candidate)) {
                continue;
            }
            bool matched = true;
            for (int64_t value : values) {
                matched = matched && function_has_numeric_value(candidate, value);
            }
            if (matched) {
                *result = candidate;
                ++matches;
            }
        }
        return count < targets.size() && matches == 1;
    };

    DtIntUtilsFunction buffer_function{};
    DtIntUtilsFunction endpoint_function{};
    DtIntUtilsFunction endpoint_send{};
    DtIntUtilsFunction endpoint_flush{};
    DtIntUtilsFunction maximum_message{};
    if (!resolve_function_entry(buffer_left, 0x400, &buffer_function) ||
        count_field_offsets(buffer_function, {0x20a8, 0x20e0, 0x20d8, 0x20f8}) != 4) {
        return semantic_error("Darktide binary reliable-buffer query", error, error_capacity);
    }
    if (!direct_target(buffer_left, {0x78, 0x80, 0xa8, 0xb0}, &endpoint_function)) {
        return semantic_error("Darktide binary peer Endpoint lookup", error, error_capacity);
    }
    if (!direct_target(send, {0x2630, 0x2b10}, &endpoint_send)) {
        return semantic_error("Darktide binary Endpoint send", error, error_capacity);
    }
    if (!direct_target(endpoint_send.start, {0x20b0, 0x20d0, 0x2088, 0x20a0, 0x20a4, 0x20a8}, &endpoint_flush)) {
        return semantic_error("Darktide binary Endpoint queue flush", error, error_capacity);
    }
    if (!direct_target(endpoint_send.start, {0x206c}, &maximum_message) ||
        !function_has_numeric_value(maximum_message, 0x4b0)) {
        return semantic_error("Darktide binary Endpoint message limit", error, error_capacity);
    }

    methods->register_listener = reinterpret_cast<RegisterChannelSystemListenerFunction>(register_channel);
    methods->send = reinterpret_cast<SendChannelFunction>(send);
    methods->buffer_left = reinterpret_cast<ReliableBufferLeftFunction>(buffer_left);
    methods->peer_endpoint = reinterpret_cast<PeerEndpointFunction>(endpoint_function.start);
    methods->message_size = reinterpret_cast<EndpointMessageSizeFunction>(maximum_message.start);
    return true;
}

} // namespace realms
