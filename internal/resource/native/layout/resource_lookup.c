#include "internal.h"

static int sa_register_is_call_preserved(int register_id) {
    return register_id == SA_REGISTER_RBX || register_id == SA_REGISTER_RSP ||
        register_id == SA_REGISTER_RBP || register_id == SA_REGISTER_RSI ||
        register_id == SA_REGISTER_RDI || register_id == SA_REGISTER_R12 ||
        register_id == SA_REGISTER_R13 || register_id == SA_REGISTER_R14 ||
        register_id == SA_REGISTER_R15;
}

static int sa_find_callback_arguments(
    const uint8_t *function_start,
    const uint8_t *call_address,
    int record_register,
    uint32_t record_size,
    uint32_t *user_data_offset
) {
    const uint8_t *cursor = function_start;
    int owner_aliases[SA_X64_REGISTER_COUNT] = {0};
    int from_owner[SA_X64_REGISTER_COUNT] = {0};
    DtIntUtilsInstruction instruction;
    int user_data_ready = 0;
    int resource_manager_ready = 0;

    owner_aliases[SA_REGISTER_RCX] = 1;

    while (sa_next_instruction(&cursor, call_address, &instruction)) {
        int destination_register = -1;
        int source_is_owner_alias = 0;
        int source_is_owner = 0;
        int user_data_load = 0;
        uint32_t candidate_user_data_offset = 0;
        int register_id;

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL) {
            user_data_ready = 0;
            resource_manager_ready = 0;
            for (register_id = 0; register_id < SA_X64_REGISTER_COUNT; ++register_id) {
                if (!sa_register_is_call_preserved(register_id)) {
                    owner_aliases[register_id] = 0;
                    from_owner[register_id] = 0;
                }
            }
            continue;
        }

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
            instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].register_id >= 0 &&
            instruction.operands[0].register_id < SA_X64_REGISTER_COUNT) {
            const DtIntUtilsOperand *destination = &instruction.operands[0];
            const DtIntUtilsOperand *source = &instruction.operands[1];

            destination_register = destination->register_id;
            source_is_owner_alias =
                source->type == DTINTUTILS_OPERAND_REGISTER && source->size_bits == 64 &&
                source->register_id >= 0 && source->register_id < SA_X64_REGISTER_COUNT &&
                owner_aliases[source->register_id];
            source_is_owner =
                (source->type == DTINTUTILS_OPERAND_MEMORY && source->size_bits == 64 &&
                 source->memory_index == DTINTUTILS_REGISTER_NONE && source->displacement >= 0 &&
                 source->memory_base >= 0 && source->memory_base < SA_X64_REGISTER_COUNT &&
                 owner_aliases[source->memory_base]) ||
                (source->type == DTINTUTILS_OPERAND_REGISTER && source->size_bits == 64 &&
                 source->register_id >= 0 && source->register_id < SA_X64_REGISTER_COUNT &&
                 from_owner[source->register_id]);

            user_data_load = destination_register == SA_REGISTER_RCX &&
                destination->size_bits == 64 &&
                source->type == DTINTUTILS_OPERAND_MEMORY &&
                source->memory_base == record_register &&
                source->memory_index == DTINTUTILS_REGISTER_NONE &&
                source->displacement >= (int64_t)sizeof(uint64_t) &&
                (source->displacement % (int64_t)sizeof(void *)) == 0 &&
                (uint64_t)source->displacement + sizeof(void *) <= record_size;
            if (user_data_load) {
                candidate_user_data_offset = (uint32_t)source->displacement;
            }
        }

        if (dtintutils_instruction_writes_register(&instruction, SA_REGISTER_RCX)) {
            user_data_ready = user_data_load;
            if (user_data_load) {
                *user_data_offset = candidate_user_data_offset;
            }
        }
        if (dtintutils_instruction_writes_register(&instruction, SA_REGISTER_R8)) {
            resource_manager_ready = destination_register == SA_REGISTER_R8 && source_is_owner;
        }
        for (register_id = 0; register_id < SA_X64_REGISTER_COUNT; ++register_id) {
            if (dtintutils_instruction_writes_register(&instruction, register_id)) {
                owner_aliases[register_id] = 0;
                from_owner[register_id] = 0;
            }
        }
        if (destination_register >= 0) {
            owner_aliases[destination_register] = source_is_owner_alias;
            from_owner[destination_register] = source_is_owner;
        }
    }
    return user_data_ready && resource_manager_ready;
}

int sa_analyze_resource_lookup_shape(
    const SaFunction *function,
    const SaTypeLayout *layout,
    uint32_t *user_data_offset,
    uint32_t *callback_offset,
    char *error,
    size_t error_size
) {
    const uint8_t *cursor;
    const uint8_t *limit;
    DtIntUtilsInstruction instruction;
    uint32_t match = 0;
    uint32_t user_data_match = 0;
    size_t match_count = 0;

    if (function == NULL || layout == NULL || user_data_offset == NULL || callback_offset == NULL) {
        sa_set_error(error, error_size, "resource-lookup callback analysis received a null argument");
        return 0;
    }

    cursor = function->start;
    limit = function->start + function->size;
    while (sa_next_instruction(&cursor, limit, &instruction)) {
        const DtIntUtilsOperand *operand;
        int64_t displacement;
        uint32_t candidate_user_data_offset;

        if (instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL || instruction.operand_count != 1) {
            continue;
        }
        operand = &instruction.operands[0];
        if (operand->type != DTINTUTILS_OPERAND_MEMORY ||
            operand->memory_base < 0 || operand->memory_base >= SA_X64_REGISTER_COUNT ||
            operand->memory_index != DTINTUTILS_REGISTER_NONE) {
            continue;
        }
        displacement = operand->displacement;
        if (displacement < (int64_t)sizeof(uint64_t) ||
            (displacement % (int64_t)sizeof(void *)) != 0 ||
            (uint64_t)displacement + sizeof(void *) > layout->record_size ||
            !sa_find_callback_arguments(
                function->start, instruction.address, operand->memory_base,
                layout->record_size, &candidate_user_data_offset)) {
            continue;
        }
        match = (uint32_t)displacement;
        user_data_match = candidate_user_data_offset;
        ++match_count;
    }

    if (match_count != 1) {
        sa_set_error(error, error_size,
                     "resource-lookup callback analysis produced %zu candidates; expected 1",
                     match_count);
        return 0;
    }
    *user_data_offset = user_data_match;
    *callback_offset = match;
    return 1;
}