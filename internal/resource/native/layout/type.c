#include "internal.h"

static int sa_find_direct_call(
    const uint8_t *start,
    const uint8_t *limit,
    DtIntUtilsInstruction *call,
    const uint8_t **target
) {
    const uint8_t *cursor = start;

    while (sa_next_instruction(&cursor, limit, call)) {
        if (call->mnemonic != DTINTUTILS_MNEMONIC_CALL) {
            continue;
        }
        if (call->operand_count == 1 &&
            call->operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            call->operands[0].has_absolute) {
            *target = (const uint8_t *)(uintptr_t)call->operands[0].absolute;
            return 1;
        }
        return 0;
    }
    return 0;
}

static int sa_derive_type_layout(
    const SaImage *image,
    const SaFunction *function,
    const uint8_t *candidate_helper,
    SaTypeLayout *layout
) {
    int manager_registers[SA_X64_REGISTER_COUNT];
    size_t manager_count = sa_collect_entry_registers(
        function, SA_REGISTER_RCX, manager_registers, SA_ARRAY_COUNT(manager_registers));
    const uint8_t *function_limit = function->start + function->size;
    SaTypeLayout matched = {0};
    size_t match_count = 0;
    size_t manager_index;

    if (manager_count == 0 || manager_count > SA_ARRAY_COUNT(manager_registers)) {
        return 0;
    }

    for (manager_index = 0; manager_index < manager_count; ++manager_index) {
        int manager_register = manager_registers[manager_index];
        const uint8_t *cursor = function->start;
        DtIntUtilsInstruction instruction;

        while (sa_next_instruction(&cursor, function_limit, &instruction)) {
            SaMemoryOperand type_operand;
            int destination;
            DtIntUtilsInstruction lookup_call;
            const uint8_t *lookup_target;
            const uint8_t *flow_cursor;
            const uint8_t *flow_limit;
            DtIntUtilsInstruction flow;
            int count_register = -1;
            int32_t count_displacement = 0;
            int product_register = -1;
            uint32_t record_size = 0;
            int32_t data_displacement = -1;

            if (!sa_parse_reg_memory_instruction(
                    &instruction, DTINTUTILS_MNEMONIC_LEA, 1,
                    &destination, &type_operand) ||
                destination != SA_REGISTER_RCX ||
                type_operand.base_register != manager_register ||
                type_operand.displacement < 0 ||
                !sa_find_direct_call(cursor, function_limit, &lookup_call, &lookup_target) ||
                lookup_target != candidate_helper ||
                !dtintutils_is_executable_address(image, lookup_target)) {
                continue;
            }

            flow_cursor = lookup_call.address + lookup_call.length;
            flow_limit = sa_before_next_call(flow_cursor, function_limit);
            while (sa_next_instruction(&flow_cursor, flow_limit, &flow)) {
                SaMemoryOperand operand;
                int register_value;

                if (count_register < 0 &&
                    sa_parse_reg_memory_instruction(
                        &flow, DTINTUTILS_MNEMONIC_MOV, 0, &register_value, &operand) &&
                    operand.base_register == manager_register && operand.displacement >= 0) {
                    count_register = register_value;
                    count_displacement = operand.displacement;
                    continue;
                }
                if (count_register >= 0 && product_register < 0 &&
                    flow.mnemonic == DTINTUTILS_MNEMONIC_IMUL && flow.operand_count == 3 &&
                    flow.operands[0].type == DTINTUTILS_OPERAND_REGISTER &&
                    flow.operands[0].size_bits == 64 &&
                    flow.operands[1].type == DTINTUTILS_OPERAND_REGISTER &&
                    flow.operands[1].register_id == count_register &&
                    flow.operands[2].type == DTINTUTILS_OPERAND_IMMEDIATE &&
                    flow.operands[2].immediate > 0 && flow.operands[2].immediate <= UINT32_MAX) {
                    product_register = flow.operands[0].register_id;
                    record_size = (uint32_t)flow.operands[2].immediate;
                    continue;
                }
                if (product_register >= 0 &&
                    sa_parse_reg_memory_instruction(
                        &flow, DTINTUTILS_MNEMONIC_ADD, 1, &register_value, &operand) &&
                    register_value == product_register &&
                    operand.base_register == manager_register && operand.displacement >= 0) {
                    data_displacement = operand.displacement;
                    break;
                }
            }

            if (count_register < 0 || product_register < 0 || data_displacement < 0) {
                continue;
            }

            matched.type_count_offset = (uint32_t)count_displacement;
            matched.type_data_offset = (uint32_t)data_displacement;
            matched.record_size = record_size;
            ++match_count;
        }
    }

    if (match_count != 1) {
        return 0;
    }
    *layout = matched;
    return 1;
}

typedef struct {
    const SaFunction *function;
    SaTypeLayout layout;
} SaTypeLayoutContext;

static int sa_validate_type_layout(
    const SaImage *image,
    const uint8_t *candidate,
    void *context
) {
    SaTypeLayoutContext *type_context = (SaTypeLayoutContext *)context;

    return sa_derive_type_layout(
        image, type_context->function, candidate, &type_context->layout);
}

int sa_analyze_type_layout(
    const SaImage *image,
    const SaFunction *function,
    SaTypeLayout *layout,
    const uint8_t **lookup_helper,
    char *error,
    size_t error_size
) {
    SaTypeLayoutContext context;
    const uint8_t *helper;

    if (image == NULL || function == NULL || layout == NULL || lookup_helper == NULL) {
        sa_set_error(error, error_size, "type-layout locator received a null argument");
        return 0;
    }
    const DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_ADDRESS(function->start, 1, 1),
        DTINTUTILS_LOCATE_COLLECT_FUNCTION_CALL_TARGETS(1, 0),
    };
    const DtIntUtilsLocator locator = {
        "ResourceManager type lookup",
        steps,
        SA_ARRAY_COUNT(steps),
    };
    context.function = function;

    if (!dtintutils_locate_unique_address_with_validator(
            image, &locator, sa_validate_type_layout, &context,
            &helper, error, error_size)) {
        return 0;
    }
    *layout = context.layout;
    *lookup_helper = helper;
    return 1;
}