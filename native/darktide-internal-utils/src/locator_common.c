#include <windows.h>

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "dtintutils_locator_internal.h"

void dtintutils_locator_set_error(char *buffer, size_t buffer_size, const char *format, ...) {
    va_list arguments;

    if (buffer == NULL || buffer_size == 0) {
        return;
    }
    va_start(arguments, format);
    vsnprintf(buffer, buffer_size, format, arguments);
    va_end(arguments);
    buffer[buffer_size - 1] = '\0';
}

const char *dtintutils_locator_operation_name(uint32_t operation) {
    switch (operation) {
        case DTINTUTILS_LOCATOR_FIND_EXACT_STRING:
            return "find exact string";
        case DTINTUTILS_LOCATOR_FIND_STRING_PREFIX:
            return "find string prefix";
        case DTINTUTILS_LOCATOR_FIND_PATTERN:
            return "find pattern";
        case DTINTUTILS_LOCATOR_SOURCE_ADDRESS:
            return "use address";
        case DTINTUTILS_LOCATOR_FIND_POINTER_SLOTS:
            return "find pointer slots";
        case DTINTUTILS_LOCATOR_FIND_RIP_REFERENCES:
            return "find RIP references";
        case DTINTUTILS_LOCATOR_CONTAINING_FUNCTIONS:
            return "map to containing functions";
        case DTINTUTILS_LOCATOR_FIND_PATTERN_NEAR:
            return "find nearby pattern";
        case DTINTUTILS_LOCATOR_ADD_OFFSET:
            return "add offset";
        case DTINTUTILS_LOCATOR_REQUIRE_DIRECT_CALL:
            return "require direct call";
        case DTINTUTILS_LOCATOR_RESOLVE_DIRECT_CALL:
            return "resolve direct call";
        case DTINTUTILS_LOCATOR_COLLECT_FUNCTION_CALL_TARGETS:
            return "collect function call targets";
        case DTINTUTILS_LOCATOR_COLLECT_FUNCTION_RIP_TARGETS:
            return "collect function RIP targets";
        case DTINTUTILS_LOCATOR_FILTER_CALL_TARGETS_OF:
            return "filter call targets";
        case DTINTUTILS_LOCATOR_FILTER_PATTERN_NEAR:
            return "filter by nearby pattern";
        case DTINTUTILS_LOCATOR_FILTER_FUNCTION_PATTERN:
            return "filter by function pattern";
        case DTINTUTILS_LOCATOR_FILTER_SECTION:
            return "filter by section";
        case DTINTUTILS_LOCATOR_FILTER_FUNCTION_ENTRIES:
            return "filter function entries";
        default:
            return "unknown operation";
    }
}

const char *dtintutils_locator_name(const DtIntUtilsLocator *locator) {
    return locator->name != NULL && locator->name[0] != '\0' ? locator->name : "unnamed locator";
}

void dtintutils_locator_list_free(DtIntUtilsCandidateList *list) {
    free(list->items);
    memset(list, 0, sizeof(*list));
}

static int dtintutils_locator_list_reserve(
    DtIntUtilsCandidateList *list,
    size_t required,
    char *error,
    size_t error_size
) {
    const uint8_t **items;
    size_t capacity;

    if (required > DTINTUTILS_LOCATOR_MAX_CANDIDATES) {
        dtintutils_locator_set_error(error, error_size, "locator candidate set exceeds the %u-address limit",
                          DTINTUTILS_LOCATOR_MAX_CANDIDATES);
        return 0;
    }
    if (required <= list->capacity) {
        return 1;
    }
    capacity = list->capacity == 0 ? 16 : list->capacity;
    while (capacity < required) {
        if (capacity >= DTINTUTILS_LOCATOR_MAX_CANDIDATES / 2) {
            capacity = DTINTUTILS_LOCATOR_MAX_CANDIDATES;
            break;
        }
        capacity *= 2;
    }
    items = (const uint8_t **)realloc(list->items, capacity * sizeof(*items));
    if (items == NULL) {
        dtintutils_locator_set_error(error, error_size, "could not allocate a %zu-address locator candidate set", capacity);
        return 0;
    }
    list->items = items;
    list->capacity = capacity;
    return 1;
}

int dtintutils_locator_list_append_unique(
    DtIntUtilsCandidateList *list,
    const uint8_t *address,
    char *error,
    size_t error_size
) {
    size_t index;

    for (index = 0; index < list->count; ++index) {
        if (list->items[index] == address) {
            return 1;
        }
    }
    if (!dtintutils_locator_list_reserve(list, list->count + 1, error, error_size)) {
        return 0;
    }
    list->items[list->count++] = address;
    return 1;
}

int dtintutils_locator_list_append_hits(
    DtIntUtilsCandidateList *list,
    const uint8_t **hits,
    size_t hit_count,
    char *error,
    size_t error_size
) {
    size_t index;

    for (index = 0; index < hit_count; ++index) {
        if (!dtintutils_locator_list_append_unique(list, hits[index], error, error_size)) {
            return 0;
        }
    }
    return 1;
}

int dtintutils_locator_resolve_pattern(
    const DtIntUtilsLocatorStep *step,
    DtIntUtilsResolvedPattern *resolved,
    char *error,
    size_t error_size
) {
    memset(resolved, 0, sizeof(*resolved));
    if (step->text != NULL && (step->pattern != NULL || step->pattern_size != 0)) {
        dtintutils_locator_set_error(error, error_size, "a locator pattern step specifies both IDA text and raw bytes");
        return 0;
    }
    if (step->text != NULL) {
        if (!dtintutils_parse_ida_pattern(
                step->text,
                resolved->parsed,
                &resolved->size,
                error,
                error_size)) {
            return 0;
        }
        resolved->bytes = resolved->parsed;
        return 1;
    }
    if (step->pattern == NULL || step->pattern_size == 0 ||
        step->pattern_size > DTINTUTILS_MAX_IDA_PATTERN_BYTES) {
        dtintutils_locator_set_error(error, error_size, "a locator pattern step has invalid raw pattern bytes");
        return 0;
    }
    resolved->bytes = step->pattern;
    resolved->size = step->pattern_size;
    return 1;
}

int dtintutils_locator_address_with_displacement(
    const DtIntUtilsModule *module,
    const uint8_t *address,
    int64_t displacement,
    const uint8_t **result
) {
    uintptr_t base = (uintptr_t)module->base;
    uintptr_t end = base + module->image_size;
    uintptr_t value = (uintptr_t)address;

    if (value < base || value >= end) {
        return 0;
    }
    if (displacement >= 0) {
        uint64_t delta = (uint64_t)displacement;
        if (delta >= end - value) {
            return 0;
        }
        value += (uintptr_t)delta;
    } else {
        uint64_t delta = (uint64_t)(-(displacement + 1)) + 1;
        if (delta > value - base) {
            return 0;
        }
        value -= (uintptr_t)delta;
    }
    *result = (const uint8_t *)value;
    return 1;
}

int dtintutils_locator_candidate_range(
    const DtIntUtilsModule *module,
    const uint8_t *candidate,
    int from_function_start,
    int64_t displacement,
    size_t requested_size,
    const uint8_t **start,
    size_t *size
) {
    DtIntUtilsFunction function;
    const uint8_t *origin;
    const uint8_t *range_start;
    size_t available;

    if (!dtintutils_function_containing(module, candidate, &function)) {
        return 0;
    }
    origin = from_function_start ? function.start : candidate;
    if (!dtintutils_locator_address_with_displacement(module, origin, displacement, &range_start) ||
        range_start < function.start || range_start >= function.start + function.size) {
        return 0;
    }
    available = (size_t)(function.start + function.size - range_start);
    *start = range_start;
    *size = requested_size == 0 || requested_size > available ? available : requested_size;
    return 1;
}

int dtintutils_locator_direct_call_target(
    const DtIntUtilsModule *module,
    const uint8_t *address,
    const uint8_t **target
) {
    const DtIntUtilsSection *section = dtintutils_section_for_address(module, address);
    DtIntUtilsInstruction instruction;
    size_t available;

    if (section == NULL) {
        return 0;
    }
    available = (size_t)(section->start + section->size - address);
    if (!dtintutils_decode(address, available, &instruction) ||
        instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL || instruction.operand_count != 1 ||
        instruction.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
        !instruction.operands[0].has_absolute) {
        return 0;
    }
    *target = (const uint8_t *)(uintptr_t)instruction.operands[0].absolute;
    return dtintutils_is_executable_address(module, *target);
}

int dtintutils_locator_section_matches(
    const DtIntUtilsSection *section,
    const DtIntUtilsLocatorStep *step
) {
    if (section == NULL || (step->section != NULL && strcmp(section->name, step->section) != 0)) {
        return 0;
    }
    if ((step->required_section_flags & DTINTUTILS_SECTION_READABLE) != 0 &&
        (section->characteristics & IMAGE_SCN_MEM_READ) == 0) {
        return 0;
    }
    if ((step->required_section_flags & DTINTUTILS_SECTION_WRITABLE) != 0 &&
        (section->characteristics & IMAGE_SCN_MEM_WRITE) == 0) {
        return 0;
    }
    if ((step->required_section_flags & DTINTUTILS_SECTION_EXECUTABLE) != 0 &&
        (section->characteristics & IMAGE_SCN_MEM_EXECUTE) == 0) {
        return 0;
    }
    return 1;
}
