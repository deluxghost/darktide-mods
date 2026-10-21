#include "../runtime_internal.h"
#include "../runtime_windows.h"

#include <stdarg.h>
#include <stdio.h>
#include <string.h>

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

uint64_t sa_resource_hash(const void *data, size_t size) {
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
        SA_FUNCTION_RESOURCE_LOOKUP,
        SA_FUNCTION_COUNT
    };
    static const char *const function_anchors[SA_FUNCTION_COUNT] = {
        "stingray::ResourceManager::load",
        "stingray::ResourceManager::get_raw_resource",
        "queue_request",
        "queue_read",
        "stingray::ResourceLoader::input_thread_transfer_request_to_callback_thread",
        "slug_album",
        "stingray::ResourceManager::resource_lookup",
    };
    SaImage image;
    SaFunction functions[SA_FUNCTION_COUNT];
    SaTypeLayout load_layout;
    SaTypeLayout raw_layout;
    const uint8_t *load_lookup_helper;
    const uint8_t *raw_lookup_helper;
    const uint8_t *queue_push;
    uint32_t request_size;
    uint64_t slug_type_hash;

    (void)once;
    (void)parameter;
    (void)context;
    g_initialize_error[0] = '\0';

    slug_type_hash = sa_resource_hash("slug", 4);
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
    if (!sa_analyze_resource_lookup_shape(
            &functions[SA_FUNCTION_RESOURCE_LOOKUP], &load_layout,
            &g_engine.resource_lookup_user_data_offset,
            &g_engine.resource_lookup_callback_offset,
            g_initialize_error, sizeof(g_initialize_error))) {
        return TRUE;
    }
    if (!sa_locate_queue_push(&image, &functions[SA_FUNCTION_QUEUE_REQUEST],
                              &functions[SA_FUNCTION_INPUT_TRANSFER],
                              &queue_push, &request_size,
                              g_initialize_error, sizeof(g_initialize_error)) ||
        !sa_validate_queue_read_shape(
            &functions[SA_FUNCTION_QUEUE_READ], request_size, &g_engine.queue_shape,
            g_initialize_error, sizeof(g_initialize_error)) ||
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
    g_engine.queue_request_size = request_size;
    g_engine.type_layout = load_layout;
    g_image = image;
    g_image.text = dtintutils_section(&g_image, ".text");

    {
        const DtIntUtilsHookRequest hook_request = {
            &g_queue_request_hook_state,
            functions[SA_FUNCTION_QUEUE_REQUEST].start,
            (void *)sa_queue_request_hook,
            NULL,
            0,
        };

        if (!sa_validate_resource_type(&g_engine, slug_type_hash, "slug",
                                       g_initialize_error, sizeof(g_initialize_error))) {
            return TRUE;
        }
        if (!dtintutils_hooks_install(
                &hook_request, 1, g_initialize_error, sizeof(g_initialize_error))) {
            return TRUE;
        }
    }

    return TRUE;
}

int sa_ensure_resource_runtime(char *error, size_t error_size) {
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
