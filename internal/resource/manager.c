#include "runtime_internal.h"

#include <string.h>

static int sa_function_references_any(
    const SaFunction *function,
    const uint8_t **targets,
    size_t target_count
) {
    size_t offset;
    for (offset = 0; offset + 7 <= function->size; ++offset) {
        const uint8_t *target;
        size_t target_index;
        if (!sa_parse_rip_relative(function->start + offset, function->start + function->size,
                                   0x8d, -1, &target, NULL, NULL)) {
            continue;
        }
        for (target_index = 0; target_index < target_count; ++target_index) {
            if (target == targets[target_index]) {
                return 1;
            }
        }
    }
    return 0;
}

static int sa_parse_test_same_register(
    const uint8_t *instruction,
    const uint8_t *limit,
    int *register_value,
    size_t *length
) {
    DtIntUtilsInstruction decoded;

    if (instruction >= limit || register_value == NULL || length == NULL ||
        !dtintutils_decode(instruction, (size_t)(limit - instruction), &decoded) ||
        decoded.mnemonic != DTINTUTILS_MNEMONIC_TEST || decoded.operand_count != 2 ||
        decoded.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
        decoded.operands[1].type != DTINTUTILS_OPERAND_REGISTER ||
        decoded.operands[0].size_bits != 64 ||
        decoded.operands[0].register_id != decoded.operands[1].register_id) {
        return 0;
    }
    *register_value = decoded.operands[0].register_id;
    *length = decoded.length;
    return 1;
}

int sa_locate_resource_manager_slot(
    const SaImage *image,
    const SaFunction *registration_function,
    void ***slot,
    char *error,
    size_t error_size
) {
    const uint8_t *slug_strings[SA_MAX_CANDIDATES];
    size_t slug_count;
    size_t offset;
    void **matches[SA_MAX_CANDIDATES];
    size_t match_count = 0;

    if (registration_function == NULL) {
        sa_set_error(error, error_size, "resource-manager registration function is null");
        return 0;
    }

    slug_count = dtintutils_find_exact_strings(image, "slug", slug_strings, SA_ARRAY_COUNT(slug_strings));
    if (slug_count == 0 || slug_count > SA_ARRAY_COUNT(slug_strings) ||
        !sa_function_references_any(registration_function, slug_strings, slug_count)) {
        sa_set_error(error, error_size, "the 'slug_album' function does not also reference the exact 'slug' type");
        return 0;
    }

    for (offset = 0; offset < registration_function->size; ++offset) {
        const uint8_t *instruction = registration_function->start + offset;
        const uint8_t *limit = registration_function->start + registration_function->size;
        int tested_register;
        size_t test_length;
        const uint8_t *cursor;
        const uint8_t *manager_slot_target = NULL;
        int owner_register = -1;
        size_t owner_matches = 0;
        size_t stores = 0;
        int saw_owner_store = 0;

        if (!sa_parse_test_same_register(instruction, limit, &tested_register, &test_length)) {
            continue;
        }

        {
            const uint8_t *owner_search = instruction > registration_function->start + 24
                ? instruction - 24
                : registration_function->start;

            for (cursor = owner_search; cursor < instruction; ++cursor) {
                SaMemoryOperand operand;
                int destination;
                size_t length;
                if (sa_parse_reg_memory_instruction(cursor, instruction, 0x8b, 1, &destination,
                                                    &operand, &length) && destination == tested_register &&
                    operand.displacement >= 0 && operand.base_register != 4 && operand.base_register != 5) {
                    owner_register = operand.base_register;
                    ++owner_matches;
                }
            }
        }
        if (owner_matches != 1) {
            continue;
        }

        for (cursor = instruction + test_length; cursor + 7 <= limit && cursor < instruction + test_length + 32;
             ++cursor) {
            const uint8_t *target;
            int source_register;
            if (!sa_parse_rip_relative(cursor, limit, 0x89, -1, &target, &source_register, NULL)) {
                continue;
            }
            if (!dtintutils_is_writable_address(image, target)) {
                continue;
            }
            ++stores;
            if (source_register == owner_register) {
                saw_owner_store = 1;
            }
            if (source_register == tested_register) {
                if (manager_slot_target != NULL && manager_slot_target != target) {
                    manager_slot_target = NULL;
                    stores = SA_MAX_CANDIDATES;
                    break;
                }
                manager_slot_target = target;
            }
        }

        if (manager_slot_target != NULL && saw_owner_store && stores >= 2 && stores < SA_MAX_CANDIDATES) {
            if (match_count < SA_ARRAY_COUNT(matches)) {
                matches[match_count] = (void **)manager_slot_target;
            }
            ++match_count;
        }
    }

    if (match_count != 1) {
        sa_set_error(error, error_size, "resource-manager global-store analysis produced %zu candidates; expected 1",
                     match_count);
        return 0;
    }
    *slot = matches[0];
    return 1;
}

int sa_validate_resource_type(
    const SaImage *image,
    const SaEngineApi *engine,
    uint64_t requested_type_hash,
    const char *type_name,
    char *error,
    size_t error_size
) {
    void *manager;
    uint32_t type_count;
    uint8_t *type_data;
    size_t records_size;
    size_t type_matches = 0;
    size_t index;

    if (!dtintutils_is_readable_range(engine->resource_manager_slot, sizeof(void *))) {
        sa_set_error(error, error_size, "the derived ResourceManager global slot is not readable");
        return 0;
    }
    manager = *engine->resource_manager_slot;
    if (manager == NULL ||
        !dtintutils_is_readable_range(manager, engine->type_layout.type_data_offset + sizeof(void *))) {
        sa_set_error(error, error_size, "the derived ResourceManager instance is null or unreadable");
        return 0;
    }

    memcpy(&type_count, (uint8_t *)manager + engine->type_layout.type_count_offset, sizeof(type_count));
    memcpy(&type_data, (uint8_t *)manager + engine->type_layout.type_data_offset, sizeof(type_data));
    if (type_count == 0 || type_count > 4096 || type_data == NULL ||
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
        size_t callback_count = 0;
        size_t callback_offset;
        memcpy(&type_hash, record, sizeof(type_hash));
        if (type_hash != requested_type_hash) {
            continue;
        }

        for (callback_offset = sizeof(uint64_t);
             callback_offset + sizeof(void *) <= engine->type_layout.record_size && callback_offset < 0x60;
             callback_offset += sizeof(void *)) {
            void *callback;
            memcpy(&callback, record + callback_offset, sizeof(callback));
            if (dtintutils_is_executable_address(image, callback)) {
                ++callback_count;
            }
        }
        if (callback_count < 2) {
            sa_set_error(error, error_size,
                         "resource type '%s' does not contain the required executable callbacks", type_name);
            return 0;
        }
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
