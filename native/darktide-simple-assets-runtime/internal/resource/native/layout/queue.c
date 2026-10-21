#include "internal.h"

#include <limits.h>

#define SA_X64_SIXTH_ARGUMENT_STACK_OFFSET 0x28

typedef struct {
    uint32_t request_size;
} SaRequestStrideContext;

static int sa_derive_request_size(
    const SaImage *image,
    const uint8_t *address,
    void *context
) {
    SaRequestStrideContext *stride_context = (SaRequestStrideContext *)context;
    SaFunction function;
    uint32_t request_size = 0;
    size_t offset = 0;

    if (stride_context == NULL ||
        !dtintutils_function_containing(image, address, &function)) {
        return 0;
    }
    while (offset < function.size) {
        DtIntUtilsInstruction instruction;
        uint64_t immediate;

        if (!dtintutils_decode(
                function.start + offset, function.size - offset, &instruction)) {
            ++offset;
            continue;
        }
        offset += instruction.length;
        if (instruction.mnemonic != DTINTUTILS_MNEMONIC_IMUL ||
            instruction.operand_count != 3 ||
            instruction.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
            instruction.operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
            instruction.operands[0].size_bits != instruction.operands[1].size_bits ||
            instruction.operands[2].type != DTINTUTILS_OPERAND_IMMEDIATE) {
            continue;
        }
        immediate = instruction.operands[2].immediate;
        if (immediate == 0 || immediate > UINT32_MAX) {
            continue;
        }
        if (request_size != 0 && request_size != (uint32_t)immediate) {
            return 0;
        }
        request_size = (uint32_t)immediate;
    }
    if (request_size == 0) {
        return 0;
    }
    stride_context->request_size = request_size;
    return 1;
}

int sa_locate_queue_push(
    const SaImage *image,
    const SaFunction *queue_request,
    const SaFunction *input_transfer,
    const uint8_t **queue_push,
    uint32_t *request_size,
    char *error,
    size_t error_size
) {
    SaRequestStrideContext context = {0};

    if (image == NULL || queue_request == NULL || input_transfer == NULL ||
        queue_push == NULL || request_size == NULL) {
        sa_set_error(error, error_size, "queue-push locator received a null argument");
        return 0;
    }
    const DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_ADDRESS(queue_request->start, 1, 1),
        DTINTUTILS_LOCATE_COLLECT_FUNCTION_CALL_TARGETS(1, 0),
        DTINTUTILS_LOCATE_FILTER_CALL_TARGETS_OF(input_transfer->start, 1, 0),
    };
    const DtIntUtilsLocator locator = {
        "ResourceLoader queue push",
        steps,
        SA_ARRAY_COUNT(steps),
    };
    if (!dtintutils_locate_unique_address_with_validator(
            image, &locator, sa_derive_request_size, &context,
            queue_push, error, error_size)) {
        return 0;
    }
    *request_size = context.request_size;
    return 1;
}

int sa_analyze_input_queue_offset(
    const SaFunction *queue_request,
    const uint8_t *queue_push,
    uint32_t *input_queue_offset,
    char *error,
    size_t error_size
) {
    int worker_registers[SA_X64_REGISTER_COUNT];
    size_t worker_count;
    const uint8_t *cursor;
    const uint8_t *limit;
    DtIntUtilsInstruction instruction;
    size_t matches = 0;

    if (queue_request == NULL || queue_push == NULL || input_queue_offset == NULL) {
        sa_set_error(error, error_size, "input-queue analysis received a null argument");
        return 0;
    }
    worker_count = sa_collect_entry_registers(
        queue_request, SA_REGISTER_RCX, worker_registers, SA_ARRAY_COUNT(worker_registers));
    if (worker_count == 0 || worker_count > SA_ARRAY_COUNT(worker_registers)) {
        sa_set_error(error, error_size, "queue_request has no bounded worker-register set");
        return 0;
    }
    cursor = queue_request->start;
    limit = queue_request->start + queue_request->size;
    while (sa_next_instruction(&cursor, limit, &instruction)) {
        const uint8_t *argument_cursor;
        DtIntUtilsInstruction argument;

        if (instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL ||
            instruction.operand_count != 1 ||
            instruction.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
            !instruction.operands[0].has_absolute ||
            (const uint8_t *)(uintptr_t)instruction.operands[0].absolute != queue_push) {
            continue;
        }
        argument_cursor = sa_after_last_call(queue_request->start, instruction.address);
        while (sa_next_instruction(&argument_cursor, instruction.address, &argument)) {
            SaMemoryOperand operand;
            int destination;

            if (!sa_parse_reg_memory_instruction(
                    &argument, DTINTUTILS_MNEMONIC_LEA, 1,
                    &destination, &operand) ||
                destination != SA_REGISTER_RCX || operand.displacement < 0 ||
                !sa_register_in_set(
                    operand.base_register, worker_registers, worker_count)) {
                continue;
            }
            *input_queue_offset = (uint32_t)operand.displacement;
            ++matches;
        }
    }
    if (matches != 1) {
        sa_set_error(error, error_size,
                     "queue_request input-queue analysis produced %zu candidates; expected 1",
                     matches);
        return 0;
    }
    return 1;
}

typedef struct {
    uint32_t displacement;
    uint16_t size_bits;
} SaRequestWrite;

static int sa_is_request_memory_operand(
    const DtIntUtilsOperand *operand,
    const int *request_registers,
    size_t request_count,
    uint32_t request_size
) {
    return operand->type == DTINTUTILS_OPERAND_MEMORY &&
        operand->memory_index == DTINTUTILS_REGISTER_NONE &&
        sa_register_in_set(operand->memory_base, request_registers, request_count) &&
        operand->displacement >= 0 && (uint64_t)operand->displacement < request_size;
}

static int sa_has_request_write(
    const SaRequestWrite *writes,
    size_t write_count,
    uint32_t displacement,
    uint16_t size_bits
) {
    size_t index;

    for (index = 0; index < write_count; ++index) {
        if (writes[index].displacement == displacement && writes[index].size_bits == size_bits) {
            return 1;
        }
    }
    return 0;
}

static int sa_append_request_write(
    SaRequestWrite **writes,
    size_t *write_count,
    size_t *write_capacity,
    uint32_t displacement,
    uint16_t size_bits
) {
    SaRequestWrite *resized;
    size_t next_capacity;

    if (sa_has_request_write(*writes, *write_count, displacement, size_bits)) {
        return 1;
    }
    if (*write_count == *write_capacity) {
        next_capacity = *write_capacity == 0 ? 16 : *write_capacity * 2;
        if (next_capacity < *write_capacity || next_capacity > SIZE_MAX / sizeof(**writes)) {
            return 0;
        }
        resized = *writes == NULL
            ? (SaRequestWrite *)HeapAlloc(
                GetProcessHeap(), 0, next_capacity * sizeof(**writes))
            : (SaRequestWrite *)HeapReAlloc(
                GetProcessHeap(), 0, *writes, next_capacity * sizeof(**writes));
        if (resized == NULL) {
            return 0;
        }
        *writes = resized;
        *write_capacity = next_capacity;
    }

    (*writes)[*write_count].displacement = displacement;
    (*writes)[*write_count].size_bits = size_bits;
    ++*write_count;
    return 1;
}

static int sa_callback_passes_stream_location(
    const SaFunction *callback_process,
    uint32_t request_size,
    uint32_t flag_offset,
    uint32_t location_offset
) {
    int request_registers[SA_X64_REGISTER_COUNT];
    size_t request_count = sa_collect_entry_registers(
        callback_process, SA_REGISTER_RDX, request_registers, SA_ARRAY_COUNT(request_registers));
    const uint8_t *limit = callback_process->start + callback_process->size;
    size_t offset = 0;

    if (request_count == 0 || request_count > SA_ARRAY_COUNT(request_registers)) {
        return 0;
    }
    while (offset < callback_process->size) {
        const uint8_t *instruction_address = callback_process->start + offset;
        const uint8_t *argument_start;
        const uint8_t *cursor;
        DtIntUtilsInstruction instruction;
        size_t operand_index;
        int location_register;
        int saw_flag_read = 0;
        int saw_sixth_argument = 0;
        int saw_indirect_call = 0;

        if (!dtintutils_decode(
                instruction_address, (size_t)(limit - instruction_address), &instruction)) {
            ++offset;
            continue;
        }
        offset += instruction.length;
        if (instruction.mnemonic != DTINTUTILS_MNEMONIC_LEA ||
            instruction.operand_count != 2 ||
            instruction.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
            !sa_is_request_memory_operand(
                &instruction.operands[1], request_registers, request_count, request_size) ||
            instruction.operands[1].displacement != location_offset) {
            continue;
        }

        location_register = instruction.operands[0].register_id;
        argument_start = sa_after_last_call(callback_process->start, instruction_address);
        cursor = argument_start;
        while (cursor < instruction_address) {
            DtIntUtilsInstruction before;

            if (!dtintutils_decode(
                    cursor, (size_t)(instruction_address - cursor), &before)) {
                ++cursor;
                continue;
            }
            cursor += before.length;
            for (operand_index = 0; operand_index < before.operand_count; ++operand_index) {
                if (before.operands[operand_index].size_bits == 8 &&
                    sa_is_request_memory_operand(
                        &before.operands[operand_index], request_registers,
                        request_count, request_size) &&
                    before.operands[operand_index].displacement == flag_offset &&
                    (dtintutils_instruction_operand_access(&before, operand_index) &
                     DTINTUTILS_OPERAND_ACCESS_READ) != 0) {
                    saw_flag_read = 1;
                    break;
                }
            }
        }

        cursor = instruction_address + instruction.length;
        while (cursor < limit) {
            DtIntUtilsInstruction after;

            if (!dtintutils_decode(cursor, (size_t)(limit - cursor), &after)) {
                ++cursor;
                continue;
            }
            cursor += after.length;
            if (after.mnemonic == DTINTUTILS_MNEMONIC_CALL) {
                saw_indirect_call = after.operand_count == 1 &&
                    after.operands[0].type == DTINTUTILS_OPERAND_REGISTER;
                break;
            }
            if (after.mnemonic == DTINTUTILS_MNEMONIC_MOV && after.operand_count == 2 &&
                after.operands[0].type == DTINTUTILS_OPERAND_MEMORY &&
                after.operands[0].memory_base == SA_REGISTER_RSP &&
                after.operands[0].memory_index == DTINTUTILS_REGISTER_NONE &&
                after.operands[0].displacement == SA_X64_SIXTH_ARGUMENT_STACK_OFFSET &&
                after.operands[0].size_bits == 64 &&
                (dtintutils_instruction_operand_access(&after, 0) &
                 DTINTUTILS_OPERAND_ACCESS_WRITE) != 0 &&
                after.operands[1].type == DTINTUTILS_OPERAND_REGISTER &&
                after.operands[1].register_id == location_register) {
                saw_sixth_argument = 1;
            }
        }
        if (saw_flag_read && saw_sixth_argument && saw_indirect_call) {
            return 1;
        }
    }
    return 0;
}

int sa_analyze_stream_location_shape(
    const SaFunction *queue_request,
    const SaFunction *callback_process,
    uint32_t request_size,
    SaStreamRequestShape *shape,
    char *error,
    size_t error_size
) {
    int request_registers[SA_X64_REGISTER_COUNT];
    size_t request_count;
    SaRequestWrite *writes = NULL;
    size_t write_count = 0;
    size_t write_capacity = 0;
    size_t offset = 0;
    size_t candidate_index;
    size_t match_count = 0;
    uint32_t matched_location = 0;
    uint32_t matched_flag = 0;
    uint32_t matched_path_size = 0;
    uint32_t matched_location_size = 0;

    if (queue_request == NULL || callback_process == NULL || shape == NULL) {
        sa_set_error(error, error_size, "stream-location analysis received a null argument");
        return 0;
    }
    request_count = sa_collect_entry_registers(
        queue_request, SA_REGISTER_RDX, request_registers, SA_ARRAY_COUNT(request_registers));
    if (request_count == 0 || request_count > SA_ARRAY_COUNT(request_registers)) {
        sa_set_error(error, error_size, "queue_request has no valid request-register set or stride");
        return 0;
    }
    while (offset < queue_request->size) {
        DtIntUtilsInstruction instruction;
        const DtIntUtilsOperand *destination;

        if (!dtintutils_decode(
                queue_request->start + offset, queue_request->size - offset, &instruction)) {
            ++offset;
            continue;
        }
        offset += instruction.length;
        if (instruction.operand_count < 2) {
            continue;
        }
        destination = &instruction.operands[0];
        if (!sa_is_request_memory_operand(
                destination, request_registers, request_count, request_size) ||
            (dtintutils_instruction_operand_access(&instruction, 0) &
             DTINTUTILS_OPERAND_ACCESS_WRITE) == 0 ||
            (destination->size_bits != 8 && destination->size_bits != 64 &&
             destination->size_bits != 128)) {
            continue;
        }
        if (!sa_append_request_write(
                &writes, &write_count, &write_capacity,
                (uint32_t)destination->displacement, destination->size_bits)) {
            if (writes != NULL) {
                HeapFree(GetProcessHeap(), 0, writes);
            }
            sa_set_error(error, error_size,
                         "queue_request stream-location write set could not be allocated");
            return 0;
        }
    }

    for (candidate_index = 0; candidate_index < write_count; ++candidate_index) {
        const SaRequestWrite *first = &writes[candidate_index];
        uint32_t location = first->displacement;
        size_t first_size;
        size_t second_index;

        if (first->size_bits == 0 || first->size_bits % CHAR_BIT != 0) {
            continue;
        }
        first_size = first->size_bits / CHAR_BIT;
        for (second_index = 0; second_index < write_count; ++second_index) {
            const SaRequestWrite *second = &writes[second_index];
            uint64_t second_location = (uint64_t)location + first_size;
            size_t second_size;
            uint64_t path_size;
            uint64_t range_offset;
            uint64_t location_size;
            size_t flag_index;

            if (second_location > UINT32_MAX || second->displacement != second_location ||
                second->size_bits == 0 || second->size_bits % CHAR_BIT != 0) {
                continue;
            }
            second_size = second->size_bits / CHAR_BIT;
            path_size = first_size + second_size;
            range_offset = (uint64_t)location + path_size;
            location_size = path_size + sizeof(uint64_t);
            if (path_size < SA_STREAM_IDENTITY_SIZE || path_size > UINT32_MAX ||
                range_offset > UINT32_MAX || location_size > UINT32_MAX ||
                (uint64_t)location + location_size > request_size ||
                !sa_has_request_write(
                    writes, write_count, (uint32_t)range_offset, 64)) {
                continue;
            }

            for (flag_index = 0; flag_index < write_count; ++flag_index) {
                uint32_t flag = writes[flag_index].displacement;

                if (writes[flag_index].size_bits != 8) {
                    continue;
                }
                if (sa_callback_passes_stream_location(
                        callback_process, request_size, flag, location)) {
                    matched_location = location;
                    matched_flag = flag;
                    matched_path_size = (uint32_t)path_size;
                    matched_location_size = (uint32_t)location_size;
                    ++match_count;
                }
            }
        }
    }
    if (writes != NULL) {
        HeapFree(GetProcessHeap(), 0, writes);
    }
    if (match_count != 1) {
        sa_set_error(error, error_size,
                     "resource stream-location analysis produced %zu candidates; expected 1", match_count);
        return 0;
    }

    shape->flag_offset = matched_flag;
    shape->location_offset = matched_location;
    shape->path_size = matched_path_size;
    shape->range_offset = matched_location + matched_path_size;
    shape->location_size = matched_location_size;
    return 1;
}
