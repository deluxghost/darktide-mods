#ifndef DTINTUTILS_H
#define DTINTUTILS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define DTINTUTILS_MAX_SECTIONS 96u
#define DTINTUTILS_MAX_OPERANDS 10u
#define DTINTUTILS_MAX_IDA_PATTERN_BYTES 512u
#define DTINTUTILS_LOCATOR_MAX_STEPS 32u
#define DTINTUTILS_LOCATOR_MAX_CANDIDATES 65536u
#define DTINTUTILS_REGISTER_NONE (-1)
#define DTINTUTILS_REGISTER_RIP 16

typedef enum DtIntUtilsMnemonic {
    DTINTUTILS_MNEMONIC_ANY = 0,
    DTINTUTILS_MNEMONIC_OTHER,
    DTINTUTILS_MNEMONIC_ADD,
    DTINTUTILS_MNEMONIC_CALL,
    DTINTUTILS_MNEMONIC_IMUL,
    DTINTUTILS_MNEMONIC_LEA,
    DTINTUTILS_MNEMONIC_MOV,
    DTINTUTILS_MNEMONIC_TEST,
    DTINTUTILS_MNEMONIC_SUB
} DtIntUtilsMnemonic;

typedef enum DtIntUtilsOperandType {
    DTINTUTILS_OPERAND_NONE = 0,
    DTINTUTILS_OPERAND_REGISTER,
    DTINTUTILS_OPERAND_MEMORY,
    DTINTUTILS_OPERAND_IMMEDIATE,
    DTINTUTILS_OPERAND_POINTER
} DtIntUtilsOperandType;

typedef enum DtIntUtilsOperandAccess {
    DTINTUTILS_OPERAND_ACCESS_NONE = 0,
    DTINTUTILS_OPERAND_ACCESS_READ = 1u << 0,
    DTINTUTILS_OPERAND_ACCESS_WRITE = 1u << 1
} DtIntUtilsOperandAccess;

typedef enum DtIntUtilsLocatorOperation {
    DTINTUTILS_LOCATOR_FIND_EXACT_STRING = 1,
    DTINTUTILS_LOCATOR_FIND_STRING_PREFIX,
    DTINTUTILS_LOCATOR_FIND_PATTERN,
    DTINTUTILS_LOCATOR_FIND_POINTER_SLOTS,
    DTINTUTILS_LOCATOR_FIND_RIP_REFERENCES,
    DTINTUTILS_LOCATOR_CONTAINING_FUNCTIONS,
    DTINTUTILS_LOCATOR_FIND_PATTERN_NEAR,
    DTINTUTILS_LOCATOR_ADD_OFFSET,
    DTINTUTILS_LOCATOR_REQUIRE_DIRECT_CALL,
    DTINTUTILS_LOCATOR_RESOLVE_DIRECT_CALL,
    DTINTUTILS_LOCATOR_COLLECT_FUNCTION_CALL_TARGETS,
    DTINTUTILS_LOCATOR_FILTER_PATTERN_NEAR,
    DTINTUTILS_LOCATOR_FILTER_FUNCTION_PATTERN,
    DTINTUTILS_LOCATOR_FILTER_SECTION,
    DTINTUTILS_LOCATOR_FILTER_FUNCTION_ENTRIES,
    DTINTUTILS_LOCATOR_SOURCE_ADDRESS,
    DTINTUTILS_LOCATOR_COLLECT_FUNCTION_RIP_TARGETS,
    DTINTUTILS_LOCATOR_FILTER_CALL_TARGETS_OF
} DtIntUtilsLocatorOperation;

typedef enum DtIntUtilsSectionFlags {
    DTINTUTILS_SECTION_READABLE = 1u,
    DTINTUTILS_SECTION_WRITABLE = 2u,
    DTINTUTILS_SECTION_EXECUTABLE = 4u
} DtIntUtilsSectionFlags;

typedef struct DtIntUtilsSection {
    uint8_t *start;
    size_t size;
    uint32_t characteristics;
    char name[9];
} DtIntUtilsSection;

typedef struct DtIntUtilsModule {
    uint8_t *base;
    size_t image_size;
    DtIntUtilsSection sections[DTINTUTILS_MAX_SECTIONS];
    size_t section_count;
    const DtIntUtilsSection *text;
    const void *runtime_functions;
    size_t runtime_function_count;
} DtIntUtilsModule;

typedef struct DtIntUtilsFunction {
    uint8_t *start;
    size_t size;
    uint32_t begin_rva;
    uint32_t end_rva;
} DtIntUtilsFunction;

typedef struct DtIntUtilsPatternByte {
    uint8_t value;
    uint8_t wildcard;
} DtIntUtilsPatternByte;

typedef struct DtIntUtilsOperand {
    DtIntUtilsOperandType type;
    uint16_t size_bits;
    int register_id;
    int memory_base;
    int memory_index;
    uint8_t memory_scale;
    int64_t displacement;
    uint64_t immediate;
    uint64_t absolute;
    int has_absolute;
    int immediate_is_signed;
    int immediate_is_relative;
} DtIntUtilsOperand;

typedef struct DtIntUtilsInstruction {
    const uint8_t *address;
    size_t length;
    DtIntUtilsMnemonic mnemonic;
    size_t operand_count;
    DtIntUtilsOperand operands[DTINTUTILS_MAX_OPERANDS];
} DtIntUtilsInstruction;

typedef struct DtIntUtilsLocatorStep {
    uint32_t operation;
    uint32_t mnemonic;
    uint32_t required_section_flags;
    uint32_t minimum_results;
    uint32_t maximum_results;
    uint32_t reserved;
    int64_t displacement;
    size_t range_size;
    const char *text;
    const char *section;
    const DtIntUtilsPatternByte *pattern;
    size_t pattern_size;
} DtIntUtilsLocatorStep;

typedef struct DtIntUtilsLocator {
    const char *name;
    const DtIntUtilsLocatorStep *steps;
    size_t step_count;
} DtIntUtilsLocator;

typedef int (*DtIntUtilsLocatorValidator)(
    const DtIntUtilsModule *module,
    const uint8_t *candidate,
    void *context
);

#define DTINTUTILS_LOCATE_EXACT_STRING(value, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FIND_EXACT_STRING, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, 0, 0, value, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_STRING_PREFIX(section_name, value, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FIND_STRING_PREFIX, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, 0, 0, value, section_name, NULL, 0}
#define DTINTUTILS_LOCATE_IDA_PATTERN(section_name, value, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FIND_PATTERN, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, 0, 0, value, section_name, NULL, 0}
#define DTINTUTILS_LOCATE_PATTERN(section_name, values, value_count, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FIND_PATTERN, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, 0, 0, NULL, section_name, values, value_count}
#define DTINTUTILS_LOCATE_ADDRESS(value, minimum, maximum) \
    {DTINTUTILS_LOCATOR_SOURCE_ADDRESS, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, 0, 0, (const char *)(value), NULL, NULL, 0}
#define DTINTUTILS_LOCATE_POINTER_SLOTS(minimum, maximum) \
    {DTINTUTILS_LOCATOR_FIND_POINTER_SLOTS, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, 0, 0, NULL, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_RIP_REFERENCES(mnemonic_value, section_name, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FIND_RIP_REFERENCES, mnemonic_value, 0u, minimum, maximum, 0u, 0, 0, NULL, section_name, NULL, 0}
#define DTINTUTILS_LOCATE_CONTAINING_FUNCTIONS(minimum, maximum) \
    {DTINTUTILS_LOCATOR_CONTAINING_FUNCTIONS, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, 0, 0, NULL, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_IDA_PATTERN_NEAR(value, relative_start, bytes, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FIND_PATTERN_NEAR, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, relative_start, bytes, value, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_PATTERN_NEAR(values, value_count, relative_start, bytes, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FIND_PATTERN_NEAR, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, relative_start, bytes, NULL, NULL, values, value_count}
#define DTINTUTILS_LOCATE_ADD_OFFSET(relative_offset, minimum, maximum) \
    {DTINTUTILS_LOCATOR_ADD_OFFSET, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, relative_offset, 0, NULL, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_REQUIRE_DIRECT_CALL(minimum, maximum) \
    {DTINTUTILS_LOCATOR_REQUIRE_DIRECT_CALL, DTINTUTILS_MNEMONIC_CALL, DTINTUTILS_SECTION_EXECUTABLE, minimum, maximum, 0u, 0, 0, NULL, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_RESOLVE_DIRECT_CALL(minimum, maximum) \
    {DTINTUTILS_LOCATOR_RESOLVE_DIRECT_CALL, DTINTUTILS_MNEMONIC_CALL, DTINTUTILS_SECTION_EXECUTABLE, minimum, maximum, 0u, 0, 0, NULL, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_COLLECT_FUNCTION_CALL_TARGETS(minimum, maximum) \
    {DTINTUTILS_LOCATOR_COLLECT_FUNCTION_CALL_TARGETS, DTINTUTILS_MNEMONIC_CALL, DTINTUTILS_SECTION_EXECUTABLE, minimum, maximum, 0u, 0, 0, NULL, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_COLLECT_FUNCTION_RIP_TARGETS(mnemonic_value, minimum, maximum) \
    {DTINTUTILS_LOCATOR_COLLECT_FUNCTION_RIP_TARGETS, mnemonic_value, 0u, minimum, maximum, 0u, 0, 0, NULL, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_FILTER_CALL_TARGETS_OF(function_address, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FILTER_CALL_TARGETS_OF, DTINTUTILS_MNEMONIC_CALL, DTINTUTILS_SECTION_EXECUTABLE, minimum, maximum, 0u, 0, 0, (const char *)(function_address), NULL, NULL, 0}
#define DTINTUTILS_LOCATE_FILTER_IDA_PATTERN_NEAR(value, relative_start, bytes, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FILTER_PATTERN_NEAR, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, relative_start, bytes, value, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_FILTER_PATTERN_NEAR(values, value_count, relative_start, bytes, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FILTER_PATTERN_NEAR, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, relative_start, bytes, NULL, NULL, values, value_count}
#define DTINTUTILS_LOCATE_FILTER_FUNCTION_IDA_PATTERN(value, relative_start, bytes, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FILTER_FUNCTION_PATTERN, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, relative_start, bytes, value, NULL, NULL, 0}
#define DTINTUTILS_LOCATE_FILTER_FUNCTION_PATTERN(values, value_count, relative_start, bytes, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FILTER_FUNCTION_PATTERN, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, relative_start, bytes, NULL, NULL, values, value_count}
#define DTINTUTILS_LOCATE_FILTER_SECTION(section_name, section_flags, minimum, maximum) \
    {DTINTUTILS_LOCATOR_FILTER_SECTION, DTINTUTILS_MNEMONIC_ANY, section_flags, minimum, maximum, 0u, 0, 0, NULL, section_name, NULL, 0}
#define DTINTUTILS_LOCATE_FILTER_FUNCTION_ENTRIES(minimum, maximum) \
    {DTINTUTILS_LOCATOR_FILTER_FUNCTION_ENTRIES, DTINTUTILS_MNEMONIC_ANY, 0u, minimum, maximum, 0u, 0, 0, NULL, NULL, NULL, 0}

typedef struct DtIntUtilsHook {
    void *target;
    void *trampoline;
    int active;
} DtIntUtilsHook;

typedef struct DtIntUtilsHookRequest {
    DtIntUtilsHook *hook;
    void *target;
    void *detour;
    const DtIntUtilsPatternByte *expected;
    size_t expected_size;
} DtIntUtilsHookRequest;

typedef struct DtIntUtilsCallPatch {
    uint8_t *call_site;
    void *original_target;
    void *relay;
    uintptr_t word_address;
    int64_t original_word;
    int64_t patched_word;
    int active;
} DtIntUtilsCallPatch;

int dtintutils_module_init_current(
    DtIntUtilsModule *module,
    char *error,
    size_t error_size
);

const DtIntUtilsSection *dtintutils_section(
    const DtIntUtilsModule *module,
    const char *name
);

const DtIntUtilsSection *dtintutils_section_for_address(
    const DtIntUtilsModule *module,
    const void *address
);

int dtintutils_is_executable_address(
    const DtIntUtilsModule *module,
    const void *address
);

int dtintutils_is_writable_address(
    const DtIntUtilsModule *module,
    const void *address
);

int dtintutils_is_readable_range(const void *address, size_t size);
int dtintutils_is_writable_range(const void *address, size_t size);

size_t dtintutils_find_exact_strings(
    const DtIntUtilsModule *module,
    const char *value,
    const uint8_t **results,
    size_t result_capacity
);

size_t dtintutils_find_prefix(
    const DtIntUtilsSection *section,
    const char *prefix,
    const uint8_t **results,
    size_t result_capacity
);

size_t dtintutils_find_pointer_slots(
    const DtIntUtilsModule *module,
    uintptr_t target,
    const uint8_t **results,
    size_t result_capacity
);

size_t dtintutils_find_pattern(
    const uint8_t *start,
    size_t size,
    const DtIntUtilsPatternByte *pattern,
    size_t pattern_size,
    const uint8_t **results,
    size_t result_capacity
);

int dtintutils_match_pattern(
    const uint8_t *bytes,
    const DtIntUtilsPatternByte *pattern,
    size_t pattern_size
);

int dtintutils_parse_ida_pattern(
    const char *text,
    DtIntUtilsPatternByte *pattern,
    size_t *pattern_size,
    char *error,
    size_t error_size
);

int dtintutils_contains_bytes(
    const uint8_t *bytes,
    size_t size,
    const uint8_t *needle,
    size_t needle_size
);

int dtintutils_decode(
    const uint8_t *address,
    size_t available,
    DtIntUtilsInstruction *instruction
);

int dtintutils_instruction_writes_register(
    const DtIntUtilsInstruction *instruction,
    int register_id
);

uint32_t dtintutils_instruction_operand_access(
    const DtIntUtilsInstruction *instruction,
    size_t operand_index
);

size_t dtintutils_find_rip_references(
    const uint8_t *start,
    size_t size,
    uintptr_t target,
    DtIntUtilsMnemonic mnemonic,
    const uint8_t **results,
    size_t result_capacity
);

int dtintutils_function_containing(
    const DtIntUtilsModule *module,
    const void *address,
    DtIntUtilsFunction *function
);

size_t dtintutils_collect_direct_call_targets(
    const DtIntUtilsModule *module,
    const DtIntUtilsFunction *function,
    const uint8_t **results,
    size_t result_capacity
);

size_t dtintutils_collect_entry_register_copies(
    const DtIntUtilsFunction *function,
    int source_register,
    int *results,
    size_t result_capacity
);

int dtintutils_find_unique_function_by_exact_string(
    const DtIntUtilsModule *module,
    const char *anchor,
    DtIntUtilsFunction *function,
    char *error,
    size_t error_size
);

int dtintutils_find_unique_functions_by_exact_strings(
    const DtIntUtilsModule *module,
    const char *const *anchors,
    DtIntUtilsFunction *functions,
    size_t anchor_count,
    char *error,
    size_t error_size
);

int dtintutils_find_unique_function_by_ida_pattern(
    const DtIntUtilsModule *module,
    const char *pattern,
    DtIntUtilsFunction *function,
    char *error,
    size_t error_size
);

int dtintutils_locate_unique_address(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocator *locator,
    const uint8_t **address,
    char *error,
    size_t error_size
);

int dtintutils_locate_unique_address_with_validator(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocator *locator,
    DtIntUtilsLocatorValidator validator,
    void *validator_context,
    const uint8_t **address,
    char *error,
    size_t error_size
);

int dtintutils_locate_unique_function(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocator *locator,
    DtIntUtilsFunction *function,
    char *error,
    size_t error_size
);

int dtintutils_hook_install(
    DtIntUtilsHook *hook,
    void *target,
    void *detour,
    const DtIntUtilsPatternByte *expected,
    size_t expected_size,
    char *error,
    size_t error_size
);

int dtintutils_hooks_install(
    const DtIntUtilsHookRequest *requests,
    size_t request_count,
    char *error,
    size_t error_size
);

int dtintutils_hook_install_exact(
    DtIntUtilsHook *hook,
    void *target,
    void *detour,
    const uint8_t *expected,
    size_t expected_size,
    char *error,
    size_t error_size
);

int dtintutils_hook_remove(
    DtIntUtilsHook *hook,
    char *error,
    size_t error_size
);

int dtintutils_call_patch_install(
    DtIntUtilsCallPatch *patch,
    uint8_t *call_site,
    void *detour,
    void *expected_original_target,
    char *error,
    size_t error_size
);

int dtintutils_call_patch_remove(
    DtIntUtilsCallPatch *patch,
    char *error,
    size_t error_size
);

#ifdef __cplusplus
}
#endif

#endif
