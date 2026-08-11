#include "runtime_internal.h"

#include <string.h>

static int sa_is_register_move(
    const DtIntUtilsInstruction *instruction,
    int destination,
    const int *sources,
    size_t source_count
) {
    return instruction->mnemonic == DTINTUTILS_MNEMONIC_MOV && instruction->operand_count == 2 &&
        instruction->operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
        instruction->operands[0].register_id == destination &&
        instruction->operands[0].size_bits == 64 &&
        instruction->operands[1].type == DTINTUTILS_OPERAND_REGISTER &&
        instruction->operands[1].size_bits == 64 &&
        sa_register_in_set(instruction->operands[1].register_id, sources, source_count);
}

static int sa_is_stack_address(
    const DtIntUtilsInstruction *instruction,
    int destination
) {
    return instruction->mnemonic == DTINTUTILS_MNEMONIC_LEA && instruction->operand_count == 2 &&
        instruction->operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
        instruction->operands[0].register_id == destination &&
        instruction->operands[0].size_bits == 64 &&
        instruction->operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
        (instruction->operands[1].memory_base == 4 || instruction->operands[1].memory_base == 5) &&
        instruction->operands[1].memory_index == DTINTUTILS_REGISTER_NONE;
}

static int sa_validate_path_join_target(const SaImage *image, const uint8_t *target) {
    SaFunction function;
    const uint8_t *call_targets[32];
    size_t call_counts[32];
    size_t call_target_count = 0;
    size_t maximum_call_count = 0;
    size_t direct_call_count = 0;
    int saw_forward_slash = 0;
    int saw_backslash = 0;
    size_t offset = 0;

    memset(call_targets, 0, sizeof(call_targets));
    memset(call_counts, 0, sizeof(call_counts));
    if (!dtintutils_function_containing(image, target, &function) || function.start != target ||
        function.size < 96 || function.size > 1024) {
        return 0;
    }

    while (offset < function.size) {
        DtIntUtilsInstruction instruction;
        size_t advance = 1;
        size_t operand_index;

        if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction)) {
            ++offset;
            continue;
        }
        advance = instruction.length;
        for (operand_index = 0; operand_index < instruction.operand_count; ++operand_index) {
            const DtIntUtilsOperand *operand = &instruction.operands[operand_index];
            if (operand->type != DTINTUTILS_OPERAND_IMMEDIATE) {
                continue;
            }
            if (operand->immediate == 0x2f) {
                saw_forward_slash = 1;
            } else if (operand->immediate == 0x5c) {
                saw_backslash = 1;
            }
        }
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count == 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            instruction.operands[0].has_absolute) {
            const uint8_t *call_target =
                (const uint8_t *)(uintptr_t)instruction.operands[0].absolute;
            size_t index;

            if (!dtintutils_is_executable_address(image, call_target)) {
                return 0;
            }
            ++direct_call_count;
            for (index = 0; index < call_target_count; ++index) {
                if (call_targets[index] == call_target) {
                    break;
                }
            }
            if (index == call_target_count) {
                if (call_target_count == SA_ARRAY_COUNT(call_targets)) {
                    return 0;
                }
                call_targets[call_target_count] = call_target;
                ++call_target_count;
            }
            ++call_counts[index];
            if (call_counts[index] > maximum_call_count) {
                maximum_call_count = call_counts[index];
            }
        }
        offset += advance;
    }

    return saw_forward_slash && saw_backslash && direct_call_count >= 4 && maximum_call_count >= 2;
}

static int sa_has_following_direct_call(
    const SaImage *image,
    const uint8_t *start,
    const uint8_t *limit
) {
    const uint8_t *cursor = start;

    while (cursor < limit) {
        DtIntUtilsInstruction instruction;
        if (!dtintutils_decode(cursor, (size_t)(limit - cursor), &instruction)) {
            return 0;
        }
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count == 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            instruction.operands[0].has_absolute &&
            dtintutils_is_executable_address(
                image, (const void *)(uintptr_t)instruction.operands[0].absolute)) {
            return 1;
        }
        cursor += instruction.length;
    }
    return 0;
}

int sa_analyze_path_join_call(
    const SaImage *image,
    const SaFunction *function,
    const uint8_t **target,
    char *error,
    size_t error_size
) {
    int owner_registers[8];
    int path_registers[8];
    size_t owner_count = sa_collect_argument_registers(
        function, 1, owner_registers, SA_ARRAY_COUNT(owner_registers));
    size_t path_count = sa_collect_argument_registers(
        function, 8, path_registers, SA_ARRAY_COUNT(path_registers));
    const uint8_t *last_root_load = NULL;
    const uint8_t *last_output_address = NULL;
    const uint8_t *last_allocator_address = NULL;
    const uint8_t *last_path_move = NULL;
    const uint8_t *selected_target = NULL;
    size_t match_count = 0;
    size_t offset = 0;

    if (owner_count == 0 || owner_count > SA_ARRAY_COUNT(owner_registers) ||
        path_count == 0 || path_count > SA_ARRAY_COUNT(path_registers)) {
        sa_set_error(error, error_size,
                     "FileClient::open_input does not preserve its owner and path arguments uniquely");
        return 0;
    }

    while (offset < function->size) {
        const uint8_t *address = function->start + offset;
        const uint8_t *limit = function->start + function->size;
        DtIntUtilsInstruction instruction;
        size_t advance = 1;

        if (!dtintutils_decode(address, function->size - offset, &instruction)) {
            ++offset;
            continue;
        }
        advance = instruction.length;
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV && instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].register_id == 2 &&
            instruction.operands[0].size_bits == 64 &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
            instruction.operands[1].memory_index == DTINTUTILS_REGISTER_NONE &&
            instruction.operands[1].displacement > 0 && instruction.operands[1].displacement <= 0x1000 &&
            sa_register_in_set(instruction.operands[1].memory_base, owner_registers, owner_count)) {
            last_root_load = address;
        } else if (sa_is_stack_address(&instruction, 1)) {
            last_output_address = address;
        } else if (sa_is_stack_address(&instruction, 9)) {
            last_allocator_address = address;
        } else if (sa_is_register_move(&instruction, 8, path_registers, path_count)) {
            last_path_move = address;
        }

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count == 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            instruction.operands[0].has_absolute) {
            const uint8_t *candidate =
                (const uint8_t *)(uintptr_t)instruction.operands[0].absolute;
            const uint8_t *window_start = address > function->start + 128
                ? address - 128
                : function->start;
            const uint8_t *following_limit = address + instruction.length + 32 < limit
                ? address + instruction.length + 32
                : limit;

            if (last_root_load != NULL && last_root_load >= window_start &&
                last_output_address != NULL && last_output_address >= window_start &&
                last_allocator_address != NULL && last_allocator_address >= window_start &&
                last_path_move != NULL && last_path_move >= window_start &&
                dtintutils_is_executable_address(image, candidate) &&
                sa_validate_path_join_target(image, candidate) &&
                sa_has_following_direct_call(image, address + instruction.length, following_limit)) {
                selected_target = candidate;
                ++match_count;
            }
            last_root_load = NULL;
            last_output_address = NULL;
            last_allocator_address = NULL;
            last_path_move = NULL;
        }
        offset += advance;
    }

    if (match_count != 1) {
        sa_set_error(error, error_size,
                     "FileClient::open_input path-join analysis produced %zu candidates; expected 1",
                     match_count);
        return 0;
    }
    *target = selected_target;
    return 1;
}

