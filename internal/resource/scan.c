#include "runtime_internal.h"

int sa_parse_rip_relative(
    const uint8_t *instruction,
    const uint8_t *limit,
    uint8_t opcode,
    int expected_reg,
    const uint8_t **target,
    int *register_value,
    size_t *length
) {
    DtIntUtilsInstruction decoded;
    DtIntUtilsMnemonic mnemonic;
    const DtIntUtilsOperand *register_operand;
    const DtIntUtilsOperand *memory_operand;

    if (instruction >= limit || target == NULL ||
        !dtintutils_decode(instruction, (size_t)(limit - instruction), &decoded)) {
        return 0;
    }
    mnemonic = opcode == 0x8d ? DTINTUTILS_MNEMONIC_LEA :
        opcode == 0x89 ? DTINTUTILS_MNEMONIC_MOV : DTINTUTILS_MNEMONIC_OTHER;
    if (decoded.mnemonic != mnemonic || decoded.operand_count != 2) {
        return 0;
    }
    if (opcode == 0x89) {
        memory_operand = &decoded.operands[0];
        register_operand = &decoded.operands[1];
    } else {
        register_operand = &decoded.operands[0];
        memory_operand = &decoded.operands[1];
    }
    if (register_operand->type != DTINTUTILS_OPERAND_REGISTER ||
        memory_operand->type != DTINTUTILS_OPERAND_MEMORY ||
        memory_operand->memory_base != DTINTUTILS_REGISTER_RIP || !memory_operand->has_absolute ||
        (expected_reg >= 0 && register_operand->register_id != expected_reg)) {
        return 0;
    }
    *target = (const uint8_t *)(uintptr_t)memory_operand->absolute;
    if (register_value != NULL) {
        *register_value = register_operand->register_id;
    }
    if (length != NULL) {
        *length = decoded.length;
    }
    return 1;
}

int sa_parse_reg_memory_instruction(
    const uint8_t *instruction,
    const uint8_t *limit,
    uint8_t opcode,
    int require_wide,
    int *destination_register,
    SaMemoryOperand *operand,
    size_t *length
) {
    DtIntUtilsInstruction decoded;
    DtIntUtilsMnemonic mnemonic = opcode == 0x8d ? DTINTUTILS_MNEMONIC_LEA :
        opcode == 0x8b ? DTINTUTILS_MNEMONIC_MOV :
        opcode == 0x03 ? DTINTUTILS_MNEMONIC_ADD : DTINTUTILS_MNEMONIC_OTHER;

    if (instruction >= limit || destination_register == NULL || operand == NULL || length == NULL ||
        !dtintutils_decode(instruction, (size_t)(limit - instruction), &decoded) ||
        decoded.mnemonic != mnemonic || decoded.operand_count != 2 ||
        decoded.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
        decoded.operands[1].type != DTINTUTILS_OPERAND_MEMORY ||
        decoded.operands[1].memory_base < 0 || decoded.operands[1].memory_base > 15 ||
        decoded.operands[1].memory_index != DTINTUTILS_REGISTER_NONE ||
        (require_wide && decoded.operands[0].size_bits != 64)) {
        return 0;
    }

    *destination_register = decoded.operands[0].register_id;
    operand->base_register = decoded.operands[1].memory_base;
    operand->displacement = (int32_t)decoded.operands[1].displacement;
    operand->length = decoded.length;
    *length = decoded.length;
    return 1;
}

int sa_parse_memory_reg_instruction(
    const uint8_t *instruction,
    const uint8_t *limit,
    uint8_t opcode,
    int require_wide,
    SaMemoryOperand *operand,
    int *source_register,
    size_t *length
) {
    DtIntUtilsInstruction decoded;
    DtIntUtilsMnemonic mnemonic = opcode == 0x89 ? DTINTUTILS_MNEMONIC_MOV : DTINTUTILS_MNEMONIC_OTHER;

    if (instruction >= limit || source_register == NULL || operand == NULL || length == NULL ||
        !dtintutils_decode(instruction, (size_t)(limit - instruction), &decoded) ||
        decoded.mnemonic != mnemonic || decoded.operand_count != 2 ||
        decoded.operands[0].type != DTINTUTILS_OPERAND_MEMORY ||
        decoded.operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
        decoded.operands[0].memory_base < 0 || decoded.operands[0].memory_base > 15 ||
        decoded.operands[0].memory_index != DTINTUTILS_REGISTER_NONE ||
        (require_wide && decoded.operands[1].size_bits != 64)) {
        return 0;
    }

    *source_register = decoded.operands[1].register_id;
    operand->base_register = decoded.operands[0].memory_base;
    operand->displacement = (int32_t)decoded.operands[0].displacement;
    operand->length = decoded.length;
    *length = decoded.length;
    return 1;
}

int sa_register_in_set(int value, const int *registers, size_t register_count) {
    size_t index;

    for (index = 0; index < register_count; ++index) {
        if (registers[index] == value) {
            return 1;
        }
    }
    return 0;
}

size_t sa_collect_argument_registers(
    const SaFunction *function,
    int source_register,
    int *registers,
    size_t capacity
) {
    size_t result_count = 0;
    size_t limit = function->size < 128 ? function->size : 128;
    size_t offset;

    for (offset = 0; offset + 3 <= limit; ++offset) {
        const uint8_t *instruction = function->start + offset;
        DtIntUtilsInstruction decoded;
        int destination;
        int source;
        size_t index;
        int duplicate = 0;

        if (!dtintutils_decode(instruction, limit - offset, &decoded) ||
            decoded.mnemonic != DTINTUTILS_MNEMONIC_MOV || decoded.operand_count != 2 ||
            decoded.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
            decoded.operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
            decoded.operands[0].size_bits != 64 || decoded.operands[1].size_bits != 64) {
            continue;
        }
        destination = decoded.operands[0].register_id;
        source = decoded.operands[1].register_id;
        if (source != source_register || destination == source_register || destination == 4) {
            continue;
        }
        for (index = 0; index < result_count && index < capacity; ++index) {
            if (registers[index] == destination) {
                duplicate = 1;
                break;
            }
        }
        if (!duplicate) {
            if (result_count < capacity) {
                registers[result_count] = destination;
            }
            ++result_count;
        }
    }
    return result_count;
}

static size_t sa_collect_manager_registers(const SaFunction *function, int *registers, size_t capacity) {
    return sa_collect_argument_registers(function, 1, registers, capacity);
}

static int sa_find_direct_call(
    const uint8_t *start,
    const uint8_t *limit,
    const uint8_t **call_address,
    const uint8_t **target
) {
    const uint8_t *cursor;
    for (cursor = start; cursor < limit; ++cursor) {
        DtIntUtilsInstruction decoded;
        if (!dtintutils_decode(cursor, (size_t)(limit - cursor), &decoded) || decoded.length != 5 ||
            decoded.mnemonic != DTINTUTILS_MNEMONIC_CALL || decoded.operand_count != 1 ||
            decoded.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
            !decoded.operands[0].has_absolute) {
            continue;
        }
        *call_address = cursor;
        *target = (const uint8_t *)(uintptr_t)decoded.operands[0].absolute;
        return 1;
    }
    return 0;
}

int sa_analyze_type_layout(
    const SaImage *image,
    const SaFunction *function,
    SaTypeLayout *layout,
    const uint8_t **lookup_helper,
    char *error,
    size_t error_size
) {
    int manager_registers[8];
    size_t manager_count = sa_collect_manager_registers(function, manager_registers, SA_ARRAY_COUNT(manager_registers));
    SaTypeLayout matches[SA_MAX_CANDIDATES];
    const uint8_t *match_helpers[SA_MAX_CANDIDATES];
    size_t match_count = 0;
    size_t manager_index;

    if (manager_count == 0 || manager_count > SA_ARRAY_COUNT(manager_registers)) {
        sa_set_error(error, error_size, "function does not have a bounded manager-register candidate set");
        return 0;
    }

    for (manager_index = 0; manager_index < manager_count; ++manager_index) {
        int manager_register = manager_registers[manager_index];
        size_t offset;

        for (offset = 0; offset < function->size; ++offset) {
            const uint8_t *instruction = function->start + offset;
            const uint8_t *function_limit = function->start + function->size;
            SaMemoryOperand type_operand;
            int destination;
            size_t instruction_length;
            const uint8_t *lookup_call;
            const uint8_t *lookup_target;
            const uint8_t *cursor;
            int count_register = -1;
            int32_t count_displacement = 0;
            const uint8_t *count_end = NULL;
            int product_register = -1;
            uint32_t record_size = 0;
            const uint8_t *product_end = NULL;
            int32_t data_displacement = 0;
            int found_add = 0;

            if (!sa_parse_reg_memory_instruction(instruction, function_limit, 0x8d, 1, &destination,
                                                 &type_operand, &instruction_length) || destination != 1 ||
                type_operand.base_register != manager_register || type_operand.displacement < 0) {
                continue;
            }
            if (!sa_find_direct_call(instruction + instruction_length,
                                     instruction + instruction_length + 16 < function_limit
                                         ? instruction + instruction_length + 16
                                         : function_limit,
                                     &lookup_call, &lookup_target)) {
                continue;
            }
            if (!dtintutils_is_executable_address(image, lookup_target)) {
                continue;
            }

            for (cursor = lookup_call + 5; cursor < function_limit && cursor < lookup_call + 53; ++cursor) {
                SaMemoryOperand operand;
                size_t length;
                int reg;
                if (sa_parse_reg_memory_instruction(cursor, function_limit, 0x8b, 0, &reg, &operand, &length) &&
                    operand.base_register == manager_register && operand.displacement >= 0) {
                    count_register = reg;
                    count_displacement = operand.displacement;
                    count_end = cursor + length;
                    break;
                }
            }
            if (count_register < 0) {
                continue;
            }

            for (cursor = count_end; cursor < function_limit && cursor < count_end + 32; ++cursor) {
                DtIntUtilsInstruction decoded;
                int destination_reg;
                int source_reg;
                int32_t immediate;

                if (!dtintutils_decode(cursor, (size_t)(function_limit - cursor), &decoded) ||
                    decoded.mnemonic != DTINTUTILS_MNEMONIC_IMUL || decoded.operand_count != 3 ||
                    decoded.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
                    decoded.operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
                    decoded.operands[2].type != DTINTUTILS_OPERAND_IMMEDIATE ||
                    decoded.operands[0].size_bits != 64) {
                    continue;
                }
                destination_reg = decoded.operands[0].register_id;
                source_reg = decoded.operands[1].register_id;
                if (source_reg != count_register) {
                    continue;
                }
                immediate = (int32_t)decoded.operands[2].immediate;
                if (immediate <= 0) {
                    continue;
                }
                product_register = destination_reg;
                record_size = (uint32_t)immediate;
                product_end = cursor + decoded.length;
                break;
            }
            if (product_register < 0) {
                continue;
            }

            for (cursor = product_end; cursor < function_limit && cursor < product_end + 24; ++cursor) {
                SaMemoryOperand operand;
                size_t length;
                int reg;
                if (sa_parse_reg_memory_instruction(cursor, function_limit, 0x03, 1, &reg, &operand, &length) &&
                    reg == product_register && operand.base_register == manager_register &&
                    operand.displacement >= 0) {
                    data_displacement = operand.displacement;
                    found_add = 1;
                    break;
                }
            }
            if (!found_add || type_operand.displacement > 0x10000 || count_displacement > 0x10000 ||
                data_displacement > 0x10000 || record_size < 0x40 || record_size > 0x1000) {
                continue;
            }

            if ((uint32_t)count_displacement != (uint32_t)type_operand.displacement + 8 ||
                (uint32_t)data_displacement != (uint32_t)type_operand.displacement + 16) {
                continue;
            }

            if (match_count < SA_ARRAY_COUNT(matches)) {
                matches[match_count].type_table_offset = (uint32_t)type_operand.displacement;
                matches[match_count].type_count_offset = (uint32_t)count_displacement;
                matches[match_count].type_data_offset = (uint32_t)data_displacement;
                matches[match_count].record_size = record_size;
                match_helpers[match_count] = lookup_target;
            }
            ++match_count;
        }
    }

    if (match_count != 1) {
        sa_set_error(error, error_size, "resource type-table analysis produced %zu candidates; expected 1",
                     match_count);
        return 0;
    }
    *layout = matches[0];
    *lookup_helper = match_helpers[0];
    return 1;
}
