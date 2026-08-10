#include <windows.h>

#include <stdlib.h>

#include "dtintutils_locator_internal.h"

int dtintutils_locator_append_pattern_hits(
    DtIntUtilsCandidateList *output,
    const uint8_t *start,
    size_t size,
    const DtIntUtilsResolvedPattern *pattern,
    char *error,
    size_t error_size
) {
    const uint8_t **hits;
    size_t hit_count;
    int result;

    hits = (const uint8_t **)malloc(DTINTUTILS_LOCATOR_MAX_CANDIDATES * sizeof(*hits));
    if (hits == NULL) {
        dtintutils_locator_set_error(error, error_size, "could not allocate pattern candidate buffer");
        return 0;
    }
    hit_count = dtintutils_find_pattern(
        start,
        size,
        pattern->bytes,
        pattern->size,
        hits,
        DTINTUTILS_LOCATOR_MAX_CANDIDATES);
    if (hit_count > DTINTUTILS_LOCATOR_MAX_CANDIDATES) {
        dtintutils_locator_set_error(error, error_size, "pattern scan produced %zu raw candidates; limit is %u",
                          hit_count, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
        free(hits);
        return 0;
    }
    result = dtintutils_locator_list_assign_hits(output, hits, hit_count, error, error_size);
    free(hits);
    return result;
}

int dtintutils_locator_find_exact_string(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    const uint8_t **hits;
    size_t count;
    int result;

    if (step->text == NULL || step->text[0] == '\0') {
        dtintutils_locator_set_error(error, error_size, "exact string locator value is empty");
        return 0;
    }
    hits = (const uint8_t **)malloc(DTINTUTILS_LOCATOR_MAX_CANDIDATES * sizeof(*hits));
    if (hits == NULL) {
        dtintutils_locator_set_error(error, error_size, "could not allocate exact-string candidate buffer");
        return 0;
    }
    count = dtintutils_find_exact_strings(
        module,
        step->text,
        hits,
        DTINTUTILS_LOCATOR_MAX_CANDIDATES);
    if (count > DTINTUTILS_LOCATOR_MAX_CANDIDATES) {
        dtintutils_locator_set_error(error, error_size, "exact-string scan produced %zu raw candidates; limit is %u",
                          count, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
        free(hits);
        return 0;
    }
    result = dtintutils_locator_list_assign_hits(output, hits, count, error, error_size);
    free(hits);
    return result;
}

static int dtintutils_locator_append_prefix_section(
    const DtIntUtilsSection *section,
    const char *prefix,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    const uint8_t **hits;
    size_t count;
    int result;

    hits = (const uint8_t **)malloc(DTINTUTILS_LOCATOR_MAX_CANDIDATES * sizeof(*hits));
    if (hits == NULL) {
        dtintutils_locator_set_error(error, error_size, "could not allocate string-prefix candidate buffer");
        return 0;
    }
    count = dtintutils_find_prefix(section, prefix, hits, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
    if (count > DTINTUTILS_LOCATOR_MAX_CANDIDATES) {
        dtintutils_locator_set_error(error, error_size, "string prefix scan produced %zu raw candidates; limit is %u",
                          count, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
        free(hits);
        return 0;
    }
    result = dtintutils_locator_list_assign_hits(output, hits, count, error, error_size);
    free(hits);
    return result;
}

int dtintutils_locator_find_string_prefix(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    size_t index;

    if (step->text == NULL || step->text[0] == '\0') {
        dtintutils_locator_set_error(error, error_size, "string prefix locator value is empty");
        return 0;
    }
    if (step->section != NULL) {
        const DtIntUtilsSection *section = dtintutils_section(module, step->section);
        if (section == NULL) {
            dtintutils_locator_set_error(error, error_size, "string prefix section '%s' does not exist", step->section);
            return 0;
        }
        return dtintutils_locator_append_prefix_section(section, step->text, output, error, error_size);
    }
    for (index = 0; index < module->section_count; ++index) {
        const DtIntUtilsSection *section = &module->sections[index];
        if ((section->characteristics & IMAGE_SCN_MEM_READ) == 0 ||
            (section->characteristics & IMAGE_SCN_MEM_EXECUTE) != 0 || section->size == 0) {
            continue;
        }
        if (!dtintutils_locator_append_prefix_section(section, step->text, output, error, error_size)) {
            return 0;
        }
    }
    return 1;
}

int dtintutils_locator_find_pattern_source(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    const char *section_name = step->section != NULL ? step->section : ".text";
    const DtIntUtilsSection *section = dtintutils_section(module, section_name);
    DtIntUtilsResolvedPattern pattern;

    if (section == NULL) {
        dtintutils_locator_set_error(error, error_size, "pattern section '%s' does not exist", section_name);
        return 0;
    }
    if (!dtintutils_locator_resolve_pattern(step, &pattern, error, error_size)) {
        return 0;
    }
    return dtintutils_locator_append_pattern_hits(output, section->start, section->size, &pattern, error, error_size);
}

int dtintutils_locator_append_pointer_slots(
    const DtIntUtilsModule *module,
    uintptr_t target,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    const uint8_t **hits;
    size_t count;
    int result;

    hits = (const uint8_t **)malloc(DTINTUTILS_LOCATOR_MAX_CANDIDATES * sizeof(*hits));
    if (hits == NULL) {
        dtintutils_locator_set_error(error, error_size, "could not allocate pointer-slot candidate buffer");
        return 0;
    }
    count = dtintutils_find_pointer_slots(module, target, hits, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
    if (count > DTINTUTILS_LOCATOR_MAX_CANDIDATES) {
        dtintutils_locator_set_error(error, error_size, "pointer-slot scan produced %zu raw candidates; limit is %u",
                          count, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
        free(hits);
        return 0;
    }
    result = dtintutils_locator_list_assign_hits(output, hits, count, error, error_size);
    free(hits);
    return result;
}

int dtintutils_locator_append_rip_references(
    const DtIntUtilsSection *section,
    uintptr_t target,
    DtIntUtilsMnemonic mnemonic,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    const uint8_t **hits;
    size_t count;
    int result;

    hits = (const uint8_t **)malloc(DTINTUTILS_LOCATOR_MAX_CANDIDATES * sizeof(*hits));
    if (hits == NULL) {
        dtintutils_locator_set_error(error, error_size, "could not allocate RIP-reference candidate buffer");
        return 0;
    }
    count = dtintutils_find_rip_references(
        section->start,
        section->size,
        target,
        mnemonic,
        hits,
        DTINTUTILS_LOCATOR_MAX_CANDIDATES);
    if (count > DTINTUTILS_LOCATOR_MAX_CANDIDATES) {
        dtintutils_locator_set_error(error, error_size, "RIP-reference scan produced %zu raw candidates; limit is %u",
                          count, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
        free(hits);
        return 0;
    }
    result = dtintutils_locator_list_assign_hits(output, hits, count, error, error_size);
    free(hits);
    return result;
}
