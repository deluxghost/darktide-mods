#include "internal.h"

#include <limits.h>

static int sa_move_file_mode(
    const DtIntUtilsInstruction *instruction,
    uint32_t *mode
) {
    if (instruction->mnemonic != DTINTUTILS_MNEMONIC_MOV ||
        instruction->operand_count != 2 ||
        instruction->operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
        instruction->operands[0].register_id != SA_REGISTER_RDX ||
        instruction->operands[1].type != DTINTUTILS_OPERAND_IMMEDIATE ||
        instruction->operands[1].immediate > UINT8_MAX) {
        return 0;
    }
    *mode = (uint32_t)instruction->operands[1].immediate;
    return 1;
}

static int sa_stack_frame_delta(const SaFunction *function, int32_t *rbp_from_rsp) {
    const uint8_t *cursor = function->start;
    const uint8_t *limit = function->start + function->size;
    DtIntUtilsInstruction instruction;
    int found_lea = 0;
    int32_t lea_displacement = 0;
    uint64_t total_sub = 0;
    uint64_t sub_before_lea = 0;
    int64_t delta;

    while (sa_next_instruction(&cursor, limit, &instruction)) {
        SaMemoryOperand operand;
        int destination;

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL) {
            break;
        }
        if (sa_parse_reg_memory_instruction(
                &instruction, DTINTUTILS_MNEMONIC_LEA, 1, &destination, &operand) &&
            destination == SA_REGISTER_RBP && operand.base_register == SA_REGISTER_RSP) {
            if (found_lea) {
                return 0;
            }
            found_lea = 1;
            lea_displacement = operand.displacement;
            sub_before_lea = total_sub;
            continue;
        }
        if (instruction.mnemonic != DTINTUTILS_MNEMONIC_SUB ||
            instruction.operand_count != 2 ||
            instruction.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
            instruction.operands[0].register_id != SA_REGISTER_RSP ||
            instruction.operands[0].size_bits != 64) {
            continue;
        }
        if (instruction.operands[1].type != DTINTUTILS_OPERAND_IMMEDIATE ||
            instruction.operands[1].immediate == 0 ||
            instruction.operands[1].immediate > INT32_MAX ||
            (instruction.operands[1].immediate_is_signed &&
             (int64_t)instruction.operands[1].immediate <= 0) ||
            total_sub > INT32_MAX - instruction.operands[1].immediate) {
            return 0;
        }
        total_sub += instruction.operands[1].immediate;
    }

    if (!found_lea || total_sub < sub_before_lea) {
        return 0;
    }
    delta = (int64_t)lea_displacement + (int64_t)(total_sub - sub_before_lea);
    if (delta < INT32_MIN || delta > INT32_MAX) {
        return 0;
    }
    *rbp_from_rsp = (int32_t)delta;
    return 1;
}

static int sa_stack_offset(
    int base_register,
    int64_t displacement,
    int32_t rbp_from_rsp,
    int32_t *offset
) {
    int64_t value;

    if (base_register == SA_REGISTER_RSP) {
        value = displacement;
    } else if (base_register == SA_REGISTER_RBP) {
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
    const uint8_t *cursor = sa_after_last_call(function_start, call_address);
    uint32_t manager_offsets[SA_X64_REGISTER_COUNT] = {0};
    int has_manager_offset[SA_X64_REGISTER_COUNT] = {0};
    DtIntUtilsInstruction instruction;
    size_t matches = 0;

    while (sa_next_instruction(&cursor, call_address, &instruction)) {
        int propagated_register = -1;
        uint32_t propagated_offset = 0;
        int base_register = -1;
        int64_t adjustment = -1;
        int register_id;

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_MOV &&
            instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].register_id >= 0 &&
            instruction.operands[0].register_id < SA_X64_REGISTER_COUNT) {
            const DtIntUtilsOperand *source = &instruction.operands[1];

            propagated_register = instruction.operands[0].register_id;
            if (source->type == DTINTUTILS_OPERAND_MEMORY &&
                source->size_bits == 64 &&
                source->memory_base == manager_register &&
                source->memory_index == DTINTUTILS_REGISTER_NONE &&
                source->displacement >= 0 && source->displacement <= UINT32_MAX) {
                propagated_offset = (uint32_t)source->displacement;
            } else if (source->type == DTINTUTILS_OPERAND_REGISTER &&
                       source->size_bits == 64 &&
                       source->register_id >= 0 &&
                       source->register_id < SA_X64_REGISTER_COUNT &&
                       has_manager_offset[source->register_id]) {
                propagated_offset = manager_offsets[source->register_id];
            } else {
                propagated_register = -1;
            }
        }

        if (instruction.mnemonic == DTINTUTILS_MNEMONIC_ADD &&
            instruction.operand_count == 2 &&
            instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
            instruction.operands[0].register_id == SA_REGISTER_R8 &&
            instruction.operands[0].size_bits == 64 &&
            instruction.operands[1].type == DTINTUTILS_OPERAND_IMMEDIATE) {
            base_register = SA_REGISTER_R8;
            if (instruction.operands[1].immediate <= INT64_MAX) {
                adjustment = (int64_t)instruction.operands[1].immediate;
            }
        } else if (instruction.mnemonic == DTINTUTILS_MNEMONIC_LEA &&
                   instruction.operand_count == 2 &&
                   instruction.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
                   instruction.operands[0].register_id == SA_REGISTER_R8 &&
                   instruction.operands[0].size_bits == 64 &&
                   instruction.operands[1].type == DTINTUTILS_OPERAND_MEMORY &&
                   instruction.operands[1].memory_index == DTINTUTILS_REGISTER_NONE) {
            base_register = instruction.operands[1].memory_base;
            adjustment = instruction.operands[1].displacement;
        }

        if (base_register >= 0 && base_register < SA_X64_REGISTER_COUNT &&
            has_manager_offset[base_register] && adjustment >= 0 && adjustment <= UINT32_MAX) {
            *manager_offset = manager_offsets[base_register];
            *subobject_offset = (uint32_t)adjustment;
            ++matches;
        }

        for (register_id = 0; register_id < SA_X64_REGISTER_COUNT; ++register_id) {
            if (has_manager_offset[register_id] &&
                dtintutils_instruction_writes_register(&instruction, register_id)) {
                has_manager_offset[register_id] = 0;
            }
        }
        if (propagated_register >= 0) {
            has_manager_offset[propagated_register] = 1;
            manager_offsets[propagated_register] = propagated_offset;
        }
    }
    return matches == 1;
}

static int sa_same_open_stream_shape(
    const SaOpenStreamShape *left,
    const SaOpenStreamShape *right
) {
    return left->helper == right->helper &&
        left->file_system_slot == right->file_system_slot &&
        left->loader_offset == right->loader_offset &&
        left->loader_subobject_offset == right->loader_subobject_offset &&
        left->file_open_mode == right->file_open_mode &&
        left->path_size == right->path_size &&
        left->range_offset == right->range_offset &&
        left->handle_offset == right->handle_offset;
}

static int sa_derive_open_stream(
    const SaImage *image,
    const SaFunction *function,
    const uint8_t *candidate_helper,
    SaOpenStreamShape *shape
) {
    int manager_registers[SA_X64_REGISTER_COUNT];
    size_t manager_count = sa_collect_entry_registers(
        function, SA_REGISTER_RCX, manager_registers, SA_ARRAY_COUNT(manager_registers));
    const uint8_t *cursor = function->start;
    const uint8_t *function_limit = function->start + function->size;
    const uint8_t *range_search_start = function->start;
    DtIntUtilsInstruction call_instruction;
    int32_t rbp_from_rsp;
    SaOpenStreamShape matched = {0};
    size_t match_count = 0;

    if (manager_count == 0 || manager_count > SA_ARRAY_COUNT(manager_registers) ||
        !sa_stack_frame_delta(function, &rbp_from_rsp)) {
        return 0;
    }

    while (sa_next_instruction(&cursor, function_limit, &call_instruction)) {
        const uint8_t *helper;
        const uint8_t *argument_cursor;
        const uint8_t *range_cursor;
        DtIntUtilsInstruction argument;
        const uint8_t *file_system_target = NULL;
        uint32_t file_open_mode = 0;
        int saw_mode = 0;
        int32_t stream_base = 0;
        int saw_stream_base = 0;
        int32_t range_location = 0;
        int saw_range = 0;
        int32_t handle_location = 0;
        int saw_handle = 0;
        int64_t range_offset;
        int64_t handle_offset;
        size_t manager_index;
        uint32_t loader_offset = 0;
        uint32_t loader_subobject_offset = 0;
        size_t loader_matches = 0;

        if (call_instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL ||
            call_instruction.operand_count != 1 ||
            call_instruction.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
            !call_instruction.operands[0].has_absolute) {
            continue;
        }
        helper = (const uint8_t *)(uintptr_t)call_instruction.operands[0].absolute;
        if (helper != candidate_helper || !dtintutils_is_executable_address(image, helper)) {
            continue;
        }

        range_cursor = range_search_start;
        range_search_start = call_instruction.address + call_instruction.length;
        argument_cursor = sa_after_last_call(function->start, call_instruction.address);
        while (sa_next_instruction(
                &argument_cursor, call_instruction.address, &argument)) {
            const uint8_t *target;
            SaMemoryOperand operand;
            int destination;
            int32_t stack_value;

            if (dtintutils_instruction_writes_register(&argument, SA_REGISTER_RDX)) {
                saw_mode = sa_move_file_mode(&argument, &file_open_mode);
            }
            if (sa_parse_rip_relative(
                    &argument, DTINTUTILS_MNEMONIC_MOV, 0, SA_REGISTER_RCX,
                    &target, NULL) && dtintutils_is_writable_address(image, target)) {
                file_system_target = target;
            } else if (dtintutils_instruction_writes_register(&argument, SA_REGISTER_RCX)) {
                file_system_target = NULL;
            }
            if (sa_parse_reg_memory_instruction(
                    &argument, DTINTUTILS_MNEMONIC_LEA, 1,
                    &destination, &operand) && destination == SA_REGISTER_R9 &&
                sa_stack_offset(
                    operand.base_register, operand.displacement,
                    rbp_from_rsp, &stack_value)) {
                stream_base = stack_value;
                saw_stream_base = 1;
            } else if (dtintutils_instruction_writes_register(&argument, SA_REGISTER_R9)) {
                saw_stream_base = 0;
            }
        }

        while (sa_next_instruction(&range_cursor, call_instruction.address, &argument)) {
            int32_t stack_value;

            if (argument.mnemonic != DTINTUTILS_MNEMONIC_MOV ||
                argument.operand_count != 2 ||
                argument.operands[0].type != DTINTUTILS_OPERAND_MEMORY ||
                argument.operands[0].memory_index != DTINTUTILS_REGISTER_NONE ||
                argument.operands[1].type != DTINTUTILS_OPERAND_IMMEDIATE ||
                (argument.operands[1].immediate != UINT32_MAX &&
                 argument.operands[1].immediate != UINT64_MAX) ||
                !sa_stack_offset(
                    argument.operands[0].memory_base,
                    argument.operands[0].displacement,
                    rbp_from_rsp, &stack_value) ||
                !saw_stream_base || stack_value <= stream_base) {
                continue;
            }
            range_location = stack_value;
            saw_range = 1;
        }

        {
            const uint8_t *result_cursor = call_instruction.address + call_instruction.length;
            const uint8_t *result_limit = sa_before_next_call(result_cursor, function_limit);
            DtIntUtilsInstruction result;

            while (sa_next_instruction(&result_cursor, result_limit, &result)) {
                int32_t stack_value;

                if (result.mnemonic != DTINTUTILS_MNEMONIC_MOV || result.operand_count != 2 ||
                    result.operands[0].type != DTINTUTILS_OPERAND_MEMORY ||
                    result.operands[0].memory_index != DTINTUTILS_REGISTER_NONE ||
                    result.operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
                    result.operands[1].register_id != SA_REGISTER_RAX ||
                    !sa_stack_offset(
                        result.operands[0].memory_base, result.operands[0].displacement,
                        rbp_from_rsp, &stack_value)) {
                    continue;
                }
                if (saw_handle && handle_location != stack_value) {
                    saw_handle = 0;
                    break;
                }
                handle_location = stack_value;
                saw_handle = 1;
            }
        }

        range_offset = (int64_t)range_location - stream_base;
        handle_offset = (int64_t)handle_location - stream_base;
        if (!saw_mode || file_system_target == NULL || !saw_stream_base ||
            !saw_range || !saw_handle || range_offset <= 0 || handle_offset <= 0 ||
            range_offset > UINT32_MAX || handle_offset > UINT32_MAX) {
            continue;
        }

        for (manager_index = 0; manager_index < manager_count; ++manager_index) {
            uint32_t candidate_loader_offset;
            uint32_t candidate_subobject_offset;

            if (sa_find_loader_derivation(
                    function->start, call_instruction.address,
                    manager_registers[manager_index],
                    &candidate_loader_offset, &candidate_subobject_offset)) {
                loader_offset = candidate_loader_offset;
                loader_subobject_offset = candidate_subobject_offset;
                ++loader_matches;
            }
        }
        if (loader_matches != 1) {
            continue;
        }

        {
            SaOpenStreamShape candidate = {
                .helper = helper,
                .file_system_slot = (void **)file_system_target,
                .loader_offset = loader_offset,
                .loader_subobject_offset = loader_subobject_offset,
                .file_open_mode = file_open_mode,
                .path_size = (uint32_t)(range_offset < handle_offset ? range_offset : handle_offset),
                .range_offset = (uint32_t)range_offset,
                .handle_offset = (uint32_t)handle_offset,
            };

            if (match_count == 0) {
                matched = candidate;
            } else if (!sa_same_open_stream_shape(&matched, &candidate)) {
                return 0;
            }
        }
        ++match_count;
    }

    if (match_count == 0) {
        return 0;
    }
    *shape = matched;
    return 1;
}

typedef struct {
    const SaFunction *function;
    SaOpenStreamShape shape;
} SaOpenStreamContext;

static int sa_validate_open_stream_helper(
    const SaImage *image,
    const uint8_t *candidate,
    void *context
) {
    SaOpenStreamContext *stream_context = (SaOpenStreamContext *)context;

    return sa_derive_open_stream(
        image, stream_context->function, candidate, &stream_context->shape);
}

int sa_analyze_open_stream(
    const SaImage *image,
    const SaFunction *function,
    SaOpenStreamShape *shape,
    char *error,
    size_t error_size
) {
    SaOpenStreamContext context;
    const uint8_t *helper;

    if (image == NULL || function == NULL || shape == NULL) {
        sa_set_error(error, error_size, "open-stream locator received a null argument");
        return 0;
    }
    const DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_ADDRESS(function->start, 1, 1),
        DTINTUTILS_LOCATE_COLLECT_FUNCTION_CALL_TARGETS(1, 0),
    };
    const DtIntUtilsLocator locator = {
        "ResourceManager open-stream helper",
        steps,
        SA_ARRAY_COUNT(steps),
    };
    context.function = function;

    if (!dtintutils_locate_unique_address_with_validator(
            image, &locator, sa_validate_open_stream_helper, &context,
            &helper, error, error_size)) {
        return 0;
    }
    context.shape.helper = helper;
    *shape = context.shape;
    return 1;
}