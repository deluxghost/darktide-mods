#include "runtime_internal.h"
#include "runtime_windows.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#define SA_MAX_RESOURCE_NAME 256
#define SA_MAX_RESOURCE_TYPE 256

SaEngineApi g_engine;
SaImage g_image;
DtIntUtilsHook g_queue_request_hook_state;

static INIT_ONCE g_initialize_once = INIT_ONCE_STATIC_INIT;
static char g_initialize_error[1024];

void sa_set_error(char *buffer, size_t buffer_size, const char *format, ...) {
    va_list arguments;

    if (buffer == NULL || buffer_size == 0) {
        return;
    }

    va_start(arguments, format);
    vsnprintf(buffer, buffer_size, format, arguments);
    va_end(arguments);
    buffer[buffer_size - 1] = '\0';
}

static uint64_t sa_murmur_hash64a(const void *data, size_t size) {
    const uint64_t multiplier = UINT64_C(0xc6a4a7935bd1e995);
    const int shift = 47;
    const uint8_t *bytes = (const uint8_t *)data;
    uint64_t hash = (uint64_t)size * multiplier;

    while (size >= 8) {
        uint64_t value;
        memcpy(&value, bytes, sizeof(value));
        value *= multiplier;
        value ^= value >> shift;
        value *= multiplier;
        hash ^= value;
        hash *= multiplier;
        bytes += 8;
        size -= 8;
    }

    switch (size) {
        case 7: hash ^= (uint64_t)bytes[6] << 48; /* fall through */
        case 6: hash ^= (uint64_t)bytes[5] << 40; /* fall through */
        case 5: hash ^= (uint64_t)bytes[4] << 32; /* fall through */
        case 4: hash ^= (uint64_t)bytes[3] << 24; /* fall through */
        case 3: hash ^= (uint64_t)bytes[2] << 16; /* fall through */
        case 2: hash ^= (uint64_t)bytes[1] << 8; /* fall through */
        case 1: hash ^= (uint64_t)bytes[0]; hash *= multiplier;
        default: break;
    }

    hash ^= hash >> shift;
    hash *= multiplier;
    hash ^= hash >> shift;
    return hash;
}

static BOOL CALLBACK sa_initialize_engine(PINIT_ONCE once, PVOID parameter, PVOID *context) {
    enum {
        SA_FUNCTION_LOAD,
        SA_FUNCTION_GET_RAW_RESOURCE,
        SA_FUNCTION_QUEUE_REQUEST,
        SA_FUNCTION_QUEUE_READ,
        SA_FUNCTION_INPUT_TRANSFER,
        SA_FUNCTION_SLUG_REGISTRATION,
        SA_FUNCTION_COUNT
    };
    static const char *const function_anchors[SA_FUNCTION_COUNT] = {
        "stingray::ResourceManager::load",
        "stingray::ResourceManager::get_raw_resource",
        "queue_request",
        "queue_read",
        "stingray::ResourceLoader::input_thread_transfer_request_to_callback_thread",
        "slug_album",
    };
    SaImage image;
    SaFunction functions[SA_FUNCTION_COUNT];
    SaTypeLayout load_layout;
    SaTypeLayout raw_layout;
    const uint8_t *load_lookup_helper;
    const uint8_t *raw_lookup_helper;
    const uint8_t *queue_push;

    (void)once;
    (void)parameter;
    (void)context;
    g_initialize_error[0] = '\0';

    if (sa_murmur_hash64a("slug", 4) != SA_KNOWN_SLUG_TYPE_HASH) {
        sa_set_error(g_initialize_error, sizeof(g_initialize_error), "internal MurmurHash64A self-check failed");
        return TRUE;
    }
    if (!dtintutils_module_init_current(&image, g_initialize_error, sizeof(g_initialize_error)) ||
        !dtintutils_find_unique_functions_by_exact_strings(
            &image, function_anchors, functions, SA_FUNCTION_COUNT,
            g_initialize_error, sizeof(g_initialize_error)) ||
        !sa_analyze_type_layout(&image, &functions[SA_FUNCTION_LOAD], &load_layout, &load_lookup_helper,
                                g_initialize_error, sizeof(g_initialize_error)) ||
        !sa_analyze_type_layout(&image, &functions[SA_FUNCTION_GET_RAW_RESOURCE],
                                &raw_layout, &raw_lookup_helper,
                                g_initialize_error, sizeof(g_initialize_error))) {
        return TRUE;
    }

    if (memcmp(&load_layout, &raw_layout, sizeof(load_layout)) != 0 ||
        load_lookup_helper != raw_lookup_helper) {
        sa_set_error(g_initialize_error, sizeof(g_initialize_error),
                     "load and get_raw_resource derive different ResourceManager type lookup structures");
        return TRUE;
    }
    if (!sa_validate_queue_read_shape(&functions[SA_FUNCTION_QUEUE_READ], &g_engine.queue_shape,
                                      g_initialize_error, sizeof(g_initialize_error)) ||
        !sa_locate_queue_push(&image, &functions[SA_FUNCTION_QUEUE_REQUEST],
                              &functions[SA_FUNCTION_INPUT_TRANSFER],
                              &queue_push, g_initialize_error, sizeof(g_initialize_error)) ||
        !sa_analyze_input_queue_offset(&functions[SA_FUNCTION_QUEUE_REQUEST], queue_push,
                                       &g_engine.queue_shape.input_queue_offset,
                                       g_initialize_error, sizeof(g_initialize_error)) ||
        !sa_locate_resource_manager_slot(&image, &functions[SA_FUNCTION_SLUG_REGISTRATION],
                                         &g_engine.resource_manager_slot,
                                         g_initialize_error, sizeof(g_initialize_error))) {
        return TRUE;
    }

    g_engine.load = functions[SA_FUNCTION_LOAD].start;
    g_engine.get_raw_resource = functions[SA_FUNCTION_GET_RAW_RESOURCE].start;
    g_engine.queue_push = (uint8_t *)queue_push;
    g_engine.type_layout = load_layout;
    g_image = image;
    g_image.text = dtintutils_section(&g_image, ".text");

    {
        static const DtIntUtilsPatternByte queue_request_entry[] = {
            {0x48, 0}, {0x8b, 0}, {0xc4, 0}, {0x55, 0}, {0x56, 0},
            {0x48, 0}, {0x8d, 0}, {0xa8, 0},
            {0x00, 1}, {0x00, 1}, {0x00, 1}, {0x00, 1},
            {0x48, 0}, {0x81, 0}, {0xec, 0},
            {0x00, 1}, {0x00, 1}, {0x00, 1}, {0x00, 1},
        };

        const DtIntUtilsHookRequest hook_request = {
            &g_queue_request_hook_state,
            functions[SA_FUNCTION_QUEUE_REQUEST].start,
            (void *)sa_queue_request_hook,
            queue_request_entry,
            SA_ARRAY_COUNT(queue_request_entry),
        };

        if (!sa_validate_resource_type(&image, &g_engine, SA_KNOWN_SLUG_TYPE_HASH, "slug",
                                       g_initialize_error, sizeof(g_initialize_error))) {
            return TRUE;
        }
        if (!dtintutils_hooks_install(&hook_request, 1, g_initialize_error, sizeof(g_initialize_error))) {
            return TRUE;
        }
    }

    return TRUE;
}

static int sa_ensure_resource_runtime(char *error, size_t error_size) {
    if (!InitOnceExecuteOnce(&g_initialize_once, sa_initialize_engine, NULL, NULL)) {
        sa_set_error(error, error_size, "InitOnceExecuteOnce failed with Win32 error %lu", GetLastError());
        return 0;
    }
    if (g_initialize_error[0] != '\0' || g_queue_request_hook_state.trampoline == NULL ||
        !g_queue_request_hook_state.active) {
        sa_set_error(error, error_size, "%s",
                     g_initialize_error[0] != '\0' ? g_initialize_error : "resource runtime initialization failed");
        return 0;
    }
    return 1;
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
    if (type_name_length == 0 || type_name_length >= SA_MAX_RESOURCE_TYPE) {
        sa_set_error(error_buffer, error_buffer_size, "resource type must contain 1 to %u UTF-8 bytes",
                     SA_MAX_RESOURCE_TYPE - 1);
        return 0;
    }
    if (resource_name_length == 0 || resource_name_length >= SA_MAX_RESOURCE_NAME) {
        sa_set_error(error_buffer, error_buffer_size, "resource name must contain 1 to %u UTF-8 bytes",
                     SA_MAX_RESOURCE_NAME - 1);
        return 0;
    }
    if (resource_data == NULL || resource_data_size == 0) {
        sa_set_error(error_buffer, error_buffer_size, "resource data must be non-empty");
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
        if (strlen(stream_path) >= g_engine.stream_range_offset) {
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

    type_hash = sa_murmur_hash64a(resource_type, type_name_length);
    resource_hash = sa_murmur_hash64a(resource_name, resource_name_length);
    if (!sa_validate_resource_type(&g_image, &g_engine, type_hash, resource_type,
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

    load(manager, (uint32_t)(resource_hash >> 32), &type_hash, &resource_hash, 0, 0, 0);
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
    void *manager;
    SaGetRawResourceFn get_raw_resource;

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
    if (type_name_length >= SA_MAX_RESOURCE_TYPE || resource_name_length >= SA_MAX_RESOURCE_NAME) {
        sa_set_error(error_buffer, error_buffer_size, "resource type or name exceeds the supported length");
        return -1;
    }
    type_hash = sa_murmur_hash64a(resource_type, type_name_length);
    resource_hash = sa_murmur_hash64a(resource_name, resource_name_length);
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
    if (get_raw_resource(manager, &type_hash, &resource_hash) == NULL) {
        return 0;
    }
    sa_mark_resource_ready(type_hash, resource_hash);
    return 1;
}
