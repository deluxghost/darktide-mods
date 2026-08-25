#include "internal.h"

#include <string.h>

#define SA_MAPPING_INITIAL_CAPACITY 64

static SRWLOCK g_mapping_lock = SRWLOCK_INIT;
static SaResourceMapping **g_mapping_slots;
static size_t g_mapping_capacity;
static size_t g_mapping_count;
static SaResourceMapping **g_stream_identity_slots;
static size_t g_stream_identity_capacity;
static size_t g_stream_identity_count;
static SaResourceMapping **g_stream_path_slots;
static size_t g_stream_path_capacity;
static size_t g_stream_path_count;

static uint64_t sa_mix_hash(uint64_t value) {
    value ^= value >> 30;
    value *= UINT64_C(0xbf58476d1ce4e5b9);
    value ^= value >> 27;
    value *= UINT64_C(0x94d049bb133111eb);
    return value ^ (value >> 31);
}

static uint64_t sa_mapping_hash(uint64_t type_hash, uint64_t resource_hash) {
    return sa_mix_hash(type_hash ^ sa_mix_hash(resource_hash));
}

static uint64_t sa_string_hash(const char *value) {
    uint64_t hash = UINT64_C(14695981039346656037);
    const unsigned char *cursor = (const unsigned char *)value;

    while (*cursor != '\0') {
        hash ^= *cursor++;
        hash *= UINT64_C(1099511628211);
    }
    return hash;
}

static int sa_capacity_for_insert(size_t count, size_t capacity, size_t *required) {
    size_t next = capacity == 0 ? SA_MAPPING_INITIAL_CAPACITY : capacity;

    if (count == SIZE_MAX) {
        return 0;
    }
    while (count + 1 > next - next / 4) {
        if (next > SIZE_MAX / 2) {
            return 0;
        }
        next *= 2;
    }
    *required = next;
    return 1;
}

static SaResourceMapping *sa_find_mapping_in_slots(
    SaResourceMapping **slots,
    size_t capacity,
    uint64_t type_hash,
    uint64_t resource_hash
) {
    size_t index;

    if (capacity == 0) {
        return NULL;
    }
    index = (size_t)(sa_mapping_hash(type_hash, resource_hash) & (capacity - 1));
    while (slots[index] != NULL) {
        SaResourceMapping *mapping = slots[index];

        if (mapping->type_hash == type_hash && mapping->resource_hash == resource_hash) {
            return mapping;
        }
        index = (index + 1) & (capacity - 1);
    }
    return NULL;
}

static SaResourceMapping *sa_find_string_in_slots(
    SaResourceMapping **slots,
    size_t capacity,
    const char *value,
    int stream_identity
) {
    size_t index;

    if (capacity == 0) {
        return NULL;
    }
    index = (size_t)(sa_string_hash(value) & (capacity - 1));
    while (slots[index] != NULL) {
        SaResourceMapping *mapping = slots[index];
        const char *candidate = stream_identity ? mapping->stream_identity : mapping->stream_path;

        if (strcmp(candidate, value) == 0) {
            return mapping;
        }
        index = (index + 1) & (capacity - 1);
    }
    return NULL;
}

static void sa_insert_mapping_slot(
    SaResourceMapping **slots,
    size_t capacity,
    SaResourceMapping *mapping
) {
    size_t index = (size_t)(sa_mapping_hash(
        mapping->type_hash, mapping->resource_hash) & (capacity - 1));

    while (slots[index] != NULL) {
        index = (index + 1) & (capacity - 1);
    }
    slots[index] = mapping;
}

static void sa_insert_string_slot(
    SaResourceMapping **slots,
    size_t capacity,
    SaResourceMapping *mapping,
    int stream_identity
) {
    const char *value = stream_identity ? mapping->stream_identity : mapping->stream_path;
    size_t index = (size_t)(sa_string_hash(value) & (capacity - 1));

    while (slots[index] != NULL) {
        index = (index + 1) & (capacity - 1);
    }
    slots[index] = mapping;
}

static int sa_resize_mapping_slots(size_t required) {
    SaResourceMapping **slots;
    size_t index;

    if (required == g_mapping_capacity) {
        return 1;
    }
    slots = (SaResourceMapping **)HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, required * sizeof(*slots));
    if (slots == NULL) {
        return 0;
    }
    for (index = 0; index < g_mapping_capacity; ++index) {
        if (g_mapping_slots[index] != NULL) {
            sa_insert_mapping_slot(slots, required, g_mapping_slots[index]);
        }
    }
    HeapFree(GetProcessHeap(), 0, g_mapping_slots);
    g_mapping_slots = slots;
    g_mapping_capacity = required;
    return 1;
}

static int sa_resize_string_slots(
    SaResourceMapping ***current_slots,
    size_t *current_capacity,
    size_t required,
    int stream_identity
) {
    SaResourceMapping **slots;
    size_t index;

    if (required == *current_capacity) {
        return 1;
    }
    slots = (SaResourceMapping **)HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, required * sizeof(*slots));
    if (slots == NULL) {
        return 0;
    }
    for (index = 0; index < *current_capacity; ++index) {
        if ((*current_slots)[index] != NULL) {
            sa_insert_string_slot(slots, required, (*current_slots)[index], stream_identity);
        }
    }
    HeapFree(GetProcessHeap(), 0, *current_slots);
    *current_slots = slots;
    *current_capacity = required;
    return 1;
}

void sa_lock_mapping_index(void) {
    AcquireSRWLockExclusive(&g_mapping_lock);
}

void sa_unlock_mapping_index(void) {
    ReleaseSRWLockExclusive(&g_mapping_lock);
}

SaResourceMapping *sa_find_mapping_locked(uint64_t type_hash, uint64_t resource_hash) {
    return sa_find_mapping_in_slots(
        g_mapping_slots, g_mapping_capacity, type_hash, resource_hash);
}

int sa_reserve_mapping_indexes(int has_stream) {
    size_t required;

    if (!sa_capacity_for_insert(g_mapping_count, g_mapping_capacity, &required) ||
        !sa_resize_mapping_slots(required)) {
        return 0;
    }
    if (!has_stream) {
        return 1;
    }
    if (!sa_capacity_for_insert(
            g_stream_identity_count, g_stream_identity_capacity, &required) ||
        !sa_resize_string_slots(
            &g_stream_identity_slots, &g_stream_identity_capacity, required, 1)) {
        return 0;
    }
    if (!sa_capacity_for_insert(g_stream_path_count, g_stream_path_capacity, &required) ||
        !sa_resize_string_slots(&g_stream_path_slots, &g_stream_path_capacity, required, 0)) {
        return 0;
    }
    return 1;
}

void sa_insert_mapping_indexes(SaResourceMapping *mapping, int has_stream) {
    sa_insert_mapping_slot(g_mapping_slots, g_mapping_capacity, mapping);
    ++g_mapping_count;
    if (!has_stream) {
        return;
    }

    sa_insert_string_slot(
        g_stream_identity_slots, g_stream_identity_capacity, mapping, 1);
    ++g_stream_identity_count;
    if (sa_find_string_in_slots(
            g_stream_path_slots, g_stream_path_capacity, mapping->stream_path, 0) == NULL) {
        sa_insert_string_slot(g_stream_path_slots, g_stream_path_capacity, mapping, 0);
        ++g_stream_path_count;
    }
}

SaResourceMapping *sa_find_mapping(uint64_t type_hash, uint64_t resource_hash) {
    SaResourceMapping *mapping;

    AcquireSRWLockShared(&g_mapping_lock);
    mapping = sa_find_mapping_locked(type_hash, resource_hash);
    ReleaseSRWLockShared(&g_mapping_lock);
    return mapping;
}

SaResourceMapping *sa_find_mapping_by_stream_identity(const char *identity) {
    SaResourceMapping *mapping;

    AcquireSRWLockShared(&g_mapping_lock);
    mapping = sa_find_string_in_slots(
        g_stream_identity_slots, g_stream_identity_capacity, identity, 1);
    ReleaseSRWLockShared(&g_mapping_lock);
    return mapping;
}

SaResourceMapping *sa_find_mapping_by_stream_path(const char *path) {
    SaResourceMapping *mapping;

    AcquireSRWLockShared(&g_mapping_lock);
    mapping = sa_find_string_in_slots(g_stream_path_slots, g_stream_path_capacity, path, 0);
    ReleaseSRWLockShared(&g_mapping_lock);
    return mapping;
}
