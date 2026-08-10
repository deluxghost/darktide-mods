#ifndef SIMPLE_ASSETS_RESOURCE_RUNTIME_INTERNAL_H
#define SIMPLE_ASSETS_RESOURCE_RUNTIME_INTERNAL_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

#include <stddef.h>
#include <stdint.h>

#include "dtintutils.h"

#define SA_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))
#define SA_MAX_CANDIDATES 128
#define SA_MAX_STREAM_PATH 4096
#define SA_KNOWN_SLUG_TYPE_HASH UINT64_C(0xA27B4D04A9BA6F9E)

typedef DtIntUtilsModule SaImage;
typedef DtIntUtilsFunction SaFunction;

typedef struct {
    int base_register;
    int32_t displacement;
    size_t length;
} SaMemoryOperand;

typedef struct {
    uint32_t type_table_offset;
    uint32_t type_count_offset;
    uint32_t type_data_offset;
    uint32_t record_size;
} SaTypeLayout;

typedef struct {
    uint32_t package_id_offset;
    uint32_t type_hash_offset;
    uint32_t name_hash_offset;
    uint32_t data_offset;
    uint32_t size_offset;
    uint32_t handle_offset;
    uint32_t io_loader_offset;
    uint32_t input_queue_offset;
    uint32_t worker_allocate_slot;
    uint32_t io_open_slot;
    uint32_t io_size_slot;
    uint32_t io_read_slot;
} SaQueueReadShape;

typedef struct {
    uint8_t *load;
    uint8_t *get_raw_resource;
    uint8_t *queue_push;
    void **resource_manager_slot;
    SaTypeLayout type_layout;
    SaQueueReadShape queue_shape;
} SaEngineApi;

typedef struct {
    void *data;
    /* queue_read reserves 0x20 bytes for this allocator result and consumes the first pointer. */
    uint64_t opaque[3];
} SaWorkerAllocation;

_Static_assert(sizeof(SaWorkerAllocation) == 0x20, "worker allocation result ABI changed");

typedef void (*SaLoadFn)(void *, uint32_t, const uint64_t *, const uint64_t *, uint64_t, uint8_t, uint8_t);
typedef void *(*SaGetRawResourceFn)(void *, const uint64_t *, const uint64_t *);
typedef uint64_t (*SaQueueRequestFn)(void *, void *);
typedef void (*SaQueuePushFn)(void *, const void *);
typedef void (*SaWorkerAllocateFn)(void *, SaWorkerAllocation *, uint64_t, uint64_t);
typedef uint64_t (*SaIoOpenFn)(void *, const char *, uint64_t, uint64_t, uint32_t, void *, uint8_t);
typedef uint64_t (*SaIoSizeFn)(void *, uint64_t);
typedef uint32_t (*SaIoSubmitFn)(void *);
typedef void (*SaIoWaitFn)(void *, uint32_t);

extern SaEngineApi g_engine;
extern SaImage g_image;
extern DtIntUtilsHook g_queue_request_hook_state;
extern DtIntUtilsHook g_io_submit_hook_state;
extern DtIntUtilsHook g_io_wait_hook_state;

void sa_set_error(char *buffer, size_t buffer_size, const char *format, ...);

int sa_parse_rip_relative(
    const uint8_t *instruction,
    const uint8_t *limit,
    uint8_t opcode,
    int expected_reg,
    const uint8_t **target,
    int *register_value,
    size_t *length
);
int sa_parse_reg_memory_instruction(
    const uint8_t *instruction,
    const uint8_t *limit,
    uint8_t opcode,
    int require_wide,
    int *destination_register,
    SaMemoryOperand *operand,
    size_t *length
);
int sa_parse_memory_reg_instruction(
    const uint8_t *instruction,
    const uint8_t *limit,
    uint8_t opcode,
    int require_wide,
    SaMemoryOperand *operand,
    int *source_register,
    size_t *length
);
int sa_register_in_set(int value, const int *registers, size_t register_count);
size_t sa_collect_argument_registers(
    const SaFunction *function,
    int source_register,
    int *registers,
    size_t capacity
);
int sa_analyze_type_layout(
    const SaImage *image,
    const SaFunction *function,
    SaTypeLayout *layout,
    const uint8_t **lookup_helper,
    char *error,
    size_t error_size
);

int sa_locate_queue_push(
    const SaImage *image,
    const SaFunction *queue_request,
    const SaFunction *input_transfer,
    const uint8_t **queue_push,
    char *error,
    size_t error_size
);
int sa_analyze_input_queue_offset(
    const SaFunction *queue_request,
    const uint8_t *queue_push,
    uint32_t *input_queue_offset,
    char *error,
    size_t error_size
);
int sa_validate_queue_read_shape(
    const SaFunction *queue_read,
    SaQueueReadShape *shape,
    char *error,
    size_t error_size
);
int sa_validate_direct_storage_hook_shapes(
    const SaFunction *submit,
    const SaFunction *wait,
    char *error,
    size_t error_size
);
int sa_make_bundle_relative_path(const char *absolute_path, char *relative_path, size_t capacity);
uint64_t sa_queue_request_hook(void *worker, void *request);
void sa_async_read_start(
    const char *path,
    void *destination,
    uint64_t size,
    void *reader,
    uint64_t type_hash,
    uint64_t resource_hash
);
uint32_t sa_io_submit_hook(void *reader);
void sa_io_wait_hook(void *reader, uint32_t token);
int sa_validate_resource_file(
    const char *resource_type,
    const char *path,
    uint64_t *file_size,
    char *error,
    size_t error_size
);

int sa_locate_resource_manager_slot(
    const SaImage *image,
    const SaFunction *registration_function,
    void ***slot,
    char *error,
    size_t error_size
);
int sa_validate_resource_type(
    const SaImage *image,
    const SaEngineApi *engine,
    uint64_t type_hash,
    const char *type_name,
    char *error,
    size_t error_size
);

int sa_find_resource_paths(
    uint64_t type_hash,
    uint64_t resource_hash,
    char *path,
    size_t path_size,
    char *io_path,
    size_t io_path_size,
    uint64_t *file_size
);
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
);
int sa_check_resource_mapping(
    uint64_t type_hash,
    uint64_t resource_hash,
    const char *type_name,
    const char *resource_name,
    const char *file_path,
    int *registered,
    char *error,
    size_t error_size
);
int sa_resource_mapping_state(
    uint64_t type_hash,
    uint64_t resource_hash,
    const char *type_name,
    const char *resource_name,
    int *state,
    char *error,
    size_t error_size
);
void sa_mark_resource_ready(uint64_t type_hash, uint64_t resource_hash);
void sa_fail_resource(uint64_t type_hash, uint64_t resource_hash, const char *format, ...);

#endif
