#include <windows.h>

#include <ctype.h>
#include <string.h>

#include "dtintutils_internal.h"

size_t dtintutils_find_exact_strings(
    const DtIntUtilsModule *module,
    const char *value,
    const uint8_t **results,
    size_t result_capacity
) {
    size_t value_size;
    size_t result_count = 0;
    size_t section_index;

    if (module == NULL || value == NULL) {
        return 0;
    }
    value_size = strlen(value) + 1;
    for (section_index = 0; section_index < module->section_count; ++section_index) {
        const DtIntUtilsSection *section = &module->sections[section_index];
        size_t offset;

        if ((section->characteristics & IMAGE_SCN_MEM_READ) == 0 ||
            (section->characteristics & IMAGE_SCN_MEM_EXECUTE) != 0 || section->size < value_size) {
            continue;
        }
        for (offset = 0; offset <= section->size - value_size; ++offset) {
            if (memcmp(section->start + offset, value, value_size) == 0) {
                if (result_count < result_capacity && results != NULL) {
                    results[result_count] = section->start + offset;
                }
                ++result_count;
            }
        }
    }
    return result_count;
}

size_t dtintutils_find_prefix(
    const DtIntUtilsSection *section,
    const char *prefix,
    const uint8_t **results,
    size_t result_capacity
) {
    size_t prefix_size;
    size_t result_count = 0;
    size_t offset;

    if (section == NULL || prefix == NULL) {
        return 0;
    }
    prefix_size = strlen(prefix);
    if (prefix_size == 0 || section->size < prefix_size) {
        return 0;
    }
    for (offset = 0; offset <= section->size - prefix_size; ++offset) {
        if (memcmp(section->start + offset, prefix, prefix_size) == 0) {
            if (result_count < result_capacity && results != NULL) {
                results[result_count] = section->start + offset;
            }
            ++result_count;
        }
    }
    return result_count;
}

size_t dtintutils_find_pointer_slots(
    const DtIntUtilsModule *module,
    uintptr_t target,
    const uint8_t **results,
    size_t result_capacity
) {
    size_t result_count = 0;
    size_t section_index;

    if (module == NULL) {
        return 0;
    }
    for (section_index = 0; section_index < module->section_count; ++section_index) {
        const DtIntUtilsSection *section = &module->sections[section_index];
        size_t offset;

        if ((strcmp(section->name, ".rdata") != 0 && strcmp(section->name, ".data") != 0) ||
            (section->characteristics & IMAGE_SCN_MEM_READ) == 0 ||
            (section->characteristics & IMAGE_SCN_MEM_EXECUTE) != 0 ||
            section->size < sizeof(uintptr_t)) {
            continue;
        }
        for (offset = 0; offset <= section->size - sizeof(uintptr_t); offset += sizeof(uintptr_t)) {
            uintptr_t value;
            memcpy(&value, section->start + offset, sizeof(value));
            if (value == target) {
                if (result_count < result_capacity && results != NULL) {
                    results[result_count] = section->start + offset;
                }
                ++result_count;
            }
        }
    }
    return result_count;
}

int dtintutils_match_pattern(
    const uint8_t *bytes,
    const DtIntUtilsPatternByte *pattern,
    size_t pattern_size
) {
    size_t index;

    if (bytes == NULL || pattern == NULL || pattern_size == 0) {
        return 0;
    }
    for (index = 0; index < pattern_size; ++index) {
        if (!pattern[index].wildcard && bytes[index] != pattern[index].value) {
            return 0;
        }
    }
    return 1;
}

size_t dtintutils_find_pattern(
    const uint8_t *start,
    size_t size,
    const DtIntUtilsPatternByte *pattern,
    size_t pattern_size,
    const uint8_t **results,
    size_t result_capacity
) {
    size_t result_count = 0;
    size_t offset;

    if (start == NULL || pattern == NULL || pattern_size == 0 || size < pattern_size) {
        return 0;
    }
    for (offset = 0; offset <= size - pattern_size; ++offset) {
        if (dtintutils_match_pattern(start + offset, pattern, pattern_size)) {
            if (result_count < result_capacity && results != NULL) {
                results[result_count] = start + offset;
            }
            ++result_count;
        }
    }
    return result_count;
}

int dtintutils_contains_bytes(
    const uint8_t *bytes,
    size_t size,
    const uint8_t *needle,
    size_t needle_size
) {
    size_t offset;

    if (bytes == NULL || needle == NULL || needle_size == 0 || size < needle_size) {
        return 0;
    }
    for (offset = 0; offset <= size - needle_size; ++offset) {
        if (memcmp(bytes + offset, needle, needle_size) == 0) {
            return 1;
        }
    }
    return 0;
}
static int dtintutils_hex_value(int value) {
    if (value >= '0' && value <= '9') {
        return value - '0';
    }
    if (value >= 'a' && value <= 'f') {
        return value - 'a' + 10;
    }
    if (value >= 'A' && value <= 'F') {
        return value - 'A' + 10;
    }
    return -1;
}

int dtintutils_parse_ida_pattern(
    const char *text,
    DtIntUtilsPatternByte *pattern,
    size_t *pattern_size,
    char *error,
    size_t error_size
) {
    size_t count = 0;
    const char *cursor = text;

    if (text == NULL || pattern == NULL || pattern_size == NULL) {
        dtintutils_set_error(error, error_size, "IDA pattern arguments are invalid");
        return 0;
    }
    while (*cursor != '\0') {
        int high;
        int low;

        while (isspace((unsigned char)*cursor)) {
            ++cursor;
        }
        if (*cursor == '\0') {
            break;
        }
        if (count == DTINTUTILS_MAX_IDA_PATTERN_BYTES) {
            dtintutils_set_error(error, error_size, "IDA pattern exceeds %u bytes",
                                DTINTUTILS_MAX_IDA_PATTERN_BYTES);
            return 0;
        }
        if (*cursor == '?') {
            pattern[count].value = 0;
            pattern[count].wildcard = 1;
            ++cursor;
            if (*cursor == '?') {
                ++cursor;
            }
        } else {
            high = dtintutils_hex_value((unsigned char)cursor[0]);
            low = dtintutils_hex_value((unsigned char)cursor[1]);
            if (high < 0 || low < 0) {
                dtintutils_set_error(error, error_size, "IDA pattern contains an invalid byte near '%s'", cursor);
                return 0;
            }
            pattern[count].value = (uint8_t)((high << 4) | low);
            pattern[count].wildcard = 0;
            cursor += 2;
        }
        if (*cursor != '\0' && !isspace((unsigned char)*cursor)) {
            dtintutils_set_error(error, error_size, "IDA pattern tokens must be separated by whitespace");
            return 0;
        }
        ++count;
    }
    if (count == 0) {
        dtintutils_set_error(error, error_size, "IDA pattern is empty");
        return 0;
    }
    *pattern_size = count;
    return 1;
}

int dtintutils_find_unique_function_by_ida_pattern(
    const DtIntUtilsModule *module,
    const char *pattern_text,
    DtIntUtilsFunction *function,
    char *error,
    size_t error_size
) {
    DtIntUtilsLocatorStep steps[] = {
        DTINTUTILS_LOCATE_IDA_PATTERN(".text", pattern_text, 1, 1),
        DTINTUTILS_LOCATE_FILTER_FUNCTION_ENTRIES(1, 1),
    };
    DtIntUtilsLocator locator = {
        "IDA-pattern function",
        steps,
        DTINTUTILS_ARRAY_COUNT(steps),
    };

    if (module == NULL || module->text == NULL || function == NULL) {
        dtintutils_set_error(error, error_size, "function-by-pattern arguments are invalid");
        return 0;
    }
    return dtintutils_locate_unique_function(module, &locator, function, error, error_size);
}
