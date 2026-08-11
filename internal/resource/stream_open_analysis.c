#include "runtime_internal.h"

#include <limits.h>
#include <string.h>

static int sa_is_move_immediate_to_register(
    const DtIntUtilsInstruction *instruction,
    int register_id,
    uint64_t immediate
) {
    return instruction->mnemonic == DTINTUTILS_MNEMONIC_MOV && instruction->operand_count == 2 &&
        instruction->operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
        instruction->operands[0].register_id == register_id &&
        instruction->operands[1].type == DTINTUTILS_OPERAND_IMMEDIATE &&
        instruction->operands[1].immediate == immediate;
}

static int sa_stack_frame_delta(const SaFunction *function, int32_t *rbp_from_rsp) {
    size_t limit = function->size < 160 ? function->size : 160;
    size_t offset;
    int found_lea = 0;
    int found_sub = 0;
    int32_t lea_displacement = 0;
    uint32_t sub_amount = 0;

    for (offset = 0; offset < limit; ++offset) {
        const uint8_t *instruction = function->start + offset;
        const uint8_t *function_limit = function->start + limit;
        SaMemoryOperand operand;
        int destination;
        size_t length;

        if (sa_parse_reg_memory_instruction(instruction, function_limit, 0x8d, 1,
                                            &destination, &operand, &length) &&
            destination == 5 && operand.base_register == 4) {
            if (found_lea) {
                return 0;
            }
            found_lea = 1;
            lea_displacement = operand.displacement;
            continue;
        }

        if (offset + 4 <= limit && instruction[0] == 0x48 && instruction[1] == 0x83 &&
            instruction[2] == 0xec) {
            if (found_sub) {
                return 0;
            }
            found_sub = 1;
            sub_amount = instruction[3];
        } else if (offset + 7 <= limit && instruction[0] == 0x48 && instruction[1] == 0x81 &&
                   instruction[2] == 0xec) {
            if (found_sub) {
                return 0;
            }
            found_sub = 1;
            memcpy(&sub_amount, instruction + 3, sizeof(sub_amount));
        }
    }

    if (!found_lea || !found_sub || sub_amount > INT32_MAX ||
        (int64_t)lea_displacement + sub_amount < INT32_MIN ||
        (int64_t)lea_displacement + sub_amount > INT32_MAX) {
        return 0;
    }
    *rbp_from_rsp = lea_displacement + (int32_t)sub_amount;
    return 1;
}

static int sa_stack_offset(int base_register, int64_t displacement, int32_t rbp_from_rsp, int32_t *offset) {
    int64_t value;

    if (base_register == 4) {
        value = displacement;
    } else if (base_register == 5) {
        value = (int64_t)rbp_from_rsp + displacement;
    } else {
        return 0;
    }
    if (value < INT32_MIN || value > INT32_MAX) {
        return 0;
    }
    *offset = (int32_t)value;
    return 1;
}

static int sa_find_loader_derivation(
    const uint8_t *function_start,
    const uint8_t *call_address,
    int manager_register,
    uint32_t *manager_offset,
    uint32_t *subobject_offset
) {
    const uint8_t *adjustment_start = call_address > function_start + 48 ? call_address - 48 : function_start;
    const uint8_t *adjust;
    size_t matches = 0;
    uint32_t selected_manager_offset = 0;
    uint32_t selected_subobject_offset = 0;

    for (adjust = adjustment_start; adjust < call_address; ++adjust) {
        DtIntUtilsInstruction decoded;
        int temporary_register = -1;
        int64_t adjustment = -1;
        const uint8_t *cursor;
        int32_t last_manager_displacement = -1;

        if (!dtintutils_decode(adjust, (size_t)(call_address - adjust), &decoded)) {
            continue;
        }
        if (decoded.mnemonic == DTINTUTILS_MNEMONIC_ADD && decoded.operand_count == 2 &&
            decoded.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            decoded.operands[0].register_id == 8 &&
            decoded.operands[1].type == DTINTUTILS_OPERAND_IMMEDIATE) {
            temporary_register = 8;
            adjustment = decoded.operands[1].immediate;
        } else if (decoded.mnemonic == DTINTUTILS_MNEMONIC_LEA && decoded.operand_count == 2 &&
                   decoded.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
                   decoded.operands[0].register_id == 8 &&
                   decoded.operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
                   decoded.operands[1].memory_index == DTINTUTILS_REGISTER_NONE) {
            temporary_register = decoded.operands[1].memory_base;
            adjustment = decoded.operands[1].displacement;
        }
        if (temporary_register < 0 || adjustment < 0 || adjustment > UINT32_MAX) {
            continue;
        }

        for (cursor = function_start; cursor < adjust; ++cursor) {
            SaMemoryOperand operand;
            int destination;
            size_t length;
            if (sa_parse_reg_memory_instruction(cursor, adjust, 0x8b, 1,
                                                &destination, &operand, &length) &&
                destination == temporary_register && operand.base_register == manager_register &&
                operand.displacement >= 0) {
                last_manager_displacement = operand.displacement;
            }
        }
        if (last_manager_displacement < 0) {
            continue;
        }

        selected_manager_offset = (uint32_t)last_manager_displacement;
        selected_subobject_offset = (uint32_t)adjustment;
        ++matches;
    }

    if (matches != 1) {
        return 0;
    }
    *manager_offset = selected_manager_offset;
    *subobject_offset = selected_subobject_offset;
    return 1;
}

int sa_analyze_open_stream(
    const SaImage *image,
    const SaFunction *function,
    SaOpenStreamShape *shape,
    char *error,
    size_t error_size
) {
    int manager_registers[8];
    size_t manager_count = sa_collect_argument_registers(
        function, 1, manager_registers, SA_ARRAY_COUNT(manager_registers));
    int32_t rbp_from_rsp;
    SaOpenStreamShape matches[8];
    size_t match_count = 0;
    size_t offset;

    if (manager_count == 0 || manager_count > SA_ARRAY_COUNT(manager_registers) ||
        !sa_stack_frame_delta(function, &rbp_from_rsp)) {
        sa_set_error(error, error_size,
                     "open_stream does not have a uniquely analyzable manager register and stack frame");
        return 0;
    }

    for (offset = 0; offset < function->size; ++offset) {
        const uint8_t *call = function->start + offset;
        const uint8_t *function_limit = function->start + function->size;
        DtIntUtilsInstruction call_instruction;
        const uint8_t *helper;
        const uint8_t *window_start = call > function->start + 128 ? call - 128 : function->start;
        const uint8_t *cursor;
        const uint8_t *file_system_target = NULL;
        int saw_mode = 0;
        int32_t stream_base = 0;
        int saw_stream_base = 0;
        int32_t range_location = 0;
        int saw_range = 0;
        int32_t handle_location = 0;
        int saw_handle = 0;
        size_t manager_index;
        uint32_t loader_offset = 0;
        uint32_t loader_subobject_offset = 0;
        size_t loader_matches = 0;

        if (!dtintutils_decode(call, (size_t)(function_limit - call), &call_instruction) ||
            call_instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL ||
            call_instruction.operand_count != 1 ||
            call_instruction.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
            !call_instruction.operands[0].has_absolute) {
            continue;
        }
        helper = (const uint8_t *)(uintptr_t)call_instruction.operands[0].absolute;
        if (!dtintutils_is_executable_address(image, helper)) {
            continue;
        }

        for (cursor = window_start; cursor < call; ++cursor) {
            DtIntUtilsInstruction decoded;
            const uint8_t *target;
            SaMemoryOperand operand;
            int destination;
            size_t length;
            int32_t stack_value;

            if (!dtintutils_decode(cursor, (size_t)(call - cursor), &decoded)) {
                continue;
            }
            if (sa_is_move_immediate_to_register(&decoded, 2, 2)) {
                saw_mode = 1;
            }
            if (sa_parse_rip_relative(cursor, call, 0x8b, 1, &target, NULL, NULL) &&
                dtintutils_is_writable_address(image, target)) {
                if (file_system_target != NULL && file_system_target != target) {
                    file_system_target = NULL;
                    break;
                }
                file_system_target = target;
            }
            if (sa_parse_reg_memory_instruction(cursor, call, 0x8d, 1,
                                                &destination, &operand, &length) &&
                destination == 9 &&
                sa_stack_offset(operand.base_register, operand.displacement,
                                rbp_from_rsp, &stack_value)) {
                stream_base = stack_value;
                saw_stream_base = 1;
            }
            if (decoded.mnemonic == DTINTUTILS_MNEMONIC_MOV && decoded.operand_count == 2 &&
                decoded.operands[0].type == DTINTUTILS_OPERAND_MEMORY &&
                decoded.operands[1].type == DTINTUTILS_OPERAND_IMMEDIATE &&
                (uint32_t)decoded.operands[1].immediate == UINT32_MAX &&
                sa_stack_offset(decoded.operands[0].memory_base,
                                decoded.operands[0].displacement,
                                rbp_from_rsp, &stack_value)) {
                range_location = stack_value;
                saw_range = 1;
            }
        }

        for (cursor = call + call_instruction.length;
             cursor < function_limit && cursor < call + call_instruction.length + 21; ++cursor) {
            DtIntUtilsInstruction decoded;
            int32_t stack_value;

            if (!dtintutils_decode(cursor, (size_t)(function_limit - cursor), &decoded) ||
                decoded.mnemonic != DTINTUTILS_MNEMONIC_MOV || decoded.operand_count != 2 ||
                decoded.operands[0].type != DTINTUTILS_OPERAND_MEMORY ||
                decoded.operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
                decoded.operands[1].register_id != 0 ||
                !sa_stack_offset(decoded.operands[0].memory_base,
                                 decoded.operands[0].displacement,
                                 rbp_from_rsp, &stack_value)) {
                continue;
            }
            handle_location = stack_value;
            saw_handle = 1;
            break;
        }

        if (!saw_mode || file_system_target == NULL || !saw_stream_base || !saw_range || !saw_handle ||
            range_location <= stream_base || handle_location <= stream_base) {
            continue;
        }

        for (manager_index = 0; manager_index < manager_count; ++manager_index) {
            uint32_t candidate_loader_offset;
            uint32_t candidate_subobject_offset;
            if (sa_find_loader_derivation(function->start, call, manager_registers[manager_index],
                                          &candidate_loader_offset, &candidate_subobject_offset)) {
                loader_offset = candidate_loader_offset;
                loader_subobject_offset = candidate_subobject_offset;
                ++loader_matches;
            }
        }
        if (loader_matches != 1) {
            continue;
        }

        if ((uint32_t)(range_location - stream_base) < 64 ||
            (uint32_t)(range_location - stream_base) > SA_MAX_STREAM_PATH ||
            handle_location - stream_base != range_location - stream_base + 8) {
            continue;
        }

        if (match_count < SA_ARRAY_COUNT(matches)) {
            matches[match_count].helper = helper;
            matches[match_count].file_system_slot = (void **)file_system_target;
            matches[match_count].loader_offset = loader_offset;
            matches[match_count].loader_subobject_offset = loader_subobject_offset;
            matches[match_count].range_offset = (uint32_t)(range_location - stream_base);
            matches[match_count].handle_offset = (uint32_t)(handle_location - stream_base);
        }
        ++match_count;
    }

    if (match_count != 2) {
        sa_set_error(error, error_size,
                     "open_stream whole-file analysis produced %zu helper calls; expected 2", match_count);
        return 0;
    }
    if (matches[0].helper != matches[1].helper ||
        matches[0].file_system_slot != matches[1].file_system_slot ||
        matches[0].loader_offset != matches[1].loader_offset ||
        matches[0].loader_subobject_offset != matches[1].loader_subobject_offset ||
        matches[0].range_offset != matches[1].range_offset ||
        matches[0].handle_offset != matches[1].handle_offset) {
        sa_set_error(error, error_size,
                     "open_stream whole-file branches do not derive the same engine layout");
        return 0;
    }

    *shape = matches[0];
    return 1;
}

