#include "../runtime_internal.h"

#include <string.h>

int sa_finalize_external_resource(
    uint64_t type_hash,
    void *raw_resource,
    char *error,
    size_t error_size
) {
    uint8_t *record;
    void *callback;
    void *user_data;
    void *manager;

    if (raw_resource == NULL) {
        sa_set_error(error, error_size, "cannot finalize a null raw resource");
        return 0;
    }
    if (!sa_find_resource_type_record(
            &g_engine, type_hash, "external resource", &record,
            error, error_size)) {
        return 0;
    }
    memcpy(&callback, record + g_engine.resource_lookup_callback_offset, sizeof(callback));
    if (callback == NULL) {
        return 1;
    }
    if (!dtintutils_is_executable_address(&g_image, callback)) {
        sa_set_error(error, error_size, "the resource type's lookup callback is not executable");
        return 0;
    }
    memcpy(&user_data, record + g_engine.resource_lookup_user_data_offset, sizeof(user_data));
    manager = *g_engine.resource_manager_slot;
    if (manager == NULL) {
        sa_set_error(error, error_size, "ResourceManager became unavailable during resource finalization");
        return 0;
    }

    ((SaResourceLookupFn)callback)(user_data, raw_resource, manager);
    return 1;
}
