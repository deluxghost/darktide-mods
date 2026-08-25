#include "internal.h"

#include <string.h>

static int sa_tested_register(
    const DtIntUtilsInstruction *instruction,
    int *register_value
) {
    if (instruction->mnemonic != DTINTUTILS_MNEMONIC_TEST ||
        instruction->operand_count != 2 ||
        instruction->operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
        instruction->operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
        instruction->operands[0].size_bits != 64 ||
        instruction->operands[0].register_id != instruction->operands[1].register_id) {
        return 0;
    }
    *register_value = instruction->operands[0].register_id;
    return 1;
}

typedef struct {
    const SaFunction *function;
} SaManagerSlotContext;

static int sa_validate_manager_slot(
    const SaImage *image,
    const uint8_t *candidate,
    void *context
) {
    const SaFunction *function = ((const SaManagerSlotContext *)context)->function;
    const uint8_t *cursor = function->start;
    const uint8_t *limit = function->start + function->size;
    DtIntUtilsInstruction instruction;
    size_t match_count = 0;

    while (sa_next_instruction(&cursor, limit, &instruction)) {
        const uint8_t *owner_cursor;
        const uint8_t *store_cursor;
        const uint8_t *store_limit;
        DtIntUtilsInstruction related;
        const uint8_t *manager_slot_target = NULL;
        int tested_register;
        int owner_register = -1;
        int saw_owner_store = 0;

        if (!sa_tested_register(&instruction, &tested_register)) {
            continue;
        }

        owner_cursor = sa_after_last_call(function->start, instruction.address);
        while (sa_next_instruction(&owner_cursor, instruction.address, &related)) {
            const DtIntUtilsOperand *destination;
            const DtIntUtilsOperand *source;

            if (related.mnemonic != DTINTUTILS_MNEMONIC_MOV || related.operand_count != 2) {
                continue;
            }
            destination = &related.operands[0];
            source = &related.operands[1];
            if (destination->type != DTINTUTILS_OPERAND_REGISTER ||
                destination->register_id != tested_register) {
                continue;
            }
            if (source->type == DTINTUTILS_OPERAND_MEMORY &&
                source->memory_index == DTINTUTILS_REGISTER_NONE &&
                source->displacement >= 0 && source->memory_base != SA_REGISTER_RSP &&
                source->memory_base != SA_REGISTER_RBP) {
                owner_register = source->memory_base;
            } else {
                owner_register = -1;
            }
        }
        if (owner_register < 0) {
            continue;
        }

        store_cursor = cursor;
        store_limit = sa_before_next_call(store_cursor, limit);
        while (sa_next_instruction(&store_cursor, store_limit, &related)) {
            const uint8_t *target;
            int source_register;

            if (related.mnemonic == DTINTUTILS_MNEMONIC_TEST) {
                break;
            }
            if (!sa_parse_rip_relative(
                    &related, DTINTUTILS_MNEMONIC_MOV, 1, -1,
                    &target, &source_register) ||
                !dtintutils_is_writable_address(image, target)) {
                continue;
            }
            if (source_register == owner_register) {
                saw_owner_store = 1;
            }
            if (source_register == tested_register) {
                if (manager_slot_target != NULL && manager_slot_target != target) {
                    manager_slot_target = NULL;
                    break;
                }
                manager_slot_target = target;
            }
        }

        if (manager_slot_target == candidate && saw_owner_store) {
            ++match_count;
        }
    }
    return match_count == 1;
}

int sa_locate_resource_manager_slot(
    const SaImage *image,
    const SaFunction *registration_function,
    void ***slot,
    char *error,
    size_t error_size
) {
    SaManagerSlotContext context;
    const uint8_t *address;

    if (image == NULL || registration_function == NULL || slot == NULL) {
        sa_set_error(error, error_size, "resource-manager locator received a null argument");
        return 0;
    }
    const DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_ADDRESS(registration_function->start, 1, 1),
        DTINTUTILS_LOCATE_COLLECT_FUNCTION_RIP_TARGETS(DTINTUTILS_MNEMONIC_MOV, 1, 0),
        DTINTUTILS_LOCATE_FILTER_SECTION(NULL, DTINTUTILS_SECTION_WRITABLE, 1, 0),
    };
    const DtIntUtilsLocator locator = {
        "ResourceManager global slot",
        steps,
        SA_ARRAY_COUNT(steps),
    };
    context.function = registration_function;

    if (!dtintutils_locate_unique_address_with_validator(
            image, &locator, sa_validate_manager_slot, &context,
            &address, error, error_size)) {
        return 0;
    }
    *slot = (void **)address;
    return 1;
}

int sa_find_resource_type_record(
    const SaEngineApi *engine,
    uint64_t requested_type_hash,
    const char *type_name,
    uint8_t **result,
    char *error,
    size_t error_size
) {
    void *manager;
    uint32_t type_count;
    uint8_t *type_data;
    size_t manager_extent;
    size_t records_size;
    size_t type_matches = 0;
    size_t index;

    if (engine == NULL || result == NULL) {
        sa_set_error(error, error_size, "resource type lookup received a null argument");
        return 0;
    }
    *result = NULL;
    if (!dtintutils_is_readable_range(engine->resource_manager_slot, sizeof(void *))) {
        sa_set_error(error, error_size, "the derived ResourceManager global slot is not readable");
        return 0;
    }
    manager = *engine->resource_manager_slot;
    manager_extent = (size_t)engine->type_layout.type_count_offset + sizeof(type_count);
    if (manager_extent < (size_t)engine->type_layout.type_data_offset + sizeof(type_data)) {
        manager_extent = (size_t)engine->type_layout.type_data_offset + sizeof(type_data);
    }
    if (manager == NULL || !dtintutils_is_readable_range(manager, manager_extent)) {
        sa_set_error(error, error_size, "the derived ResourceManager instance is null or unreadable");
        return 0;
    }

    memcpy(&type_count, (uint8_t *)manager + engine->type_layout.type_count_offset, sizeof(type_count));
    memcpy(&type_data, (uint8_t *)manager + engine->type_layout.type_data_offset, sizeof(type_data));
    if (type_count == 0 || type_data == NULL ||
        engine->type_layout.record_size < sizeof(uint64_t) ||
        engine->type_layout.record_size > SIZE_MAX / type_count) {
        sa_set_error(error, error_size, "the derived ResourceManager type table has invalid bounds");
        return 0;
    }
    records_size = (size_t)engine->type_layout.record_size * type_count;
    if (!dtintutils_is_readable_range(type_data, records_size)) {
        sa_set_error(error, error_size, "the derived ResourceManager type record array is not readable");
        return 0;
    }

    for (index = 0; index < type_count; ++index) {
        uint8_t *record = type_data + index * engine->type_layout.record_size;
        uint64_t type_hash;
        memcpy(&type_hash, record, sizeof(type_hash));
        if (type_hash != requested_type_hash) {
            continue;
        }
        *result = record;
        ++type_matches;
    }

    if (type_matches != 1) {
        sa_set_error(error, error_size,
                     "the runtime type table contains %zu records for resource type '%s'; expected 1",
                     type_matches, type_name);
        return 0;
    }
    return 1;
}

int sa_validate_resource_type(
    const SaEngineApi *engine,
    uint64_t requested_type_hash,
    const char *type_name,
    char *error,
    size_t error_size
) {
    uint8_t *record;

    return sa_find_resource_type_record(
        engine, requested_type_hash, type_name, &record, error, error_size);
}
