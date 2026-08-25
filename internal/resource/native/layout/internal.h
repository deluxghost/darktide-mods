#ifndef SIMPLE_ASSETS_RESOURCE_LAYOUT_INTERNAL_H
#define SIMPLE_ASSETS_RESOURCE_LAYOUT_INTERNAL_H

#include "../runtime_internal.h"

enum {
    SA_REGISTER_RAX = 0,
    SA_REGISTER_RCX = 1,
    SA_REGISTER_RDX = 2,
    SA_REGISTER_RBX = 3,
    SA_REGISTER_RSP = 4,
    SA_REGISTER_RBP = 5,
    SA_REGISTER_RSI = 6,
    SA_REGISTER_RDI = 7,
    SA_REGISTER_R8 = 8,
    SA_REGISTER_R9 = 9,
    SA_REGISTER_R12 = 12,
    SA_REGISTER_R13 = 13,
    SA_REGISTER_R14 = 14,
    SA_REGISTER_R15 = 15,
    SA_X64_REGISTER_COUNT = 16,
};

typedef struct {
    int base_register;
    int32_t displacement;
} SaMemoryOperand;

static int sa_parse_rip_relative(
    const DtIntUtilsInstruction *instruction,
    DtIntUtilsMnemonic mnemonic,
    int store,
    int expected_register,
    const uint8_t **target,
    int *register_value
);
static int sa_parse_reg_memory_instruction(
    const DtIntUtilsInstruction *instruction,
    DtIntUtilsMnemonic mnemonic,
    int require_wide,
    int *destination_register,
    SaMemoryOperand *operand
);
static int sa_next_instruction(
    const uint8_t **cursor,
    const uint8_t *limit,
    DtIntUtilsInstruction *instruction
);
static const uint8_t *sa_after_last_call(const uint8_t *start, const uint8_t *limit);
static const uint8_t *sa_before_next_call(const uint8_t *start, const uint8_t *limit);
static size_t sa_collect_entry_registers(
    const SaFunction *function,
    int source_register,
    int *registers,
    size_t capacity
);
static int sa_register_in_set(int value, const int *registers, size_t register_count);

#endif