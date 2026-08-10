#include "runtime_internal.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#define SA_MAPPING_BUCKET_COUNT 256
#define SA_MAPPING_ERROR_SIZE 512
#define SA_MAX_RESOURCE_NAME 256
#define SA_MAX_RESOURCE_TYPE 256

enum {
    SA_MAPPING_PENDING,
    SA_MAPPING_READY,
    SA_MAPPING_FAILED,
    SA_MAPPING_FAILING,
};

typedef struct SaResourceMapping {
    struct SaResourceMapping *next;
    uint64_t type_hash;
    uint64_t resource_hash;
    char type_name[SA_MAX_RESOURCE_TYPE];
    char resource_name[SA_MAX_RESOURCE_NAME];
    char file_path[SA_MAX_STREAM_PATH];
    char io_path[SA_MAX_STREAM_PATH];
    uint64_t file_size;
    char error[SA_MAPPING_ERROR_SIZE];
    volatile LONG state;
} SaResourceMapping;

static SRWLOCK g_mapping_insert_lock = SRWLOCK_INIT;
static SaResourceMapping *volatile g_mapping_buckets[SA_MAPPING_BUCKET_COUNT];

static size_t sa_mapping_bucket(uint64_t type_hash, uint64_t resource_hash) {
    uint64_t mixed = type_hash ^ (resource_hash + UINT64_C(0x9e3779b97f4a7c15) +
                                  (type_hash << 6) + (type_hash >> 2));
    return (size_t)(mixed & (SA_MAPPING_BUCKET_COUNT - 1));
}

static SaResourceMapping *sa_find_mapping(uint64_t type_hash, uint64_t resource_hash) {
    SaResourceMapping *mapping = (SaResourceMapping *)InterlockedCompareExchangePointer(
        (PVOID volatile *)&g_mapping_buckets[sa_mapping_bucket(type_hash, resource_hash)], NULL, NULL);

    for (; mapping != NULL; mapping = mapping->next) {
        if (mapping->type_hash == type_hash && mapping->resource_hash == resource_hash) {
            return mapping;
        }
    }
    return NULL;
}

int sa_find_resource_paths(
    uint64_t type_hash,
    uint64_t resource_hash,
    char *path,
    size_t path_size,
    char *io_path,
    size_t io_path_size,
    uint64_t *file_size
) {
    SaResourceMapping *mapping;

    if (path == NULL || path_size < SA_MAX_STREAM_PATH || io_path == NULL ||
        io_path_size < SA_MAX_STREAM_PATH || file_size == NULL) {
        return 0;
    }
    mapping = sa_find_mapping(type_hash, resource_hash);
    if (mapping == NULL) {
        return 0;
    }
    memcpy(path, mapping->file_path, SA_MAX_STREAM_PATH);
    path[SA_MAX_STREAM_PATH - 1] = '\0';
    memcpy(io_path, mapping->io_path, SA_MAX_STREAM_PATH);
    io_path[SA_MAX_STREAM_PATH - 1] = '\0';
    *file_size = mapping->file_size;
    return 1;
}

int sa_register_resource_mapping(
    uint64_t type_hash,
    uint64_t resource_hash,
    const char *type_name,
    const char *resource_name,
    const char *file_path,
    const char *io_path,
    uint64_t file_size,
    int *already_registered,
    char *error,
    size_t error_size
) {
    SaResourceMapping *mapping;
    size_t bucket;

    if (already_registered == NULL) {
        sa_set_error(error, error_size, "resource mapping result pointer is null");
        return 0;
    }
    *already_registered = 0;
    AcquireSRWLockExclusive(&g_mapping_insert_lock);
    mapping = sa_find_mapping(type_hash, resource_hash);
    if (mapping != NULL) {
        if (strcmp(mapping->type_name, type_name) != 0 ||
            strcmp(mapping->resource_name, resource_name) != 0) {
            ReleaseSRWLockExclusive(&g_mapping_insert_lock);
            sa_set_error(error, error_size,
                         "resource type and name have a MurmurHash64A collision with an existing mapping");
            return 0;
        }
        if (strcmp(mapping->file_path, file_path) != 0) {
            ReleaseSRWLockExclusive(&g_mapping_insert_lock);
            sa_set_error(error, error_size,
                         "resource type and name are already mapped to a different path");
            return 0;
        }
        *already_registered = 1;
        ReleaseSRWLockExclusive(&g_mapping_insert_lock);
        return 1;
    }

    mapping = (SaResourceMapping *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*mapping));
    if (mapping == NULL) {
        ReleaseSRWLockExclusive(&g_mapping_insert_lock);
        sa_set_error(error, error_size, "could not allocate an external resource mapping");
        return 0;
    }
    mapping->type_hash = type_hash;
    mapping->resource_hash = resource_hash;
    memcpy(mapping->type_name, type_name, strlen(type_name) + 1);
    memcpy(mapping->resource_name, resource_name, strlen(resource_name) + 1);
    memcpy(mapping->file_path, file_path, strlen(file_path) + 1);
    memcpy(mapping->io_path, io_path, strlen(io_path) + 1);
    mapping->file_size = file_size;

    bucket = sa_mapping_bucket(type_hash, resource_hash);
    mapping->next = (SaResourceMapping *)InterlockedCompareExchangePointer(
        (PVOID volatile *)&g_mapping_buckets[bucket], NULL, NULL);
    InterlockedExchangePointer((PVOID volatile *)&g_mapping_buckets[bucket], mapping);
    ReleaseSRWLockExclusive(&g_mapping_insert_lock);
    return 1;
}

int sa_check_resource_mapping(
    uint64_t type_hash,
    uint64_t resource_hash,
    const char *type_name,
    const char *resource_name,
    const char *file_path,
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
    if (strcmp(mapping->file_path, file_path) != 0) {
        sa_set_error(error, error_size,
                     "resource type and name are already mapped to a different path");
        return 0;
    }
    *registered = 1;
    return 1;
}

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

void sa_mark_resource_ready(uint64_t type_hash, uint64_t resource_hash) {
    SaResourceMapping *mapping = sa_find_mapping(type_hash, resource_hash);

    if (mapping != NULL) {
        InterlockedCompareExchange(&mapping->state, SA_MAPPING_READY, SA_MAPPING_PENDING);
    }
}

void sa_fail_resource(uint64_t type_hash, uint64_t resource_hash, const char *format, ...) {
    SaResourceMapping *mapping = sa_find_mapping(type_hash, resource_hash);
    va_list arguments;

    if (mapping == NULL ||
        InterlockedCompareExchange(&mapping->state, SA_MAPPING_FAILING, SA_MAPPING_PENDING) !=
            SA_MAPPING_PENDING) {
        return;
    }
    va_start(arguments, format);
    vsnprintf(mapping->error, sizeof(mapping->error), format, arguments);
    va_end(arguments);
    mapping->error[sizeof(mapping->error) - 1] = '\0';
    InterlockedExchange(&mapping->state, SA_MAPPING_FAILED);
}
