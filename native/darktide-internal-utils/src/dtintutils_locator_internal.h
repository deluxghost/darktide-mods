#ifndef DTINTUTILS_LOCATOR_INTERNAL_H
#define DTINTUTILS_LOCATOR_INTERNAL_H

#include "../include/dtintutils.h"

typedef struct DtIntUtilsCandidateList {
    const uint8_t **items;
    size_t count;
    size_t capacity;
} DtIntUtilsCandidateList;

typedef struct DtIntUtilsResolvedPattern {
    DtIntUtilsPatternByte parsed[DTINTUTILS_MAX_IDA_PATTERN_BYTES];
    const DtIntUtilsPatternByte *bytes;
    size_t size;
} DtIntUtilsResolvedPattern;

void dtintutils_locator_set_error(char *buffer, size_t buffer_size, const char *format, ...);
const char *dtintutils_locator_operation_name(uint32_t operation);
const char *dtintutils_locator_name(const DtIntUtilsLocator *locator);
void dtintutils_locator_list_free(DtIntUtilsCandidateList *list);
int dtintutils_locator_list_append_unique(
    DtIntUtilsCandidateList *list,
    const uint8_t *value,
    char *error,
    size_t error_size
);
int dtintutils_locator_list_append_hits(
    DtIntUtilsCandidateList *list,
    const uint8_t **hits,
    size_t hit_count,
    char *error,
    size_t error_size
);
int dtintutils_locator_resolve_pattern(
    const DtIntUtilsLocatorStep *step,
    DtIntUtilsResolvedPattern *pattern,
    char *error,
    size_t error_size
);
int dtintutils_locator_append_pattern_hits(
    DtIntUtilsCandidateList *output,
    const uint8_t *start,
    size_t size,
    const DtIntUtilsResolvedPattern *pattern,
    char *error,
    size_t error_size
);
int dtintutils_locator_find_exact_string(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
);
int dtintutils_locator_find_string_prefix(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
);
int dtintutils_locator_find_pattern_source(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
);
int dtintutils_locator_append_pointer_slots(
    const DtIntUtilsModule *module,
    uintptr_t target,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
);
int dtintutils_locator_append_rip_references(
    const DtIntUtilsSection *section,
    uintptr_t target,
    DtIntUtilsMnemonic mnemonic,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
);
int dtintutils_locator_address_with_displacement(
    const DtIntUtilsModule *module,
    const uint8_t *address,
    int64_t displacement,
    const uint8_t **result
);
int dtintutils_locator_candidate_range(
    const DtIntUtilsModule *module,
    const uint8_t *candidate,
    int from_function_start,
    int64_t displacement,
    size_t requested_size,
    const uint8_t **start,
    size_t *size
);
int dtintutils_locator_direct_call_target(
    const DtIntUtilsModule *module,
    const uint8_t *address,
    const uint8_t **target
);
int dtintutils_locator_section_matches(
    const DtIntUtilsSection *section,
    const DtIntUtilsLocatorStep *step
);

#endif
