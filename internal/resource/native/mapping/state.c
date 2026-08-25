#include "internal.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

int sa_resource_mapping_state(
    uint64_t type_hash,
    uint64_t resource_hash,
    const char *type_name,
    const char *resource_name,
    int *state,
    char *error,
    size_t error_size
) {
    SaResourceMapping *mapping = sa_find_mapping(type_hash, resource_hash);
    LONG current_state;

    if (state == NULL) {
        sa_set_error(error, error_size, "resource state result pointer is null");
        return 0;
    }
    if (mapping == NULL || strcmp(mapping->type_name, type_name) != 0 ||
        strcmp(mapping->resource_name, resource_name) != 0) {
        sa_set_error(error, error_size, "resource type and name are not externally mapped");
        return 0;
    }
    current_state = InterlockedCompareExchange(&mapping->state, 0, 0);
    if (current_state == SA_MAPPING_FAILED) {
        sa_set_error(error, error_size, "%s",
                     mapping->error[0] != '\0' ? mapping->error : "external resource loading failed");
        return 0;
    }
    *state = current_state == SA_MAPPING_READY ? 1 : 0;
    return 1;
}

int sa_begin_resource_finalization(
    uint64_t type_hash,
    uint64_t resource_hash,
    int *acquired,
    char *error,
    size_t error_size
) {
    SaResourceMapping *mapping = sa_find_mapping(type_hash, resource_hash);
    LONG previous_state;

    if (acquired == NULL) {
        sa_set_error(error, error_size, "resource finalization result pointer is null");
        return 0;
    }
    *acquired = 0;
    if (mapping == NULL) {
        sa_set_error(error, error_size, "resource is not externally mapped");
        return 0;
    }

    previous_state = InterlockedCompareExchange(
        &mapping->state, SA_MAPPING_FINALIZING, SA_MAPPING_PENDING);
    if (previous_state == SA_MAPPING_PENDING) {
        *acquired = 1;
        return 1;
    }
    if (previous_state == SA_MAPPING_FINALIZING || previous_state == SA_MAPPING_READY ||
        previous_state == SA_MAPPING_FAILING) {
        return 1;
    }
    if (previous_state == SA_MAPPING_FAILED) {
        sa_set_error(error, error_size, "%s",
                     mapping->error[0] != '\0' ? mapping->error : "external resource loading failed");
        return 0;
    }
    sa_set_error(error, error_size, "resource mapping has an invalid finalization state");
    return 0;
}

void sa_mark_resource_ready(uint64_t type_hash, uint64_t resource_hash) {
    SaResourceMapping *mapping = sa_find_mapping(type_hash, resource_hash);

    if (mapping != NULL) {
        InterlockedCompareExchange(&mapping->state, SA_MAPPING_READY, SA_MAPPING_FINALIZING);
    }
}

void sa_fail_resource(uint64_t type_hash, uint64_t resource_hash, const char *format, ...) {
    SaResourceMapping *mapping = sa_find_mapping(type_hash, resource_hash);
    va_list arguments;
    LONG state;

    if (mapping == NULL) {
        return;
    }
    for (;;) {
        state = InterlockedCompareExchange(&mapping->state, 0, 0);
        if (state == SA_MAPPING_FAILED || state == SA_MAPPING_FAILING) {
            return;
        }
        if (state != SA_MAPPING_PENDING && state != SA_MAPPING_FINALIZING &&
            state != SA_MAPPING_READY) {
            return;
        }
        if (InterlockedCompareExchange(&mapping->state, SA_MAPPING_FAILING, state) == state) {
            break;
        }
    }
    va_start(arguments, format);
    vsnprintf(mapping->error, sizeof(mapping->error), format, arguments);
    va_end(arguments);
    mapping->error[sizeof(mapping->error) - 1] = '\0';
    InterlockedExchange(&mapping->state, SA_MAPPING_FAILED);
}
