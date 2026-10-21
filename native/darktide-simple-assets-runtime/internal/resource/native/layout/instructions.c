#include "internal.h"

static int sa_parse_rip_relative(
    const DtIntUtilsInstruction *instruction,
    DtIntUtilsMnemonic mnemonic,
    int store,
    int expected_register,
    const uint8_t **target,
    int *register_value
) {
    const DtIntUtilsOperand *register_operand;
    const DtIntUtilsOperand *memory_operand;

    if (instruction == NULL || target == NULL || instruction->mnemonic != mnemonic ||
        instruction->operand_count != 2) {
        return 0;
    }
    if (store) {
        memory_operand = &instruction->operands[0];
        register_operand = &instruction->operands[1];
    } else {
        register_operand = &instruction->operands[0];
        memory_operand = &instruction->operands[1];
    }
    if (register_operand->type != DTINTUTILS_OPERAND_REGISTER ||
        memory_operand->type != DTINTUTILS_OPERAND_MEMORY ||
        memory_operand->memory_base != DTINTUTILS_REGISTER_RIP || !memory_operand->has_absolute ||
        (expected_register >= 0 && register_operand->register_id != expected_register)) {
        return 0;
    }
    *target = (const uint8_t *)(uintptr_t)memory_operand->absolute;
    if (register_value != NULL) {
        *register_value = register_operand->register_id;
    }
    return 1;
}

static int sa_parse_reg_memory_instruction(
    const DtIntUtilsInstruction *instruction,
    DtIntUtilsMnemonic mnemonic,
    int require_wide,
    int *destination_register,
    SaMemoryOperand *operand
) {
    if (instruction == NULL || destination_register == NULL || operand == NULL ||
        instruction->mnemonic != mnemonic || instruction->operand_count != 2 ||
        instruction->operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
        instruction->operands[1].type != DTINTUTILS_OPERAND_MEMORY ||
        instruction->operands[1].memory_base < 0 ||
        instruction->operands[1].memory_base >= SA_X64_REGISTER_COUNT ||
        instruction->operands[1].memory_index != DTINTUTILS_REGISTER_NONE ||
        instruction->operands[1].displacement < INT32_MIN ||
        instruction->operands[1].displacement > INT32_MAX ||
        (require_wide && instruction->operands[0].size_bits != 64)) {
        return 0;
    }

    *destination_register = instruction->operands[0].register_id;
    operand->base_register = instruction->operands[1].memory_base;
    operand->displacement = (int32_t)instruction->operands[1].displacement;
    return 1;
}

static int sa_next_instruction(
    const uint8_t **cursor,
    const uint8_t *limit,
    DtIntUtilsInstruction *instruction
) {
    while (*cursor < limit) {
        if (dtintutils_decode(*cursor, (size_t)(limit - *cursor), instruction)) {
            *cursor += instruction->length;
            return 1;
        }
        ++*cursor;
    }
    return 0;
}

static const uint8_t *sa_after_last_call(const uint8_t *start, const uint8_t *limit) {
    const uint8_t *boundary = start;
    const uint8_t *cursor = start;
    DtIntUtilsInstruction instruction;

    while (sa_next_instruction(&cursor, limit, &instruction)) {
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL) {
            boundary = cursor;
        }
    }
    return boundary;
}

static const uint8_t *sa_before_next_call(const uint8_t *start, const uint8_t *limit) {
    const uint8_t *cursor = start;
    DtIntUtilsInstruction instruction;

    while (sa_next_instruction(&cursor, limit, &instruction)) {
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL) {
            return instruction.address;
        }
    }
    return limit;
}

static size_t sa_collect_entry_registers(
    const SaFunction *function,
    int source_register,
    int *registers,
    size_t capacity
) {
    size_t copy_count;

    if (function == NULL || registers == NULL || capacity == 0) {
        return 0;
    }
    registers[0] = source_register;
    copy_count = dtintutils_collect_entry_register_copies(
        function, source_register, registers + 1, capacity - 1);
    if (copy_count > capacity - 1) {
        return capacity + 1;
    }
    return copy_count + 1;
}

static int sa_register_in_set(int value, const int *registers, size_t register_count) {
    size_t index;

    for (index = 0; index < register_count; ++index) {
        if (registers[index] == value) {
            return 1;
        }
    }
    return 0;
}
