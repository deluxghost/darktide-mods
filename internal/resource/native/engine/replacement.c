#include "../runtime_internal.h"

#include <string.h>

#define SA_INITIAL_REPLACEMENT_CAPACITY 16

typedef struct {
    uint64_t type_hash;
    uint64_t target_hash;
    uint64_t source_hash;
    char *type_name;
    char *target_name;
} SaResourceReplacement;

static SRWLOCK g_replacement_lock = SRWLOCK_INIT;
static SaResourceReplacement *g_replacements;
static size_t g_replacement_capacity;
static size_t g_replacement_count;
static INIT_ONCE g_replacement_initialize_once = INIT_ONCE_STATIC_INIT;
static char g_replacement_initialize_error[1024];
static DtIntUtilsHook g_get_raw_resource_hook_state;

static uint64_t sa_replacement_key_hash(uint64_t type_hash, uint64_t target_hash) {
    uint64_t hash = target_hash ^ (type_hash + UINT64_C(0x9e3779b97f4a7c15));

    hash ^= hash >> 30;
    hash *= UINT64_C(0xbf58476d1ce4e5b9);
    hash ^= hash >> 27;
    hash *= UINT64_C(0x94d049bb133111eb);
    hash ^= hash >> 31;
    return hash;
}

static SaResourceReplacement *sa_find_replacement(
    SaResourceReplacement *entries,
    size_t capacity,
    uint64_t type_hash,
    uint64_t target_hash
) {
    size_t index;
    size_t probe;

    if (entries == NULL || capacity == 0) {
        return NULL;
    }
    index = (size_t)sa_replacement_key_hash(type_hash, target_hash) & (capacity - 1);
    for (probe = 0; probe < capacity; ++probe) {
        SaResourceReplacement *entry = &entries[index];

        if (entry->type_name == NULL) {
            return NULL;
        }
        if (entry->type_hash == type_hash && entry->target_hash == target_hash) {
            return entry;
        }
        index = (index + 1) & (capacity - 1);
    }
    return NULL;
}

static void sa_insert_replacement(
    SaResourceReplacement *entries,
    size_t capacity,
    const SaResourceReplacement *replacement
) {
    size_t index = (size_t)sa_replacement_key_hash(
        replacement->type_hash, replacement->target_hash) & (capacity - 1);

    while (entries[index].type_name != NULL) {
        index = (index + 1) & (capacity - 1);
    }
    entries[index] = *replacement;
}

static int sa_reserve_replacements(char *error, size_t error_size) {
    SaResourceReplacement *entries;
    size_t capacity;
    size_t index;

    if (g_replacement_capacity != 0 &&
        g_replacement_count + 1 <= g_replacement_capacity - g_replacement_capacity / 4) {
        return 1;
    }
    if (g_replacement_capacity == 0) {
        capacity = SA_INITIAL_REPLACEMENT_CAPACITY;
    } else {
        if (g_replacement_capacity > SIZE_MAX / 2) {
            sa_set_error(error, error_size, "resource replacement table exceeds the supported size");
            return 0;
        }
        capacity = g_replacement_capacity * 2;
    }
    if (capacity > SIZE_MAX / sizeof(*entries)) {
        sa_set_error(error, error_size, "resource replacement table exceeds the supported size");
        return 0;
    }

    entries = (SaResourceReplacement *)HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, capacity * sizeof(*entries));
    if (entries == NULL) {
        sa_set_error(error, error_size, "failed to allocate resource replacement table");
        return 0;
    }
    for (index = 0; index < g_replacement_capacity; ++index) {
        if (g_replacements[index].type_name != NULL) {
            sa_insert_replacement(entries, capacity, &g_replacements[index]);
        }
    }
    if (g_replacements != NULL) {
        HeapFree(GetProcessHeap(), 0, g_replacements);
    }
    g_replacements = entries;
    g_replacement_capacity = capacity;
    return 1;
}

static int sa_replacement_string(
    const char *value,
    const char *description,
    size_t *length,
    char *error,
    size_t error_size
) {
    if (value == NULL || value[0] == '\0') {
        sa_set_error(error, error_size, "%s must not be empty", description);
        return 0;
    }
    *length = strlen(value);
    return 1;
}

static void *sa_get_raw_resource_hook(
    void *manager,
    const uint64_t *type_hash,
    const uint64_t *resource_hash
) {
    SaGetRawResourceFn original = (SaGetRawResourceFn)g_get_raw_resource_hook_state.trampoline;
    uint64_t replacement_hash;
    const uint64_t *lookup_hash = resource_hash;
    SaResourceReplacement *replacement;

    if (type_hash == NULL || resource_hash == NULL) {
        return original(manager, type_hash, resource_hash);
    }
    AcquireSRWLockShared(&g_replacement_lock);
    replacement = sa_find_replacement(
        g_replacements, g_replacement_capacity, *type_hash, *resource_hash);
    if (replacement != NULL) {
        replacement_hash = replacement->source_hash;
        lookup_hash = &replacement_hash;
    }
    ReleaseSRWLockShared(&g_replacement_lock);

    return original(manager, type_hash, lookup_hash);
}

static BOOL CALLBACK sa_initialize_replacement_runtime(
    PINIT_ONCE once,
    PVOID parameter,
    PVOID *context
) {
    DtIntUtilsHookRequest hook_request;

    (void)once;
    (void)parameter;
    (void)context;
    g_replacement_initialize_error[0] = '\0';

    if (!sa_ensure_resource_runtime(
            g_replacement_initialize_error,
            sizeof(g_replacement_initialize_error))) {
        return TRUE;
    }
    hook_request.hook = &g_get_raw_resource_hook_state;
    hook_request.target = g_engine.get_raw_resource;
    hook_request.detour = (void *)sa_get_raw_resource_hook;
    hook_request.expected = NULL;
    hook_request.expected_size = 0;
    if (!dtintutils_hooks_install(
            &hook_request, 1,
            g_replacement_initialize_error,
            sizeof(g_replacement_initialize_error))) {
        return TRUE;
    }
    g_engine.get_raw_resource = (uint8_t *)g_get_raw_resource_hook_state.trampoline;
    return TRUE;
}

static int sa_ensure_replacement_runtime(char *error, size_t error_size) {
    if (!InitOnceExecuteOnce(
            &g_replacement_initialize_once,
            sa_initialize_replacement_runtime,
            NULL,
            NULL)) {
        sa_set_error(
            error, error_size,
            "replacement runtime initialization failed with Win32 error %lu",
            GetLastError());
        return 0;
    }
    if (g_replacement_initialize_error[0] != '\0' ||
        !g_get_raw_resource_hook_state.active ||
        g_get_raw_resource_hook_state.trampoline == NULL) {
        sa_set_error(
            error, error_size, "%s",
            g_replacement_initialize_error[0] != '\0'
                ? g_replacement_initialize_error
                : "replacement runtime initialization failed");
        return 0;
    }
    return 1;
}

int sa_replace_resource(
    const char *resource_type,
    const char *target_resource_name,
    const char *source_resource_name,
    char *error,
    size_t error_size
) {
    size_t type_length;
    size_t target_length;
    size_t source_length;
    uint64_t type_hash;
    uint64_t target_hash;
    uint64_t source_hash;
    SaGetRawResourceFn get_raw_resource;
    SaResourceReplacement *replacement;
    char *identity;
    size_t identity_size;
    SaResourceReplacement created;
    void *manager;

    if (!sa_replacement_string(
            resource_type, "resource type", &type_length, error, error_size) ||
        !sa_replacement_string(
            target_resource_name, "target resource name", &target_length, error, error_size) ||
        !sa_replacement_string(
            source_resource_name, "source resource name", &source_length, error, error_size)) {
        return 0;
    }
    if (!sa_ensure_replacement_runtime(error, error_size)) {
        return 0;
    }

    type_hash = sa_resource_hash(resource_type, type_length);
    target_hash = sa_resource_hash(target_resource_name, target_length);
    source_hash = sa_resource_hash(source_resource_name, source_length);
    if (!sa_validate_resource_type(&g_engine, type_hash, resource_type, error, error_size)) {
        return 0;
    }
    manager = *g_engine.resource_manager_slot;
    if (manager == NULL) {
        sa_set_error(error, error_size, "ResourceManager became unavailable");
        return 0;
    }
    get_raw_resource = (SaGetRawResourceFn)g_engine.get_raw_resource;
    if (get_raw_resource(manager, &type_hash, &source_hash) == NULL) {
        sa_set_error(error, error_size, "source resource is not loaded");
        return 0;
    }

    AcquireSRWLockExclusive(&g_replacement_lock);
    replacement = sa_find_replacement(
        g_replacements, g_replacement_capacity, type_hash, target_hash);
    if (replacement != NULL) {
        if (strcmp(replacement->type_name, resource_type) != 0 ||
            strcmp(replacement->target_name, target_resource_name) != 0) {
            ReleaseSRWLockExclusive(&g_replacement_lock);
            sa_set_error(error, error_size, "resource replacement identity has a hash collision");
            return 0;
        }
        replacement->source_hash = source_hash;
        ReleaseSRWLockExclusive(&g_replacement_lock);
        if (error != NULL && error_size != 0) {
            error[0] = '\0';
        }
        return 1;
    }

    if (!sa_reserve_replacements(error, error_size)) {
        ReleaseSRWLockExclusive(&g_replacement_lock);
        return 0;
    }
    if (type_length > SIZE_MAX - 2 || target_length > SIZE_MAX - type_length - 2) {
        ReleaseSRWLockExclusive(&g_replacement_lock);
        sa_set_error(error, error_size, "resource replacement identity is too large");
        return 0;
    }
    identity_size = type_length + target_length + 2;
    identity = (char *)HeapAlloc(GetProcessHeap(), 0, identity_size);
    if (identity == NULL) {
        ReleaseSRWLockExclusive(&g_replacement_lock);
        sa_set_error(error, error_size, "failed to allocate resource replacement identity");
        return 0;
    }
    memcpy(identity, resource_type, type_length + 1);
    memcpy(identity + type_length + 1, target_resource_name, target_length + 1);

    created.type_hash = type_hash;
    created.target_hash = target_hash;
    created.source_hash = source_hash;
    created.type_name = identity;
    created.target_name = identity + type_length + 1;
    sa_insert_replacement(g_replacements, g_replacement_capacity, &created);
    ++g_replacement_count;
    ReleaseSRWLockExclusive(&g_replacement_lock);

    if (error != NULL && error_size != 0) {
        error[0] = '\0';
    }
    return 1;
}
