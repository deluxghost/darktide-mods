#include "internal.h"

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
        (instruction->operands[1].memory_base == SA_REGISTER_RSP ||
         instruction->operands[1].memory_base == SA_REGISTER_RBP) &&
        instruction->operands[1].memory_index == DTINTUTILS_REGISTER_NONE;
}

static int sa_path_join_target_matches(
    const SaImage *image,
    const SaFunction *function,
    const uint8_t *candidate_target
) {
    int owner_registers[SA_X64_REGISTER_COUNT];
    int path_registers[SA_X64_REGISTER_COUNT];
    size_t owner_count = sa_collect_entry_registers(
        function, SA_REGISTER_RCX, owner_registers, SA_ARRAY_COUNT(owner_registers));
    size_t path_count = sa_collect_entry_registers(
        function, SA_REGISTER_R8, path_registers, SA_ARRAY_COUNT(path_registers));
    const uint8_t *cursor = function->start;
    const uint8_t *limit = function->start + function->size;
    DtIntUtilsInstruction instruction;
    int root_ready = 0;
    int output_ready = 0;
    int allocator_ready = 0;
    int path_ready = 1;
    size_t match_count = 0;

    if (owner_count == 0 || owner_count > SA_ARRAY_COUNT(owner_registers) ||
        path_count == 0 || path_count > SA_ARRAY_COUNT(path_registers)) {
        return 0;
    }

    while (sa_next_instruction(&cursor, limit, &instruction)) {
        int root_load = instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
            instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].register_id == SA_REGISTER_RDX &&
            instruction.operands[0].size_bits == 64 &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
            instruction.operands[1].memory_index == DTINTUTILS_REGISTER_NONE &&
            instruction.operands[1].displacement >= 0 &&
            sa_register_in_set(
                instruction.operands[1].memory_base, owner_registers, owner_count);
        int output_address = sa_is_stack_address(&instruction, SA_REGISTER_RCX);
        int allocator_address = sa_is_stack_address(&instruction, SA_REGISTER_R9);
        int path_move = sa_is_register_move(
            &instruction, SA_REGISTER_R8, path_registers, path_count);

        if (root_load || dtintutils_instruction_writes_register(&instruction, SA_REGISTER_RDX)) {
            root_ready = root_load;
        }
        if (output_address || dtintutils_instruction_writes_register(&instruction, SA_REGISTER_RCX)) {
            output_ready = output_address;
        }
        if (allocator_address || dtintutils_instruction_writes_register(&instruction, SA_REGISTER_R9)) {
            allocator_ready = allocator_address;
        }
        if (path_move || dtintutils_instruction_writes_register(&instruction, SA_REGISTER_R8)) {
            path_ready = path_move;
        }

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL) {
            if (instruction.operand_count == 1 &&
                instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
                instruction.operands[0].has_absolute &&
                (const uint8_t *)(uintptr_t)instruction.operands[0].absolute == candidate_target &&
                dtintutils_is_executable_address(image, candidate_target) &&
                root_ready && output_ready && allocator_ready && path_ready) {
                ++match_count;
            }
            root_ready = 0;
            output_ready = 0;
            allocator_ready = 0;
            path_ready = 0;
        }
    }

    return match_count != 0;
}

typedef struct {
    const SaFunction *function;
} SaPathJoinContext;

static int sa_validate_path_join_candidate(
    const SaImage *image,
    const uint8_t *candidate,
    void *context
) {
    const SaPathJoinContext *path_context = (const SaPathJoinContext *)context;

    return sa_path_join_target_matches(image, path_context->function, candidate);
}

int sa_analyze_path_join_call(
    const SaImage *image,
    const SaFunction *function,
    const uint8_t **target,
    char *error,
    size_t error_size
) {
    SaPathJoinContext context;

    if (image == NULL || function == NULL || target == NULL) {
        sa_set_error(error, error_size, "path-join locator received a null argument");
        return 0;
    }
    const DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_ADDRESS(function->start, 1, 1),
        DTINTUTILS_LOCATE_COLLECT_FUNCTION_CALL_TARGETS(1, 0),
    };
    const DtIntUtilsLocator locator = {
        "FileClient path join",
        steps,
        SA_ARRAY_COUNT(steps),
    };
    context.function = function;

    return dtintutils_locate_unique_address_with_validator(
        image, &locator, sa_validate_path_join_candidate, &context,
        target, error, error_size);
}