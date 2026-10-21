#include "internal.h"

#include <string.h>

static int sa_size_add(size_t *total, size_t value) {
    if (*total > SIZE_MAX - value) {
        return 0;
    }
    *total += value;
    return 1;
}

static char *sa_copy_string(char **cursor, const char *value) {
    size_t size = strlen(value) + 1;
    char *result = *cursor;

    memcpy(result, value, size);
    *cursor += size;
    return result;
}

static SaResourceMapping *sa_create_mapping(
    uint64_t type_hash,
    uint64_t resource_hash,
    const char *type_name,
    const char *resource_name,
    const char *file_path,
    const char *io_path,
    const void *resource_data,
    size_t resource_data_size,
    const char *stream_path,
    uint64_t stream_range
) {
    const char *stored_stream_path = stream_path == NULL ? "" : stream_path;
    const char *values[] = {type_name, resource_name, file_path, io_path, stored_stream_path};
    SaResourceMapping *mapping;
    char *cursor;
    size_t strings_size = 0;
    size_t index;

    for (index = 0; index < SA_ARRAY_COUNT(values); ++index) {
        if (!sa_size_add(&strings_size, strlen(values[index]) + 1)) {
            return NULL;
        }
    }
    mapping = (SaResourceMapping *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*mapping));
    if (mapping == NULL) {
        return NULL;
    }
    mapping->strings = (char *)HeapAlloc(GetProcessHeap(), 0, strings_size);
    if (resource_data_size != 0) {
        mapping->resource_data = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, resource_data_size);
    }
    if (mapping->strings == NULL ||
        (resource_data_size != 0 && mapping->resource_data == NULL)) {
        HeapFree(GetProcessHeap(), 0, mapping->resource_data);
        HeapFree(GetProcessHeap(), 0, mapping->strings);
        HeapFree(GetProcessHeap(), 0, mapping);
        return NULL;
    }

    cursor = mapping->strings;
    mapping->type_name = sa_copy_string(&cursor, type_name);
    mapping->resource_name = sa_copy_string(&cursor, resource_name);
    mapping->file_path = sa_copy_string(&cursor, file_path);
    mapping->io_path = sa_copy_string(&cursor, io_path);
    mapping->stream_path = sa_copy_string(&cursor, stored_stream_path);
    mapping->type_hash = type_hash;
    mapping->resource_hash = resource_hash;
    mapping->stream_range = stream_range;
    if (resource_data_size != 0) {
        memcpy(mapping->resource_data, resource_data, resource_data_size);
    }
    mapping->resource_data_size = resource_data_size;
    return mapping;
}

static void sa_destroy_unpublished_mapping(SaResourceMapping *mapping) {
    if (mapping == NULL) {
        return;
    }
    HeapFree(GetProcessHeap(), 0, mapping->resource_data);
    HeapFree(GetProcessHeap(), 0, mapping->strings);
    HeapFree(GetProcessHeap(), 0, mapping);
}

static int sa_mapping_data_matches(
    const SaResourceMapping *mapping,
    const char *file_path,
    const char *io_path,
    const void *resource_data,
    size_t resource_data_size,
    const char *stream_path,
    uint64_t stream_range
) {
    if (strcmp(mapping->file_path, file_path) != 0 || strcmp(mapping->io_path, io_path) != 0 ||
        mapping->resource_data_size != resource_data_size ||
        (resource_data_size != 0 &&
         memcmp(mapping->resource_data, resource_data, resource_data_size) != 0)) {
        return 0;
    }
    if (stream_path == NULL) {
        return mapping->stream_path[0] == '\0';
    }
    return strcmp(mapping->stream_path, stream_path) == 0 &&
        mapping->stream_range == stream_range;
}

int sa_find_resource_data(
    uint64_t type_hash,
    uint64_t resource_hash,
    char *io_path,
    size_t io_path_size,
    const uint8_t **resource_data,
    size_t *resource_data_size
) {
    SaResourceMapping *mapping;
    size_t required;

    if (io_path == NULL || resource_data == NULL || resource_data_size == NULL) {
        return 0;
    }
    mapping = sa_find_mapping(type_hash, resource_hash);
    if (mapping == NULL) {
        return 0;
    }
    required = strlen(mapping->io_path) + 1;
    if (required > io_path_size) {
        return 0;
    }
    memcpy(io_path, mapping->io_path, required);
    *resource_data = mapping->resource_data;
    *resource_data_size = mapping->resource_data_size;
    return 1;
}

int sa_find_resource_stream(
    uint64_t type_hash,
    uint64_t resource_hash,
    char *path,
    size_t path_size,
    uint64_t *range
) {
    SaResourceMapping *mapping;
    size_t required;

    if (path == NULL || range == NULL) {
        return 0;
    }
    mapping = sa_find_mapping(type_hash, resource_hash);
    if (mapping == NULL || mapping->stream_path[0] == '\0') {
        return 0;
    }
    required = strlen(mapping->stream_path) + 1;
    if (required > path_size) {
        return 0;
    }
    memcpy(path, mapping->stream_path, required);
    *range = mapping->stream_range;
    return 1;
}

int sa_register_resource_mapping(
    uint64_t type_hash,
    uint64_t resource_hash,
    const char *type_name,
    const char *resource_name,
    const char *file_path,
    const char *io_path,
    const void *resource_data,
    size_t resource_data_size,
    const char *stream_path,
    uint64_t stream_range,
    int *already_registered,
    char *error,
    size_t error_size
) {
    SaResourceMapping *mapping;
    int has_stream = stream_path != NULL;

    if (already_registered == NULL) {
        sa_set_error(error, error_size, "resource mapping result pointer is null");
        return 0;
    }
    *already_registered = 0;
    if (type_name == NULL || resource_name == NULL || file_path == NULL || io_path == NULL ||
        (resource_data_size != 0 && resource_data == NULL) ||
        (resource_data_size == 0 && stream_path == NULL)) {
        sa_set_error(error, error_size, "resource mapping data is invalid");
        return 0;
    }
    if (strlen(file_path) >= SA_MAX_STREAM_PATH || strlen(io_path) >= SA_MAX_STREAM_PATH ||
        (stream_path != NULL && strlen(stream_path) >= SA_MAX_STREAM_PATH)) {
        sa_set_error(error, error_size, "resource mapping path is too long");
        return 0;
    }

    sa_lock_mapping_index();
    mapping = sa_find_mapping_locked(type_hash, resource_hash);
    if (mapping != NULL) {
        if (strcmp(mapping->type_name, type_name) != 0 ||
            strcmp(mapping->resource_name, resource_name) != 0) {
            sa_unlock_mapping_index();
            sa_set_error(error, error_size,
                         "resource type and name have a MurmurHash64A collision with an existing mapping");
            return 0;
        }
        if (!sa_mapping_data_matches(
                mapping, file_path, io_path, resource_data, resource_data_size,
                stream_path, stream_range)) {
            sa_unlock_mapping_index();
            sa_set_error(error, error_size,
                         "resource type and name are already mapped to different resource data");
            return 0;
        }
        *already_registered = 1;
        sa_unlock_mapping_index();
        return 1;
    }
    if (!sa_reserve_mapping_indexes(has_stream)) {
        sa_unlock_mapping_index();
        sa_set_error(error, error_size, "could not grow the external resource mapping index");
        return 0;
    }

    mapping = sa_create_mapping(
        type_hash, resource_hash, type_name, resource_name, file_path, io_path,
        resource_data, resource_data_size, stream_path, stream_range);
    if (mapping == NULL) {
        sa_unlock_mapping_index();
        sa_set_error(error, error_size, "could not allocate an external resource mapping");
        return 0;
    }
    if (has_stream && !sa_format_resource_stream_identity(
            type_hash, resource_hash, mapping->stream_identity,
            sizeof(mapping->stream_identity))) {
        sa_destroy_unpublished_mapping(mapping);
        sa_unlock_mapping_index();
        sa_set_error(error, error_size, "could not format external resource stream identity");
        return 0;
    }

    sa_insert_mapping_indexes(mapping, has_stream);
    sa_unlock_mapping_index();
    return 1;
}

int sa_check_resource_mapping(
    uint64_t type_hash,
    uint64_t resource_hash,
    const char *type_name,
    const char *resource_name,
    const char *file_path,
    const char *io_path,
    const void *resource_data,
    size_t resource_data_size,
    const char *stream_path,
    uint64_t stream_range,
    int *registered,
    char *error,
    size_t error_size
) {
    SaResourceMapping *mapping = sa_find_mapping(type_hash, resource_hash);

    if (registered == NULL) {
        sa_set_error(error, error_size, "resource mapping result pointer is null");
        return 0;
    }
    *registered = 0;
    if (mapping == NULL) {
        return 1;
    }
    if (strcmp(mapping->type_name, type_name) != 0 ||
        strcmp(mapping->resource_name, resource_name) != 0) {
        sa_set_error(error, error_size,
                     "resource type and name have a MurmurHash64A collision with an existing mapping");
        return 0;
    }
    if (!sa_mapping_data_matches(
            mapping, file_path, io_path, resource_data, resource_data_size,
            stream_path, stream_range)) {
        sa_set_error(error, error_size,
                     "resource type and name are already mapped to different resource data");
        return 0;
    }
    *registered = 1;
    return 1;
}
