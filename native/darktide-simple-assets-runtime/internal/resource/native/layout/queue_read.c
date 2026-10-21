#include "internal.h"

#define SA_X64_FIFTH_ARGUMENT_STACK_OFFSET 0x20

typedef struct {
    size_t call_offset;
    uint32_t object_offset;
    uint32_t slot;
    uint32_t result_offset;
    int has_result;
} SaMethodCall;

typedef struct {
    const SaFunction *function;
    int worker_registers[SA_X64_REGISTER_COUNT];
    size_t worker_count;
    int request_registers[SA_X64_REGISTER_COUNT];
    size_t request_count;
    uint32_t request_size;
} SaQueueReadAnalysis;

static int sa_same_memory_operand(
    const DtIntUtilsOperand *left,
    const DtIntUtilsOperand *right
) {
    return left->type == DTINTUTILS_OPERAND_MEMORY &&
        right->type == DTINTUTILS_OPERAND_MEMORY &&
        left->memory_base == right->memory_base &&
        left->memory_index == right->memory_index &&
        left->displacement == right->displacement;
}

static int sa_is_request_operand(
    const SaQueueReadAnalysis *analysis,
    const DtIntUtilsOperand *operand,
    uint16_t size_bits
) {
    return operand->type == DTINTUTILS_OPERAND_MEMORY &&
        operand->memory_index == DTINTUTILS_REGISTER_NONE &&
        operand->displacement >= 0 &&
        (uint64_t)operand->displacement + size_bits / 8 <= analysis->request_size &&
        operand->size_bits == size_bits &&
        sa_register_in_set(
            operand->memory_base, analysis->request_registers, analysis->request_count);
}

static int sa_find_method_call(
    const SaFunction *function,
    size_t search_offset,
    int vtable_register,
    size_t *call_offset,
    uint32_t *slot
) {
    const uint8_t *cursor = function->start + search_offset;
    const uint8_t *limit = function->start + function->size;
    DtIntUtilsInstruction instruction;
    int method_register = -1;
    uint32_t method_slot = 0;

    while (sa_next_instruction(&cursor, limit, &instruction)) {
        const DtIntUtilsOperand *target;

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV && instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].size_bits == 64 &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
            instruction.operands[1].size_bits == 64 &&
            instruction.operands[1].memory_base == vtable_register &&
            instruction.operands[1].memory_index == DTINTUTILS_REGISTER_NONE &&
            instruction.operands[1].displacement >= 0 &&
            (instruction.operands[1].displacement % (int64_t)sizeof(void *)) == 0 &&
            instruction.operands[1].displacement <= UINT32_MAX) {
            method_register = instruction.operands[0].register_id;
            method_slot = (uint32_t)instruction.operands[1].displacement;
            continue;
        }
        if (method_register >= 0 &&
            dtintutils_instruction_writes_register(&instruction, method_register)) {
            method_register = -1;
        }
        if (instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL || instruction.operand_count != 1) {
            continue;
        }
        target = &instruction.operands[0];
        if (target->type == DTINTUTILS_OPERAND_MEMORY &&
            target->memory_base == vtable_register &&
            target->memory_index == DTINTUTILS_REGISTER_NONE &&
            target->displacement >= 0 &&
            (target->displacement % (int64_t)sizeof(void *)) == 0 &&
            target->displacement <= UINT32_MAX) {
            *call_offset = (size_t)(instruction.address - function->start);
            *slot = (uint32_t)target->displacement;
            return 1;
        }
        if (target->type == DTINTUTILS_OPERAND_REGISTER &&
            target->register_id == method_register) {
            *call_offset = (size_t)(instruction.address - function->start);
            *slot = method_slot;
            return 1;
        }
        return 0;
    }
    return 0;
}

static int sa_find_result_store(
    const SaQueueReadAnalysis *analysis,
    size_t call_offset,
    uint32_t *result_offset
) {
    const SaFunction *function = analysis->function;
    const uint8_t *call = function->start + call_offset;
    const uint8_t *function_limit = function->start + function->size;
    const uint8_t *cursor;
    const uint8_t *limit;
    DtIntUtilsInstruction instruction;

    if (!dtintutils_decode(call, (size_t)(function_limit - call), &instruction) ||
        instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL) {
        return 0;
    }
    cursor = call + instruction.length;
    limit = sa_before_next_call(cursor, function_limit);
    while (sa_next_instruction(&cursor, limit, &instruction)) {
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV && instruction.operand_count == 2 &&
            sa_is_request_operand(analysis, &instruction.operands[0], 64) &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[1].register_id == SA_REGISTER_RAX) {
            *result_offset = (uint32_t)instruction.operands[0].displacement;
            return 1;
        }
    }
    return 0;
}

static int sa_append_method_call(
    SaMethodCall **calls,
    size_t *count,
    size_t *capacity,
    const SaMethodCall *call
) {
    SaMethodCall *resized;
    size_t next_capacity;

    if (*count == *capacity) {
        next_capacity = *capacity == 0 ? 16 : *capacity * 2;
        if (next_capacity < *capacity || next_capacity > SIZE_MAX / sizeof(**calls)) {
            return 0;
        }
        resized = *calls == NULL
            ? (SaMethodCall *)HeapAlloc(GetProcessHeap(), 0, next_capacity * sizeof(**calls))
            : (SaMethodCall *)HeapReAlloc(
                GetProcessHeap(), 0, *calls, next_capacity * sizeof(**calls));
        if (resized == NULL) {
            return 0;
        }
        *calls = resized;
        *capacity = next_capacity;
    }
    (*calls)[(*count)++] = *call;
    return 1;
}

static int sa_collect_io_method_calls(
    const SaQueueReadAnalysis *analysis,
    SaMethodCall **calls,
    size_t *count
) {
    const SaFunction *function = analysis->function;
    const uint8_t *cursor = function->start;
    const uint8_t *limit = function->start + function->size;
    DtIntUtilsInstruction object_load;
    size_t capacity = 0;

    *calls = NULL;
    *count = 0;
    while (sa_next_instruction(&cursor, limit, &object_load)) {
        const uint8_t *vtable_cursor;
        const uint8_t *vtable_limit;
        DtIntUtilsInstruction vtable_load;

        if (object_load.mnemonic != DTINTUTILS_MNEMONIC_MOV ||
            object_load.operand_count != 2 ||
            object_load.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
            object_load.operands[0].register_id != SA_REGISTER_RCX ||
            object_load.operands[0].size_bits != 64 ||
            object_load.operands[1].type != DTINTUTILS_OPERAND_MEMORY ||
            object_load.operands[1].size_bits != 64 ||
            object_load.operands[1].memory_index != DTINTUTILS_REGISTER_NONE ||
            object_load.operands[1].displacement <= 0 ||
            object_load.operands[1].displacement > UINT32_MAX ||
            !sa_register_in_set(
                object_load.operands[1].memory_base,
                analysis->worker_registers,
                analysis->worker_count)) {
            continue;
        }

        vtable_cursor = cursor;
        vtable_limit = sa_before_next_call(vtable_cursor, limit);
        while (sa_next_instruction(&vtable_cursor, vtable_limit, &vtable_load)) {
            SaMethodCall call;
            size_t call_offset;
            uint32_t slot;

            if (vtable_load.mnemonic != DTINTUTILS_MNEMONIC_MOV ||
                vtable_load.operand_count != 2 ||
                vtable_load.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
                vtable_load.operands[0].size_bits != 64 ||
                vtable_load.operands[1].type != DTINTUTILS_OPERAND_MEMORY ||
                vtable_load.operands[1].size_bits != 64 ||
                vtable_load.operands[1].memory_base != SA_REGISTER_RCX ||
                vtable_load.operands[1].memory_index != DTINTUTILS_REGISTER_NONE ||
                vtable_load.operands[1].displacement != 0 ||
                !sa_find_method_call(
                    function, (size_t)(vtable_cursor - function->start),
                    vtable_load.operands[0].register_id, &call_offset, &slot)) {
                continue;
            }
            call.call_offset = call_offset;
            call.object_offset = (uint32_t)object_load.operands[1].displacement;
            call.slot = slot;
            call.has_result = sa_find_result_store(
                analysis, call_offset, &call.result_offset);
            if (!sa_append_method_call(calls, count, &capacity, &call)) {
                return 0;
            }
            break;
        }
    }
    return 1;
}

static int sa_find_request_register_argument(
    const SaQueueReadAnalysis *analysis,
    size_t call_offset,
    int argument_register,
    uint32_t *request_offset
) {
    const SaFunction *function = analysis->function;
    const uint8_t *call = function->start + call_offset;
    const uint8_t *cursor = sa_after_last_call(function->start, call);
    DtIntUtilsInstruction instruction;
    int found = 0;

    while (sa_next_instruction(&cursor, call, &instruction)) {
        if (!dtintutils_instruction_writes_register(&instruction, argument_register)) {
            continue;
        }
        found = instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
            instruction.operand_count == 2 &&
            sa_is_request_operand(analysis, &instruction.operands[1], 64);
        if (found) {
            *request_offset = (uint32_t)instruction.operands[1].displacement;
        }
    }
    return found;
}

static int sa_find_package_argument(
    const SaQueueReadAnalysis *analysis,
    size_t call_offset,
    uint32_t *package_offset
) {
    const SaFunction *function = analysis->function;
    const uint8_t *call = function->start + call_offset;
    const uint8_t *cursor = sa_after_last_call(function->start, call);
    uint32_t request_offsets[SA_X64_REGISTER_COUNT] = {0};
    int has_request_offset[SA_X64_REGISTER_COUNT] = {0};
    DtIntUtilsInstruction instruction;
    int found = 0;

    while (sa_next_instruction(&cursor, call, &instruction)) {
        int propagated_register = -1;
        uint32_t propagated_offset = 0;
        int register_id;

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
            instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].size_bits == 32 &&
            instruction.operands[0].register_id >= 0 &&
            instruction.operands[0].register_id < SA_X64_REGISTER_COUNT) {
            const DtIntUtilsOperand *source = &instruction.operands[1];

            propagated_register = instruction.operands[0].register_id;
            if (sa_is_request_operand(analysis, source, 32)) {
                propagated_offset = (uint32_t)source->displacement;
            } else if (source->type == DTINTUTILS_OPERAND_REGISTER &&
                       source->size_bits == 32 && source->register_id >= 0 &&
                       source->register_id < SA_X64_REGISTER_COUNT &&
                       has_request_offset[source->register_id]) {
                propagated_offset = request_offsets[source->register_id];
            } else {
                propagated_register = -1;
            }
        }

        if (instruction.operand_count >= 1 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_MEMORY &&
            instruction.operands[0].memory_base == SA_REGISTER_RSP &&
            instruction.operands[0].memory_index == DTINTUTILS_REGISTER_NONE &&
            instruction.operands[0].displacement == SA_X64_FIFTH_ARGUMENT_STACK_OFFSET &&
            (dtintutils_instruction_operand_access(&instruction, 0) &
             DTINTUTILS_OPERAND_ACCESS_WRITE) != 0) {
            found = instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
                instruction.operand_count == 2 &&
                instruction.operands[1].type == DTINTUTILS_OPERAND_REGISTER &&
                instruction.operands[1].register_id >= 0 &&
                instruction.operands[1].register_id < SA_X64_REGISTER_COUNT &&
                has_request_offset[instruction.operands[1].register_id];
            if (found) {
                *package_offset = request_offsets[instruction.operands[1].register_id];
            }
        }

        for (register_id = 0; register_id < SA_X64_REGISTER_COUNT; ++register_id) {
            if (has_request_offset[register_id] &&
                dtintutils_instruction_writes_register(&instruction, register_id)) {
                has_request_offset[register_id] = 0;
            }
        }
        if (propagated_register >= 0) {
            has_request_offset[propagated_register] = 1;
            request_offsets[propagated_register] = propagated_offset;
        }
    }
    return found;
}

static int sa_call_receives_open_handle(
    const SaQueueReadAnalysis *analysis,
    size_t call_offset,
    uint32_t handle_offset
) {
    const SaFunction *function = analysis->function;
    const uint8_t *call = function->start + call_offset;
    const uint8_t *cursor = sa_after_last_call(function->start, call);
    DtIntUtilsInstruction instruction;
    int receives_handle = 0;

    while (sa_next_instruction(&cursor, call, &instruction)) {
        if (!dtintutils_instruction_writes_register(&instruction, SA_REGISTER_RDX)) {
            continue;
        }
        receives_handle = instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
            instruction.operand_count == 2 &&
            ((instruction.operands[1].type == DTINTUTILS_OPERAND_REGISTER &&
              instruction.operands[1].register_id == SA_REGISTER_RAX) ||
             (sa_is_request_operand(analysis, &instruction.operands[1], 64) &&
              instruction.operands[1].displacement == handle_offset));
    }
    return receives_handle;
}

static int sa_same_open_shape(const SaQueueReadShape *left, const SaQueueReadShape *right) {
    return left->package_id_offset == right->package_id_offset &&
        left->type_hash_offset == right->type_hash_offset &&
        left->name_hash_offset == right->name_hash_offset &&
        left->size_offset == right->size_offset &&
        left->handle_offset == right->handle_offset &&
        left->io_loader_offset == right->io_loader_offset &&
        left->io_open_slot == right->io_open_slot &&
        left->io_size_slot == right->io_size_slot;
}

static int sa_analyze_open_sequence(
    const SaQueueReadAnalysis *analysis,
    const SaMethodCall *calls,
    size_t call_count,
    SaQueueReadShape *shape
) {
    size_t match_count = 0;
    size_t open_index;

    for (open_index = 0; open_index < call_count; ++open_index) {
        const SaMethodCall *open = &calls[open_index];
        SaQueueReadShape candidate = {0};
        size_t size_index;

        if (!open->has_result ||
            !sa_find_request_register_argument(
                analysis, open->call_offset, SA_REGISTER_R8, &candidate.type_hash_offset) ||
            !sa_find_request_register_argument(
                analysis, open->call_offset, SA_REGISTER_R9, &candidate.name_hash_offset) ||
            !sa_find_package_argument(
                analysis, open->call_offset, &candidate.package_id_offset)) {
            continue;
        }
        for (size_index = open_index + 1; size_index < call_count; ++size_index) {
            const SaMethodCall *size = &calls[size_index];
            SaQueueReadShape complete = candidate;

            if (!size->has_result || size->object_offset != open->object_offset ||
                size->slot == open->slot ||
                !sa_call_receives_open_handle(
                    analysis, size->call_offset, open->result_offset)) {
                continue;
            }
            complete.handle_offset = open->result_offset;
            complete.size_offset = size->result_offset;
            complete.io_loader_offset = open->object_offset;
            complete.io_open_slot = open->slot;
            complete.io_size_slot = size->slot;
            if (match_count == 0) {
                *shape = complete;
                match_count = 1;
            } else if (!sa_same_open_shape(shape, &complete)) {
                return 0;
            }
            break;
        }
    }
    return match_count == 1;
}

static int sa_find_stack_output_argument(
    const SaFunction *function,
    size_t call_offset,
    DtIntUtilsOperand *output
) {
    const uint8_t *call = function->start + call_offset;
    const uint8_t *cursor = sa_after_last_call(function->start, call);
    DtIntUtilsInstruction instruction;
    int found = 0;

    while (sa_next_instruction(&cursor, call, &instruction)) {
        if (!dtintutils_instruction_writes_register(&instruction, SA_REGISTER_RDX)) {
            continue;
        }
        found = instruction.mnemonic == DTINTUTILS_MNEMONIC_LEA &&
            instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].register_id == SA_REGISTER_RDX &&
            instruction.operands[0].size_bits == 64 &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
            (instruction.operands[1].memory_base == SA_REGISTER_RSP ||
             instruction.operands[1].memory_base == SA_REGISTER_RBP) &&
            instruction.operands[1].memory_index == DTINTUTILS_REGISTER_NONE;
        if (found) {
            *output = instruction.operands[1];
        }
    }
    return found;
}

static int sa_call_has_alignment_argument(const SaFunction *function, size_t call_offset) {
    const uint8_t *call = function->start + call_offset;
    const uint8_t *cursor = sa_after_last_call(function->start, call);
    DtIntUtilsInstruction instruction;
    int found = 0;

    while (sa_next_instruction(&cursor, call, &instruction)) {
        if (!dtintutils_instruction_writes_register(&instruction, SA_REGISTER_R9)) {
            continue;
        }
        found = instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
            instruction.operand_count == 2 &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            instruction.operands[1].immediate == sizeof(void *);
    }
    return found;
}

static int sa_find_allocation_result(
    const SaQueueReadAnalysis *analysis,
    size_t call_offset,
    const DtIntUtilsOperand *output,
    uint32_t *data_offset
) {
    const SaFunction *function = analysis->function;
    const uint8_t *call = function->start + call_offset;
    const uint8_t *function_limit = function->start + function->size;
    const uint8_t *cursor;
    const uint8_t *limit;
    DtIntUtilsInstruction instruction;
    int result_register = -1;

    if (!dtintutils_decode(call, (size_t)(function_limit - call), &instruction) ||
        instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL) {
        return 0;
    }
    cursor = call + instruction.length;
    limit = sa_before_next_call(cursor, function_limit);
    while (sa_next_instruction(&cursor, limit, &instruction)) {
        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV && instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].size_bits == 64 &&
            instruction.operands[1].size_bits == 64 &&
            sa_same_memory_operand(&instruction.operands[1], output)) {
            result_register = instruction.operands[0].register_id;
            continue;
        }
        if (result_register >= 0 &&
            dtintutils_instruction_writes_register(&instruction, result_register)) {
            result_register = -1;
        }
        if (result_register >= 0 && instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
            instruction.operand_count == 2 &&
            sa_is_request_operand(analysis, &instruction.operands[0], 64) &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[1].register_id == result_register) {
            *data_offset = (uint32_t)instruction.operands[0].displacement;
            return 1;
        }
    }
    return 0;
}

static int sa_analyze_worker_allocate(
    const SaQueueReadAnalysis *analysis,
    SaQueueReadShape *shape
) {
    const SaFunction *function = analysis->function;
    const uint8_t *cursor = function->start;
    const uint8_t *limit = function->start + function->size;
    DtIntUtilsInstruction vtable_load;
    size_t matches = 0;

    while (sa_next_instruction(&cursor, limit, &vtable_load)) {
        size_t call_offset;
        uint32_t slot;
        uint32_t size_offset;
        uint32_t data_offset;
        DtIntUtilsOperand output;

        if (vtable_load.mnemonic != DTINTUTILS_MNEMONIC_MOV ||
            vtable_load.operand_count != 2 ||
            vtable_load.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
            vtable_load.operands[0].size_bits != 64 ||
            vtable_load.operands[1].type != DTINTUTILS_OPERAND_MEMORY ||
            vtable_load.operands[1].size_bits != 64 ||
            vtable_load.operands[1].memory_index != DTINTUTILS_REGISTER_NONE ||
            vtable_load.operands[1].displacement != 0 ||
            !sa_register_in_set(
                vtable_load.operands[1].memory_base,
                analysis->worker_registers,
                analysis->worker_count) ||
            !sa_find_method_call(
                function, (size_t)(cursor - function->start),
                vtable_load.operands[0].register_id, &call_offset, &slot) ||
            !sa_find_request_register_argument(
                analysis, call_offset, SA_REGISTER_R8, &size_offset) ||
            size_offset != shape->size_offset ||
            !sa_call_has_alignment_argument(function, call_offset) ||
            !sa_find_stack_output_argument(function, call_offset, &output) ||
            !sa_find_allocation_result(analysis, call_offset, &output, &data_offset)) {
            continue;
        }
        if (matches != 0 &&
            (shape->worker_allocate_slot != slot || shape->data_offset != data_offset)) {
            return 0;
        }
        shape->worker_allocate_slot = slot;
        shape->data_offset = data_offset;
        ++matches;
    }
    return matches == 1;
}

int sa_validate_queue_read_shape(
    const SaFunction *queue_read,
    uint32_t request_size,
    SaQueueReadShape *shape,
    char *error,
    size_t error_size
) {
    SaQueueReadAnalysis analysis = {0};
    SaMethodCall *io_calls = NULL;
    size_t io_call_count = 0;
    SaQueueReadShape analyzed = {0};

    if (queue_read == NULL || request_size == 0 || shape == NULL) {
        sa_set_error(error, error_size, "queue_read shape analysis received an invalid argument");
        return 0;
    }
    analysis.function = queue_read;
    analysis.request_size = request_size;
    analysis.worker_count = sa_collect_entry_registers(
        queue_read, SA_REGISTER_RCX,
        analysis.worker_registers, SA_ARRAY_COUNT(analysis.worker_registers));
    analysis.request_count = sa_collect_entry_registers(
        queue_read, SA_REGISTER_RDX,
        analysis.request_registers, SA_ARRAY_COUNT(analysis.request_registers));
    if (analysis.worker_count == 0 ||
        analysis.worker_count > SA_ARRAY_COUNT(analysis.worker_registers) ||
        analysis.request_count == 0 ||
        analysis.request_count > SA_ARRAY_COUNT(analysis.request_registers)) {
        sa_set_error(error, error_size, "queue_read has no bounded worker and request data flow");
        return 0;
    }

    if (!sa_collect_io_method_calls(&analysis, &io_calls, &io_call_count) ||
        io_call_count == 0 ||
        !sa_analyze_open_sequence(&analysis, io_calls, io_call_count, &analyzed) ||
        !sa_analyze_worker_allocate(&analysis, &analyzed)) {
        if (io_calls != NULL) {
            HeapFree(GetProcessHeap(), 0, io_calls);
        }
        sa_set_error(error, error_size,
                     "queue_read external-read data flow could not be derived uniquely");
        return 0;
    }

    HeapFree(GetProcessHeap(), 0, io_calls);
    *shape = analyzed;
    return 1;
}