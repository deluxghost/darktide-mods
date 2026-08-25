#include "../runtime_internal.h"
#include "../runtime_windows.h"

#include <string.h>

int simple_assets_resource_replace(
    const char *resource_type,
    const char *target_resource_name,
    const char *source_resource_name,
    char *error_buffer,
    size_t error_buffer_size
) {
    return sa_replace_resource(
        resource_type, target_resource_name, source_resource_name,
        error_buffer, error_buffer_size);
}

int sa_load_external_resource(
    const char *resource_type,
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    const void *resource_data,
    size_t resource_data_size,
    const char *stream_path,
    uint64_t stream_range,
    char *error_buffer,
    size_t error_buffer_size
) {
    uint64_t type_hash;
    uint64_t resource_hash;
    size_t type_name_length;
    size_t resource_name_length;
    size_t file_path_length;
    int already_registered;
    char io_path[SA_MAX_STREAM_PATH];
    void *manager;
    SaGetRawResourceFn get_raw_resource;
    SaLoadFn load;
    void *raw_resource;

    if (resource_type == NULL || resource_name == NULL || file_path == NULL || io_carrier_path == NULL) {
        sa_set_error(error_buffer, error_buffer_size,
                     "resource type, name, path, and I/O carrier must not be null");
        return 0;
    }
    type_name_length = strlen(resource_type);
    resource_name_length = strlen(resource_name);
    file_path_length = strlen(file_path);
    if (type_name_length == 0 || resource_name_length == 0) {
        sa_set_error(error_buffer, error_buffer_size, "resource type and name must not be empty");
        return 0;
    }
    if ((resource_data_size != 0 && resource_data == NULL) ||
        (resource_data_size == 0 && stream_path == NULL)) {
        sa_set_error(error_buffer, error_buffer_size,
                     "resource data may be empty only for a streamed resource");
        return 0;
    }
    if (file_path_length == 0 || file_path_length >= SA_MAX_STREAM_PATH) {
        sa_set_error(error_buffer, error_buffer_size, "resource path must contain fewer than %u UTF-8 bytes",
                     SA_MAX_STREAM_PATH);
        return 0;
    }
    if (stream_path != NULL &&
        (stream_path[0] == '\0' || strlen(stream_path) >= SA_MAX_STREAM_PATH)) {
        sa_set_error(error_buffer, error_buffer_size, "resource stream path is invalid");
        return 0;
    }
    if (!sa_ensure_resource_runtime(error_buffer, error_buffer_size)) {
        return 0;
    }
    if (stream_path != NULL) {
        if (!sa_ensure_stream_runtime(error_buffer, error_buffer_size)) {
            return 0;
        }
        if (strlen(stream_path) >= g_engine.stream_path_size) {
            sa_set_error(error_buffer, error_buffer_size,
                         "resource stream path exceeds the engine stream path storage");
            return 0;
        }
    }
    if (!sa_make_bundle_relative_path(io_carrier_path, io_path, sizeof(io_path))) {
        sa_set_error(error_buffer, error_buffer_size,
                     "resource I/O carrier must be an absolute path inside the Darktide installation directory");
        return 0;
    }

    type_hash = sa_resource_hash(resource_type, type_name_length);
    resource_hash = sa_resource_hash(resource_name, resource_name_length);
    if (!sa_validate_resource_type(&g_engine, type_hash, resource_type,
                                   error_buffer, error_buffer_size)) {
        return 0;
    }
    manager = *g_engine.resource_manager_slot;
    if (manager == NULL) {
        sa_set_error(error_buffer, error_buffer_size, "ResourceManager became unavailable");
        return 0;
    }
    get_raw_resource = (SaGetRawResourceFn)g_engine.get_raw_resource;
    load = (SaLoadFn)g_engine.load;

    if (!sa_check_resource_mapping(
            type_hash, resource_hash, resource_type, resource_name, file_path,
            io_path, resource_data, resource_data_size, stream_path, stream_range,
            &already_registered, error_buffer, error_buffer_size)) {
        return 0;
    }
    if (already_registered) {
        return 1;
    }
    raw_resource = get_raw_resource(manager, &type_hash, &resource_hash);
    if (raw_resource != NULL) {
        sa_set_error(error_buffer, error_buffer_size,
                     "resource name is already owned by an engine resource");
        return 0;
    }
    if (!sa_register_resource_mapping(
            type_hash, resource_hash, resource_type, resource_name, file_path, io_path,
            resource_data, resource_data_size, stream_path, stream_range,
            &already_registered, error_buffer, error_buffer_size)) {
        return 0;
    }
    if (already_registered) {
        return 1;
    }

    load(manager, (uint32_t)(resource_hash >> 32), &type_hash, &resource_hash,
         NULL, 0, 0);
    if (error_buffer != NULL && error_buffer_size > 0) {
        error_buffer[0] = '\0';
    }
    return 1;
}

int simple_assets_resource_load(
    const char *resource_type,
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    const void *resource_data,
    size_t resource_data_size,
    char *error_buffer,
    size_t error_buffer_size
) {
    if (resource_type == NULL || resource_name == NULL || file_path == NULL ||
        io_carrier_path == NULL || resource_data == NULL) {
        sa_set_error(error_buffer, error_buffer_size,
                     "resource type, name, path, I/O carrier, and data must not be null");
        return 0;
    }
    if (!sa_validate_resource_data(resource_type, resource_data, resource_data_size,
                                   error_buffer, error_buffer_size)) {
        return 0;
    }
    return sa_load_external_resource(
        resource_type, resource_name, file_path, io_carrier_path,
        resource_data, resource_data_size, NULL, 0, error_buffer, error_buffer_size);
}

int simple_assets_resource_state(
    const char *resource_type,
    const char *resource_name,
    char *error_buffer,
    size_t error_buffer_size
) {
    uint64_t type_hash;
    uint64_t resource_hash;
    size_t type_name_length;
    size_t resource_name_length;
    int state;
    int acquired;
    void *manager;
    SaGetRawResourceFn get_raw_resource;
    void *raw_resource;

    if (resource_type == NULL || resource_name == NULL ||
        resource_type[0] == '\0' || resource_name[0] == '\0') {
        sa_set_error(error_buffer, error_buffer_size, "resource type and name must not be empty");
        return -1;
    }
    if (!sa_ensure_resource_runtime(error_buffer, error_buffer_size)) {
        return -1;
    }

    type_name_length = strlen(resource_type);
    resource_name_length = strlen(resource_name);

    type_hash = sa_resource_hash(resource_type, type_name_length);
    resource_hash = sa_resource_hash(resource_name, resource_name_length);
    if (!sa_resource_mapping_state(
            type_hash, resource_hash, resource_type, resource_name,
            &state, error_buffer, error_buffer_size)) {
        return -1;
    }
    if (state == 1) {
        return 1;
    }

    manager = *g_engine.resource_manager_slot;
    if (manager == NULL) {
        sa_set_error(error_buffer, error_buffer_size, "ResourceManager became unavailable");
        return -1;
    }
    get_raw_resource = (SaGetRawResourceFn)g_engine.get_raw_resource;
    if (error_buffer != NULL && error_buffer_size > 0) {
        error_buffer[0] = '\0';
    }
    raw_resource = get_raw_resource(manager, &type_hash, &resource_hash);
    if (raw_resource == NULL) {
        return 0;
    }
    if (!sa_begin_resource_finalization(
            type_hash, resource_hash, &acquired, error_buffer, error_buffer_size)) {
        return -1;
    }
    if (!acquired) {
        if (!sa_resource_mapping_state(
                type_hash, resource_hash, resource_type, resource_name,
                &state, error_buffer, error_buffer_size)) {
            return -1;
        }
        return state;
    }
    if (!sa_finalize_external_resource(type_hash, raw_resource, error_buffer, error_buffer_size)) {
        sa_fail_resource(type_hash, resource_hash, "%s",
                         error_buffer != NULL && error_buffer[0] != '\0'
                             ? error_buffer
                             : "external resource finalization failed");
        return -1;
    }
    sa_mark_resource_ready(type_hash, resource_hash);
    if (!sa_resource_mapping_state(
            type_hash, resource_hash, resource_type, resource_name,
            &state, error_buffer, error_buffer_size)) {
        return -1;
    }
    return state;
}
