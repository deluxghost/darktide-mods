#include "runtime_internal.h"

#include <string.h>

static INIT_ONCE g_stream_initialize_once = INIT_ONCE_STATIC_INIT;
static char g_stream_initialize_error[1024];
static DtIntUtilsHook g_open_stream_hook_state;
static DtIntUtilsHook g_stream_path_join_hook_state;
static const uint8_t *g_stream_file_client_open_input;

typedef uint32_t *(*SaPathJoinFn)(uint32_t *, const char *, const char *, void *);

static const DtIntUtilsPatternByte g_open_stream_entry[] = {
    {0x48, 0}, {0x89, 0}, {0x5c, 0}, {0x24, 0}, {0x00, 1},
    {0x48, 0}, {0x89, 0}, {0x7c, 0}, {0x24, 0}, {0x00, 1},
    {0x55, 0}, {0x41, 0}, {0x54, 0}, {0x41, 0}, {0x55, 0},
    {0x41, 0}, {0x56, 0}, {0x41, 0}, {0x57, 0},
    {0x48, 0}, {0x8d, 0}, {0xac, 0}, {0x24, 0},
    {0x00, 1}, {0x00, 1}, {0x00, 1}, {0x00, 1},
    {0x48, 0}, {0x81, 0}, {0xec, 0},
    {0x00, 1}, {0x00, 1}, {0x00, 1}, {0x00, 1},
};

static int sa_validate_stream_file_client(
    const uint8_t *file_client_open_input,
    char *error,
    size_t error_size
) {
    void *manager;
    void *loader;
    void **file_client_vtable;
    void *open_input_method;

    if (!dtintutils_is_readable_range(g_engine.resource_manager_slot, sizeof(void *))) {
        sa_set_error(error, error_size, "ResourceManager slot is unavailable during stream validation");
        return 0;
    }
    manager = *g_engine.resource_manager_slot;
    if (manager == NULL ||
        !dtintutils_is_readable_range((uint8_t *)manager + g_engine.loader_offset, sizeof(void *))) {
        sa_set_error(error, error_size, "ResourceManager loader is unavailable during stream validation");
        return 0;
    }
    memcpy(&loader, (uint8_t *)manager + g_engine.loader_offset, sizeof(loader));
    if (loader == NULL ||
        !dtintutils_is_readable_range((uint8_t *)loader + g_engine.loader_subobject_offset,
                                      sizeof(void *))) {
        sa_set_error(error, error_size, "ResourceLoader FileClient object is unavailable");
        return 0;
    }
    memcpy(&file_client_vtable, (uint8_t *)loader + g_engine.loader_subobject_offset,
           sizeof(file_client_vtable));
    if (file_client_vtable == NULL ||
        !dtintutils_is_readable_range(file_client_vtable, 9 * sizeof(void *))) {
        sa_set_error(error, error_size, "ResourceLoader FileClient vtable is unavailable");
        return 0;
    }
    memcpy(&open_input_method, file_client_vtable + 8, sizeof(open_input_method));
    if (open_input_method != file_client_open_input) {
        sa_set_error(error, error_size,
                     "ResourceLoader FileClient open_input vtable slot does not match the anchored function");
        return 0;
    }
    return 1;
}

static uint32_t *sa_path_join_hook(
    uint32_t *output,
    const char *base_path,
    const char *path,
    void *allocator
) {
    SaPathJoinFn original = (SaPathJoinFn)g_stream_path_join_hook_state.trampoline;

    if (sa_is_resource_stream_path(path)) {
        base_path = "";
    }
    return original(output, base_path, path, allocator);
}

static void sa_initialize_invalid_stream(void *output) {
    uint64_t whole_file_range = UINT64_MAX;
    int invalid_handle = -1;

    memset(output, 0, g_engine.stream_handle_offset + sizeof(invalid_handle));
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

    if (manager == NULL || output == NULL || type_hash == NULL || resource_hash == NULL) {
        return original(manager, output, type_hash, resource_hash, flags);
    }
    if (!sa_find_resource_stream(*type_hash, *resource_hash, path, sizeof(path), &range)) {
        return original(manager, output, type_hash, resource_hash, flags);
    }
    output_writable = dtintutils_is_writable_range(
        output, g_engine.stream_handle_offset + sizeof(int));
    if (strlen(path) >= g_engine.stream_range_offset ||
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

    memset(output, 0, g_engine.stream_handle_offset + sizeof(int));
    memcpy(output, path, strlen(path) + 1);
    memcpy((uint8_t *)output + g_engine.stream_range_offset, &whole_file_range, sizeof(whole_file_range));
    handle = ((SaFileOpenFn)g_engine.file_open)(
        file_system, 2, (uint8_t *)loader + g_engine.loader_subobject_offset, output);
    memcpy((uint8_t *)output + g_engine.stream_handle_offset, &handle, sizeof(handle));
    memcpy((uint8_t *)output + g_engine.stream_range_offset, &range, sizeof(range));
    if (handle == -1) {
        sa_fail_resource(*type_hash, *resource_hash, "engine file system could not open the external video stream");
    }
    return output;
}

static BOOL CALLBACK sa_initialize_stream_runtime(PINIT_ONCE once, PVOID parameter, PVOID *context) {
    SaFunction open_stream;
    SaFunction file_client_open_input;
    SaOpenStreamShape shape;
    const uint8_t *path_join_target;
    DtIntUtilsHookRequest hooks[2];

    (void)once;
    (void)parameter;
    (void)context;
    g_stream_initialize_error[0] = '\0';

    if (!dtintutils_find_unique_function_by_exact_string(
            &g_image, "stingray::ResourceManager::open_stream", &open_stream,
            g_stream_initialize_error, sizeof(g_stream_initialize_error)) ||
        !dtintutils_find_unique_function_by_exact_string(
            &g_image, "stingray::FileClient::open_input", &file_client_open_input,
            g_stream_initialize_error, sizeof(g_stream_initialize_error)) ||
        !sa_analyze_open_stream(&g_image, &open_stream, &shape,
                                g_stream_initialize_error, sizeof(g_stream_initialize_error)) ||
        !sa_analyze_path_join_call(
            &g_image, &file_client_open_input, &path_join_target,
            g_stream_initialize_error, sizeof(g_stream_initialize_error))) {
        return TRUE;
    }

    g_engine.file_system_slot = shape.file_system_slot;
    g_engine.file_open = (uint8_t *)shape.helper;
    g_engine.loader_offset = shape.loader_offset;
    g_engine.loader_subobject_offset = shape.loader_subobject_offset;
    g_engine.stream_range_offset = shape.range_offset;
    g_engine.stream_handle_offset = shape.handle_offset;
    g_stream_file_client_open_input = file_client_open_input.start;

    if (!dtintutils_is_executable_address(&g_image, g_engine.file_open) ||
        !dtintutils_is_readable_range(g_engine.file_system_slot, sizeof(void *)) ||
        g_engine.stream_handle_offset != g_engine.stream_range_offset + sizeof(uint64_t)) {
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
    hooks[1].target = open_stream.start;
    hooks[1].detour = (void *)sa_open_stream_hook;
    hooks[1].expected = g_open_stream_entry;
    hooks[1].expected_size = SA_ARRAY_COUNT(g_open_stream_entry);
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
    if (!sa_validate_stream_file_client(
            g_stream_file_client_open_input, error, error_size)) {
        return 0;
    }
    return 1;
}


