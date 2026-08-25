#include "../runtime_internal.h"

#include <string.h>

static INIT_ONCE g_stream_initialize_once = INIT_ONCE_STATIC_INIT;
static char g_stream_initialize_error[1024];
static DtIntUtilsHook g_open_stream_hook_state;
static DtIntUtilsHook g_stream_path_join_hook_state;

typedef uint32_t *(*SaPathJoinFn)(uint32_t *, const char *, const char *, void *);

static uint32_t *sa_path_join_hook(
    uint32_t *output,
    const char *base_path,
    const char *path,
    void *allocator
) {
    SaPathJoinFn original = (SaPathJoinFn)g_stream_path_join_hook_state.trampoline;
    char resolved_path[SA_MAX_STREAM_PATH];

    if (sa_resolve_resource_stream_identity(path, resolved_path, sizeof(resolved_path))) {
        base_path = "";
        path = resolved_path;
    } else if (sa_is_resource_stream_path(path)) {
        base_path = "";
    }
    return original(output, base_path, path, allocator);
}

static size_t sa_stream_output_size(void) {
    size_t range_end = (size_t)g_engine.stream_range_offset + sizeof(uint64_t);
    size_t handle_end = (size_t)g_engine.stream_handle_offset + sizeof(int);

    return range_end > handle_end ? range_end : handle_end;
}

static void sa_initialize_invalid_stream(void *output) {
    uint64_t whole_file_range = UINT64_MAX;
    int invalid_handle = -1;

    memset(output, 0, sa_stream_output_size());
    memcpy((uint8_t *)output + g_engine.stream_range_offset, &whole_file_range, sizeof(whole_file_range));
    memcpy((uint8_t *)output + g_engine.stream_handle_offset, &invalid_handle, sizeof(invalid_handle));
}

static void *sa_open_stream_hook(
    void *manager,
    void *output,
    const uint64_t *type_hash,
    const uint64_t *resource_hash,
    uint32_t flags
) {
    SaOpenStreamFn original = (SaOpenStreamFn)g_open_stream_hook_state.trampoline;
    char path[SA_MAX_STREAM_PATH];
    uint64_t range;
    uint64_t whole_file_range = UINT64_MAX;
    void *file_system;
    void *loader;
    int handle;
    int output_writable;
    size_t output_size;

    if (manager == NULL || output == NULL || type_hash == NULL || resource_hash == NULL) {
        return original(manager, output, type_hash, resource_hash, flags);
    }
    if (!sa_find_resource_stream(*type_hash, *resource_hash, path, sizeof(path), &range)) {
        return original(manager, output, type_hash, resource_hash, flags);
    }
    output_size = sa_stream_output_size();
    output_writable = dtintutils_is_writable_range(output, output_size);
    if (strlen(path) >= g_engine.stream_path_size ||
        !dtintutils_is_readable_range(g_engine.file_system_slot, sizeof(void *)) ||
        !dtintutils_is_readable_range((uint8_t *)manager + g_engine.loader_offset, sizeof(void *)) ||
        !output_writable) {
        if (output_writable) {
            sa_initialize_invalid_stream(output);
        }
        sa_fail_resource(*type_hash, *resource_hash,
                         "external stream objects or path storage became unavailable");
        return output;
    }

    file_system = *g_engine.file_system_slot;
    memcpy(&loader, (uint8_t *)manager + g_engine.loader_offset, sizeof(loader));
    if (file_system == NULL || loader == NULL ||
        !dtintutils_is_readable_range((uint8_t *)loader + g_engine.loader_subobject_offset, 1)) {
        sa_initialize_invalid_stream(output);
        sa_fail_resource(*type_hash, *resource_hash,
                         "external stream file-system objects became unavailable");
        return output;
    }

    memset(output, 0, output_size);
    memcpy(output, path, strlen(path) + 1);
    memcpy((uint8_t *)output + g_engine.stream_range_offset, &whole_file_range, sizeof(whole_file_range));
    handle = ((SaFileOpenFn)g_engine.file_open)(
        file_system, (uint8_t)g_engine.file_open_mode,
        (uint8_t *)loader + g_engine.loader_subobject_offset, output);
    memcpy((uint8_t *)output + g_engine.stream_handle_offset, &handle, sizeof(handle));
    memcpy((uint8_t *)output + g_engine.stream_range_offset, &range, sizeof(range));
    if (handle == -1) {
        sa_fail_resource(*type_hash, *resource_hash, "engine file system could not open the external resource stream");
    }
    return output;
}

static BOOL CALLBACK sa_initialize_stream_runtime(PINIT_ONCE once, PVOID parameter, PVOID *context) {
    enum {
        SA_STREAM_FUNCTION_QUEUE_REQUEST,
        SA_STREAM_FUNCTION_CALLBACK_PROCESS,
        SA_STREAM_FUNCTION_OPEN_STREAM,
        SA_STREAM_FUNCTION_FILE_CLIENT_OPEN_INPUT,
        SA_STREAM_FUNCTION_COUNT
    };
    static const char *const function_anchors[SA_STREAM_FUNCTION_COUNT] = {
        "queue_request",
        "stingray::ResourceLoader::callback_thread_process_request",
        "stingray::ResourceManager::open_stream",
        "stingray::FileClient::open_input",
    };
    SaFunction functions[SA_STREAM_FUNCTION_COUNT];
    SaStreamRequestShape request_shape;
    SaOpenStreamShape shape;
    const uint8_t *path_join_target;
    DtIntUtilsHookRequest hooks[2];

    (void)once;
    (void)parameter;
    (void)context;
    g_stream_initialize_error[0] = '\0';

    if (!sa_ensure_resource_runtime(
            g_stream_initialize_error, sizeof(g_stream_initialize_error))) {
        return TRUE;
    }
    memset(&request_shape, 0, sizeof(request_shape));
    if (!dtintutils_find_unique_functions_by_exact_strings(
            &g_image, function_anchors, functions, SA_STREAM_FUNCTION_COUNT,
            g_stream_initialize_error, sizeof(g_stream_initialize_error)) ||
        !sa_analyze_stream_location_shape(
            &functions[SA_STREAM_FUNCTION_QUEUE_REQUEST],
            &functions[SA_STREAM_FUNCTION_CALLBACK_PROCESS],
            g_engine.queue_request_size, &request_shape,
            g_stream_initialize_error, sizeof(g_stream_initialize_error)) ||
        !sa_analyze_open_stream(
            &g_image, &functions[SA_STREAM_FUNCTION_OPEN_STREAM], &shape,
            g_stream_initialize_error, sizeof(g_stream_initialize_error)) ||
        !sa_analyze_path_join_call(
            &g_image, &functions[SA_STREAM_FUNCTION_FILE_CLIENT_OPEN_INPUT], &path_join_target,
            g_stream_initialize_error, sizeof(g_stream_initialize_error))) {
        return TRUE;
    }

    g_engine.stream_request_shape = request_shape;
    g_engine.file_system_slot = shape.file_system_slot;
    g_engine.file_open = (uint8_t *)shape.helper;
    g_engine.loader_offset = shape.loader_offset;
    g_engine.loader_subobject_offset = shape.loader_subobject_offset;
    g_engine.file_open_mode = shape.file_open_mode;
    g_engine.stream_path_size = shape.path_size;
    g_engine.stream_range_offset = shape.range_offset;
    g_engine.stream_handle_offset = shape.handle_offset;

    if (!dtintutils_is_executable_address(&g_image, g_engine.file_open) ||
        !dtintutils_is_readable_range(g_engine.file_system_slot, sizeof(void *))) {
        if (g_stream_initialize_error[0] == '\0') {
            sa_set_error(g_stream_initialize_error, sizeof(g_stream_initialize_error),
                         "open_stream runtime validation failed");
        }
        return TRUE;
    }
    hooks[0].hook = &g_stream_path_join_hook_state;
    hooks[0].target = (void *)path_join_target;
    hooks[0].detour = (void *)sa_path_join_hook;
    hooks[0].expected = NULL;
    hooks[0].expected_size = 0;
    hooks[1].hook = &g_open_stream_hook_state;
    hooks[1].target = functions[SA_STREAM_FUNCTION_OPEN_STREAM].start;
    hooks[1].detour = (void *)sa_open_stream_hook;
    hooks[1].expected = NULL;
    hooks[1].expected_size = 0;
    if (!dtintutils_hooks_install(
            hooks, SA_ARRAY_COUNT(hooks),
            g_stream_initialize_error, sizeof(g_stream_initialize_error))) {
        return TRUE;
    }
    return TRUE;
}

int sa_ensure_stream_runtime(char *error, size_t error_size) {
    if (!InitOnceExecuteOnce(&g_stream_initialize_once, sa_initialize_stream_runtime, NULL, NULL)) {
        sa_set_error(error, error_size, "stream runtime initialization failed with Win32 error %lu", GetLastError());
        return 0;
    }
    if (g_stream_initialize_error[0] != '\0' || !g_open_stream_hook_state.active ||
        g_open_stream_hook_state.trampoline == NULL || !g_stream_path_join_hook_state.active ||
        g_stream_path_join_hook_state.trampoline == NULL) {
        sa_set_error(error, error_size, "%s",
                     g_stream_initialize_error[0] != '\0' ? g_stream_initialize_error :
                     "stream runtime initialization failed");
        return 0;
    }
    return 1;
}
