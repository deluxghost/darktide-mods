#ifndef SIMPLE_ASSETS_RESOURCE_MAPPING_INTERNAL_H
#define SIMPLE_ASSETS_RESOURCE_MAPPING_INTERNAL_H

#include "../runtime_internal.h"

#define SA_MAPPING_ERROR_SIZE 512

enum {
    SA_MAPPING_PENDING,
    SA_MAPPING_FINALIZING,
    SA_MAPPING_READY,
    SA_MAPPING_FAILED,
    SA_MAPPING_FAILING,
};

typedef struct SaResourceMapping {
    uint64_t type_hash;
    uint64_t resource_hash;
    const char *type_name;
    const char *resource_name;
    const char *file_path;
    const char *io_path;
    const char *stream_path;
    char stream_identity[SA_STREAM_IDENTITY_SIZE];
    uint64_t stream_range;
    uint8_t *resource_data;
    size_t resource_data_size;
    char *strings;
    char error[SA_MAPPING_ERROR_SIZE];
    volatile LONG state;
} SaResourceMapping;

SaResourceMapping *sa_find_mapping(uint64_t type_hash, uint64_t resource_hash);
SaResourceMapping *sa_find_mapping_by_stream_identity(const char *identity);
SaResourceMapping *sa_find_mapping_by_stream_path(const char *path);
void sa_lock_mapping_index(void);
void sa_unlock_mapping_index(void);
SaResourceMapping *sa_find_mapping_locked(uint64_t type_hash, uint64_t resource_hash);
int sa_reserve_mapping_indexes(int has_stream);
void sa_insert_mapping_indexes(SaResourceMapping *mapping, int has_stream);

#endif
