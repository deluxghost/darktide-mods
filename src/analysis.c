#include <windows.h>

#include <stdlib.h>
#include <string.h>

#include "dtintutils_internal.h"
#include <Zydis/Zydis.h>

#define DTINTUTILS_EXACT_STRING_MAX_REFERENCES 256u
#define DTINTUTILS_MAX_UNWIND_CHAIN_DEPTH 32u
#define DTINTUTILS_UNW_FLAG_CHAININFO 0x04u


static DtIntUtilsMnemonic dtintutils_mnemonic(ZydisMnemonic mnemonic) {
    switch (mnemonic) {
        case ZYDIS_MNEMONIC_ADD: return DTINTUTILS_MNEMONIC_ADD;
        case ZYDIS_MNEMONIC_CALL: return DTINTUTILS_MNEMONIC_CALL;
        case ZYDIS_MNEMONIC_IMUL: return DTINTUTILS_MNEMONIC_IMUL;
        case ZYDIS_MNEMONIC_LEA: return DTINTUTILS_MNEMONIC_LEA;
        case ZYDIS_MNEMONIC_MOV: return DTINTUTILS_MNEMONIC_MOV;
        case ZYDIS_MNEMONIC_TEST: return DTINTUTILS_MNEMONIC_TEST;
        case ZYDIS_MNEMONIC_SUB: return DTINTUTILS_MNEMONIC_SUB;
        default: return DTINTUTILS_MNEMONIC_OTHER;
    }
}

static int dtintutils_register_id(ZydisRegister value) {
    ZydisRegister largest;

    if (value == ZYDIS_REGISTER_NONE) {
        return DTINTUTILS_REGISTER_NONE;
    }
    if (value == ZYDIS_REGISTER_RIP || value == ZYDIS_REGISTER_EIP || value == ZYDIS_REGISTER_IP) {
        return DTINTUTILS_REGISTER_RIP;
    }
    largest = ZydisRegisterGetLargestEnclosing(ZYDIS_MACHINE_MODE_LONG_64, value);
    if (largest >= ZYDIS_REGISTER_RAX && largest <= ZYDIS_REGISTER_R15) {
        return (int)(largest - ZYDIS_REGISTER_RAX);
    }
    return DTINTUTILS_REGISTER_NONE;
}

static int dtintutils_decode_with_decoder(
    const ZydisDecoder *decoder,
    const uint8_t *address,
    size_t available,
    DtIntUtilsInstruction *instruction
) {
    ZydisDecodedInstruction decoded;
    ZydisDecodedOperand operands[ZYDIS_MAX_OPERAND_COUNT];
    size_t index;

    if (decoder == NULL || address == NULL || available == 0 || instruction == NULL ||
        ZYAN_FAILED(ZydisDecoderDecodeFull(decoder, address, available, &decoded, operands))) {
        return 0;
    }

    memset(instruction, 0, sizeof(*instruction));
    instruction->address = address;
    instruction->length = decoded.length;
    instruction->mnemonic = dtintutils_mnemonic(decoded.mnemonic);
    instruction->operand_count = decoded.operand_count_visible;
    if (instruction->operand_count > DTINTUTILS_MAX_OPERANDS) {
        instruction->operand_count = DTINTUTILS_MAX_OPERANDS;
    }

    for (index = 0; index < instruction->operand_count; ++index) {
        const ZydisDecodedOperand *source = &operands[index];
        DtIntUtilsOperand *target = &instruction->operands[index];
        ZyanU64 absolute;

        target->size_bits = source->size;
        target->register_id = DTINTUTILS_REGISTER_NONE;
        target->memory_base = DTINTUTILS_REGISTER_NONE;
        target->memory_index = DTINTUTILS_REGISTER_NONE;

        switch (source->type) {
            case ZYDIS_OPERAND_TYPE_REGISTER:
                target->type = DTINTUTILS_OPERAND_REGISTER;
                target->register_id = dtintutils_register_id(source->reg.value);
                break;
            case ZYDIS_OPERAND_TYPE_MEMORY:
                target->type = DTINTUTILS_OPERAND_MEMORY;
                target->memory_base = dtintutils_register_id(source->mem.base);
                target->memory_index = dtintutils_register_id(source->mem.index);
                target->memory_scale = source->mem.scale;
                target->displacement = source->mem.disp.has_displacement ? source->mem.disp.value : 0;
                if (ZYAN_SUCCESS(ZydisCalcAbsoluteAddress(&decoded, source, (ZyanU64)(uintptr_t)address, &absolute))) {
                    target->absolute = absolute;
                    target->has_absolute = 1;
                }
                break;
            case ZYDIS_OPERAND_TYPE_IMMEDIATE:
                target->type = DTINTUTILS_OPERAND_IMMEDIATE;
                target->immediate_is_signed = source->imm.is_signed != 0;
                target->immediate_is_relative = source->imm.is_relative != 0;
                target->immediate = source->imm.is_signed
                    ? (uint64_t)source->imm.value.s
                    : source->imm.value.u;
                if (ZYAN_SUCCESS(ZydisCalcAbsoluteAddress(&decoded, source, (ZyanU64)(uintptr_t)address, &absolute))) {
                    target->absolute = absolute;
                    target->has_absolute = 1;
                }
                break;
            case ZYDIS_OPERAND_TYPE_POINTER:
                target->type = DTINTUTILS_OPERAND_POINTER;
                break;
            default:
                target->type = DTINTUTILS_OPERAND_NONE;
                break;
        }
    }
    return 1;
}

int dtintutils_decode(
    const uint8_t *address,
    size_t available,
    DtIntUtilsInstruction *instruction
) {
    ZydisDecoder decoder;

    if (ZYAN_FAILED(ZydisDecoderInit(&decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_STACK_WIDTH_64))) {
        return 0;
    }
    return dtintutils_decode_with_decoder(&decoder, address, available, instruction);
}

static int dtintutils_redecode(
    const DtIntUtilsInstruction *instruction,
    ZydisDecodedInstruction *decoded,
    ZydisDecodedOperand operands[ZYDIS_MAX_OPERAND_COUNT]
) {
    ZydisDecoder decoder;

    return instruction != NULL && instruction->address != NULL && instruction->length != 0 &&
        ZYAN_SUCCESS(ZydisDecoderInit(
            &decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_STACK_WIDTH_64)) &&
        ZYAN_SUCCESS(ZydisDecoderDecodeFull(
            &decoder, instruction->address, instruction->length, decoded, operands));
}

static int dtintutils_decoded_writes_register(
    const ZydisDecodedInstruction *instruction,
    const ZydisDecodedOperand *operands,
    int register_id
) {
    size_t index;

    for (index = 0; index < instruction->operand_count; ++index) {
        const ZydisDecodedOperand *operand = &operands[index];

        if (operand->type == ZYDIS_OPERAND_TYPE_REGISTER &&
            (operand->actions & ZYDIS_OPERAND_ACTION_MASK_WRITE) != 0 &&
            dtintutils_register_id(operand->reg.value) == register_id) {
            return 1;
        }
    }
    return 0;
}

int dtintutils_instruction_writes_register(
    const DtIntUtilsInstruction *instruction,
    int register_id
) {
    ZydisDecodedInstruction decoded;
    ZydisDecodedOperand operands[ZYDIS_MAX_OPERAND_COUNT];

    if (register_id < 0 || register_id >= 16 ||
        !dtintutils_redecode(instruction, &decoded, operands)) {
        return 0;
    }
    return dtintutils_decoded_writes_register(&decoded, operands, register_id);
}

uint32_t dtintutils_instruction_operand_access(
    const DtIntUtilsInstruction *instruction,
    size_t operand_index
) {
    ZydisDecodedInstruction decoded;
    ZydisDecodedOperand operands[ZYDIS_MAX_OPERAND_COUNT];
    uint32_t access = DTINTUTILS_OPERAND_ACCESS_NONE;

    if (instruction == NULL || operand_index >= instruction->operand_count ||
        !dtintutils_redecode(instruction, &decoded, operands) ||
        operand_index >= decoded.operand_count_visible) {
        return access;
    }
    if ((operands[operand_index].actions & ZYDIS_OPERAND_ACTION_MASK_READ) != 0) {
        access |= DTINTUTILS_OPERAND_ACCESS_READ;
    }
    if ((operands[operand_index].actions & ZYDIS_OPERAND_ACTION_MASK_WRITE) != 0) {
        access |= DTINTUTILS_OPERAND_ACCESS_WRITE;
    }
    return access;
}

size_t dtintutils_find_rip_references(
    const uint8_t *start,
    size_t size,
    uintptr_t target,
    DtIntUtilsMnemonic mnemonic,
    const uint8_t **results,
    size_t result_capacity
) {
    ZydisDecoder decoder;
    size_t result_count = 0;
    size_t offset;

    if (start == NULL ||
        ZYAN_FAILED(ZydisDecoderInit(&decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_STACK_WIDTH_64))) {
        return 0;
    }
    for (offset = 0; offset < size;) {
        DtIntUtilsInstruction instruction;
        size_t operand_index;
        int matches = 0;

        if (!dtintutils_decode_with_decoder(&decoder, start + offset, size - offset, &instruction)) {
            ++offset;
            continue;
        }
        if (mnemonic == DTINTUTILS_MNEMONIC_ANY || instruction.mnemonic == mnemonic) {
            for (operand_index = 0; operand_index < instruction.operand_count; ++operand_index) {
                const DtIntUtilsOperand *operand = &instruction.operands[operand_index];
                if (operand->type == DTINTUTILS_OPERAND_MEMORY &&
                    operand->memory_base == DTINTUTILS_REGISTER_RIP && operand->has_absolute &&
                    operand->absolute == target) {
                    matches = 1;
                    break;
                }
            }
        }
        if (matches) {
            if (result_count < result_capacity && results != NULL) {
                results[result_count] = start + offset;
            }
            ++result_count;
        }
        offset += instruction.length;
    }
    return result_count;
}

static int dtintutils_runtime_function_equal(
    const RUNTIME_FUNCTION *left,
    const RUNTIME_FUNCTION *right
) {
    return left->BeginAddress == right->BeginAddress &&
           left->EndAddress == right->EndAddress &&
           left->UnwindData == right->UnwindData;
}

static int dtintutils_runtime_function_exists(
    const DtIntUtilsModule *module,
    const RUNTIME_FUNCTION *target
) {
    const RUNTIME_FUNCTION *runtime_functions = (const RUNTIME_FUNCTION *)module->runtime_functions;
    size_t lower = 0;
    size_t upper = module->runtime_function_count;
    size_t index;
    size_t matches = 0;

    while (lower < upper) {
        size_t middle = lower + (upper - lower) / 2;
        if (runtime_functions[middle].BeginAddress < target->BeginAddress) {
            lower = middle + 1;
        } else {
            upper = middle;
        }
    }
    for (index = lower; index < module->runtime_function_count &&
                          runtime_functions[index].BeginAddress == target->BeginAddress; ++index) {
        if (dtintutils_runtime_function_equal(&runtime_functions[index], target)) {
            ++matches;
        }
    }
    return matches == 1;
}

static int dtintutils_resolve_runtime_function_root(
    const DtIntUtilsModule *module,
    const RUNTIME_FUNCTION *input,
    RUNTIME_FUNCTION *root
) {
    RUNTIME_FUNCTION current = *input;
    size_t depth;

    for (depth = 0; depth < DTINTUTILS_MAX_UNWIND_CHAIN_DEPTH; ++depth) {
        const uint8_t *unwind;
        uint8_t version;
        uint8_t flags;
        uint8_t code_count;
        size_t code_bytes;
        size_t chain_offset;
        RUNTIME_FUNCTION parent;

        if (current.BeginAddress >= current.EndAddress || current.EndAddress > module->image_size ||
            current.UnwindData > module->image_size - 4) {
            return 0;
        }
        unwind = module->base + current.UnwindData;
        version = unwind[0] & 7u;
        flags = unwind[0] >> 3;
        if (version == 0 || version > 2) {
            return 0;
        }
        if ((flags & DTINTUTILS_UNW_FLAG_CHAININFO) == 0) {
            *root = current;
            return 1;
        }

        code_count = unwind[2];
        code_bytes = ((size_t)code_count + 1) / 2 * 4;
        chain_offset = 4 + code_bytes;
        if (current.UnwindData > module->image_size - chain_offset ||
            module->image_size - (current.UnwindData + chain_offset) < sizeof(parent)) {
            return 0;
        }
        memcpy(&parent, unwind + chain_offset, sizeof(parent));
        if (parent.BeginAddress >= parent.EndAddress || parent.EndAddress > current.BeginAddress ||
            parent.UnwindData >= module->image_size ||
            !dtintutils_runtime_function_exists(module, &parent) ||
            dtintutils_runtime_function_equal(&parent, &current)) {
            return 0;
        }
        current = parent;
    }
    return 0;
}

int dtintutils_function_containing(
    const DtIntUtilsModule *module,
    const void *address,
    DtIntUtilsFunction *function
) {
    const RUNTIME_FUNCTION *runtime_functions;
    uint32_t rva;
    RUNTIME_FUNCTION containing;
    RUNTIME_FUNCTION root;
    uint32_t end_rva;
    size_t index;
    size_t lower;
    size_t upper;
    size_t match_count = 0;

    if (module == NULL || address == NULL || function == NULL ||
        (const uint8_t *)address < module->base ||
        (const uint8_t *)address >= module->base + module->image_size) {
        return 0;
    }

    runtime_functions = (const RUNTIME_FUNCTION *)module->runtime_functions;
    rva = (uint32_t)((const uint8_t *)address - module->base);
    lower = 0;
    upper = module->runtime_function_count;
    while (lower < upper) {
        size_t middle = lower + (upper - lower) / 2;
        if (runtime_functions[middle].BeginAddress <= rva) {
            lower = middle + 1;
        } else {
            upper = middle;
        }
    }
    if (lower == 0) {
        return 0;
    }
    index = lower - 1;
    while (index > 0 && runtime_functions[index - 1].BeginAddress == runtime_functions[index].BeginAddress) {
        --index;
    }
    for (; index < module->runtime_function_count && runtime_functions[index].BeginAddress <= rva; ++index) {
        const RUNTIME_FUNCTION *candidate = &runtime_functions[index];
        if (rva < candidate->EndAddress) {
            containing = *candidate;
            ++match_count;
        }
    }
    if (match_count != 1 || !dtintutils_resolve_runtime_function_root(module, &containing, &root)) {
        return 0;
    }

    end_rva = root.EndAddress;
    for (index = 0; index < module->runtime_function_count; ++index) {
        RUNTIME_FUNCTION candidate_root;
        const RUNTIME_FUNCTION *candidate = &runtime_functions[index];

        if (candidate->BeginAddress < root.BeginAddress ||
            !dtintutils_resolve_runtime_function_root(module, candidate, &candidate_root) ||
            !dtintutils_runtime_function_equal(&candidate_root, &root)) {
            continue;
        }
        if (candidate->EndAddress > end_rva) {
            end_rva = candidate->EndAddress;
        }
    }
    if (end_rva <= root.BeginAddress || end_rva > module->image_size) {
        return 0;
    }

    function->start = module->base + root.BeginAddress;
    function->size = end_rva - root.BeginAddress;
    function->begin_rva = root.BeginAddress;
    function->end_rva = end_rva;
    return 1;
}

static int dtintutils_append_unique_address(
    const uint8_t ***values,
    size_t *count,
    size_t *capacity,
    const uint8_t *value
) {
    size_t index;

    for (index = 0; index < *count; ++index) {
        if ((*values)[index] == value) {
            return 1;
        }
    }
    if (*count == *capacity) {
        size_t next_capacity = *capacity == 0 ? 16 : *capacity * 2;
        const uint8_t **next_values;

        if (next_capacity < *capacity || next_capacity > SIZE_MAX / sizeof(*next_values)) {
            return 0;
        }
        next_values = (const uint8_t **)realloc(
            *values,
            next_capacity * sizeof(*next_values));
        if (next_values == NULL) {
            return 0;
        }
        *values = next_values;
        *capacity = next_capacity;
    }
    (*values)[(*count)++] = value;
    return 1;
}

size_t dtintutils_collect_direct_call_targets(
    const DtIntUtilsModule *module,
    const DtIntUtilsFunction *function,
    const uint8_t **results,
    size_t result_capacity
) {
    ZydisDecoder decoder;
    const uint8_t **unique_targets = NULL;
    size_t unique_count = 0;
    size_t unique_capacity = 0;
    size_t offset = 0;

    if (module == NULL || function == NULL || function->start == NULL || function->size == 0 ||
        function->start < module->base || function->start >= module->base + module->image_size ||
        function->size > (size_t)(module->base + module->image_size - function->start) ||
        ZYAN_FAILED(ZydisDecoderInit(&decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_STACK_WIDTH_64))) {
        return 0;
    }
    while (offset < function->size) {
        DtIntUtilsInstruction instruction;
        size_t advance = 1;

        if (dtintutils_decode_with_decoder(
                &decoder, function->start + offset, function->size - offset, &instruction)) {
            advance = instruction.length;
            if (instruction.mnemonic == DTINTUTILS_MNEMONIC_CALL && instruction.operand_count >= 1 &&
                instruction.operands[0].type == DTINTUTILS_OPERAND_IMMEDIATE &&
                instruction.operands[0].has_absolute &&
                dtintutils_is_executable_address(module, (const void *)(uintptr_t)instruction.operands[0].absolute)) {
                const uint8_t *target = (const uint8_t *)(uintptr_t)instruction.operands[0].absolute;
                if (!dtintutils_append_unique_address(
                        &unique_targets, &unique_count, &unique_capacity, target)) {
                    free(unique_targets);
                    return 0;
                }
            }
        }
        offset += advance;
    }
    if (results != NULL && result_capacity != 0 && unique_count != 0) {
        size_t copy_count = unique_count < result_capacity ? unique_count : result_capacity;
        memcpy(results, unique_targets, copy_count * sizeof(*results));
    }
    free(unique_targets);
    return unique_count;
}

size_t dtintutils_collect_entry_register_copies(
    const DtIntUtilsFunction *function,
    int source_register,
    int *results,
    size_t result_capacity
) {
    enum { DTINTUTILS_X64_REGISTER_RSP = 4 };
    ZydisDecoder decoder;
    uint8_t aliases[16] = {0};
    size_t result_count = 0;
    size_t offset = 0;
    int register_id;

    if (function == NULL || function->start == NULL || function->size == 0 ||
        source_register < 0 || source_register >= 16 ||
        ZYAN_FAILED(ZydisDecoderInit(
            &decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_STACK_WIDTH_64))) {
        return 0;
    }
    aliases[source_register] = 1;
    while (offset < function->size) {
        ZydisDecodedInstruction instruction;
        ZydisDecodedOperand operands[ZYDIS_MAX_OPERAND_COUNT];
        int copied_alias = 0;
        int destination = DTINTUTILS_REGISTER_NONE;

        if (ZYAN_FAILED(ZydisDecoderDecodeFull(
                &decoder, function->start + offset, function->size - offset,
                &instruction, operands))) {
            ++offset;
            continue;
        }
        if (instruction.mnemonic == ZYDIS_MNEMONIC_CALL) {
            break;
        }
        offset += instruction.length;
        if (instruction.mnemonic == ZYDIS_MNEMONIC_MOV && instruction.operand_count_visible == 2 &&
            operands[0].type == ZYDIS_OPERAND_TYPE_REGISTER && operands[0].size == 64 &&
            operands[1].type == ZYDIS_OPERAND_TYPE_REGISTER && operands[1].size == 64) {
            int source = dtintutils_register_id(operands[1].reg.value);

            destination = dtintutils_register_id(operands[0].reg.value);
            copied_alias = source >= 0 && source < 16 && aliases[source];
        }

        for (register_id = 0; register_id < 16; ++register_id) {
            if (dtintutils_decoded_writes_register(&instruction, operands, register_id)) {
                aliases[register_id] = 0;
            }
        }
        if (destination >= 0 && destination < 16 &&
            destination != DTINTUTILS_X64_REGISTER_RSP && copied_alias) {
            aliases[destination] = 1;
        }
    }

    for (register_id = 0; register_id < 16; ++register_id) {
        if (register_id == source_register || register_id == DTINTUTILS_X64_REGISTER_RSP ||
            !aliases[register_id]) {
            continue;
        }
        if (result_count < result_capacity && results != NULL) {
            results[result_count] = register_id;
        }
        ++result_count;
    }
    return result_count;
}

int dtintutils_find_unique_function_by_exact_string(
    const DtIntUtilsModule *module,
    const char *anchor,
    DtIntUtilsFunction *function,
    char *error,
    size_t error_size
) {
    const char *anchors[] = {anchor};

    return dtintutils_find_unique_functions_by_exact_strings(
        module, anchors, function, DTINTUTILS_ARRAY_COUNT(anchors), error, error_size);
}

typedef struct DtIntUtilsExactStringFunctionState {
    const char *anchor;
    size_t anchor_size;
    const uint8_t *string_address;
    size_t string_count;
    const uint8_t **references;
    size_t reference_count;
    const uint8_t *last_reference;
    DtIntUtilsFunction function;
    size_t function_count;
} DtIntUtilsExactStringFunctionState;

int dtintutils_find_unique_functions_by_exact_strings(
    const DtIntUtilsModule *module,
    const char *const *anchors,
    DtIntUtilsFunction *functions,
    size_t anchor_count,
    char *error,
    size_t error_size
) {
    ZydisDecoder decoder;
    DtIntUtilsExactStringFunctionState *states = NULL;
    const uint8_t **references = NULL;
    size_t state_index;
    size_t section_index;
    size_t text_offset;
    int result = 0;

    if (module == NULL || module->text == NULL || anchors == NULL || functions == NULL ||
        anchor_count == 0 ||
        anchor_count > SIZE_MAX / sizeof(*states) ||
        anchor_count > SIZE_MAX / DTINTUTILS_EXACT_STRING_MAX_REFERENCES / sizeof(*references)) {
        dtintutils_set_error(error, error_size, "function-by-strings arguments are invalid");
        return 0;
    }
    if (ZYAN_FAILED(ZydisDecoderInit(&decoder, ZYDIS_MACHINE_MODE_LONG_64, ZYDIS_STACK_WIDTH_64))) {
        dtintutils_set_error(error, error_size, "could not initialize the function-by-strings decoder");
        return 0;
    }

    states = (DtIntUtilsExactStringFunctionState *)calloc(anchor_count, sizeof(*states));
    references = (const uint8_t **)calloc(
        anchor_count * DTINTUTILS_EXACT_STRING_MAX_REFERENCES,
        sizeof(*references));
    if (states == NULL || references == NULL) {
        dtintutils_set_error(error, error_size, "could not allocate function-by-strings scan state");
        goto cleanup;
    }

    for (state_index = 0; state_index < anchor_count; ++state_index) {
        if (anchors[state_index] == NULL) {
            dtintutils_set_error(error, error_size, "function-by-strings anchor %zu is null", state_index);
            goto cleanup;
        }
        states[state_index].anchor = anchors[state_index];
        states[state_index].anchor_size = strlen(anchors[state_index]) + 1;
        states[state_index].references =
            references + state_index * DTINTUTILS_EXACT_STRING_MAX_REFERENCES;
    }

    for (state_index = 0; state_index < anchor_count; ++state_index) {
        DtIntUtilsExactStringFunctionState *state = &states[state_index];

        for (section_index = 0; section_index < module->section_count; ++section_index) {
            const DtIntUtilsSection *section = &module->sections[section_index];
            const uint8_t *cursor;
            const uint8_t *last;

            if ((section->characteristics & IMAGE_SCN_MEM_READ) == 0 ||
                (section->characteristics & IMAGE_SCN_MEM_EXECUTE) != 0 ||
                section->size < state->anchor_size) {
                continue;
            }
            cursor = section->start;
            last = section->start + section->size - state->anchor_size;
            while (cursor <= last) {
                const uint8_t *match = (const uint8_t *)memchr(
                    cursor, (unsigned char)state->anchor[0], (size_t)(last - cursor) + 1);

                if (match == NULL) {
                    break;
                }
                if (memcmp(match, state->anchor, state->anchor_size) == 0) {
                    state->string_address = match;
                    ++state->string_count;
                }
                cursor = match + 1;
            }
        }
    }

    for (state_index = 0; state_index < anchor_count; ++state_index) {
        const DtIntUtilsExactStringFunctionState *state = &states[state_index];

        if (state->string_count != 1) {
            dtintutils_set_error(
                error, error_size, "exact string '%s' produced %zu candidates; expected 1",
                state->anchor, state->string_count);
            goto cleanup;
        }
    }

    for (text_offset = 0; text_offset + 7 <= module->text->size; ++text_offset) {
        const uint8_t *instruction_address = module->text->start + text_offset;
        DtIntUtilsInstruction instruction;

        if ((instruction_address[0] & 0xf8u) != 0x48u || instruction_address[1] != 0x8d ||
            (instruction_address[2] & 0xc7u) != 0x05u ||
            !dtintutils_decode_with_decoder(
                &decoder, instruction_address, module->text->size - text_offset, &instruction) ||
            instruction.length != 7 || instruction.mnemonic != DTINTUTILS_MNEMONIC_LEA ||
            instruction.operand_count != 2 ||
            instruction.operands[0].type != DTINTUTILS_OPERAND_REGISTER ||
            instruction.operands[0].size_bits != 64 ||
            instruction.operands[1].type != DTINTUTILS_OPERAND_MEMORY ||
            instruction.operands[1].memory_base != DTINTUTILS_REGISTER_RIP ||
            !instruction.operands[1].has_absolute) {
            continue;
        }
        for (state_index = 0; state_index < anchor_count; ++state_index) {
            DtIntUtilsExactStringFunctionState *state = &states[state_index];

            if (instruction.operands[1].absolute != (uintptr_t)state->string_address ||
                state->last_reference == instruction_address) {
                continue;
            }
            if (state->reference_count < DTINTUTILS_EXACT_STRING_MAX_REFERENCES) {
                state->references[state->reference_count] = instruction_address;
            }
            state->last_reference = instruction_address;
            ++state->reference_count;
        }
    }

    for (state_index = 0; state_index < anchor_count; ++state_index) {
        DtIntUtilsExactStringFunctionState *state = &states[state_index];
        size_t reference_index;

        if (state->reference_count == 0 ||
            state->reference_count > DTINTUTILS_EXACT_STRING_MAX_REFERENCES) {
            dtintutils_set_error(
                error, error_size, "LEA references to '%s' produced %zu candidates; expected 1..%u",
                state->anchor, state->reference_count, DTINTUTILS_EXACT_STRING_MAX_REFERENCES);
            goto cleanup;
        }
        for (reference_index = 0; reference_index < state->reference_count; ++reference_index) {
            DtIntUtilsFunction candidate;

            if (!dtintutils_function_containing(module, state->references[reference_index], &candidate)) {
                continue;
            }
            if (state->function_count == 0) {
                state->function = candidate;
                state->function_count = 1;
            } else if (candidate.begin_rva != state->function.begin_rva ||
                       candidate.end_rva != state->function.end_rva) {
                state->function_count = 2;
                break;
            }
        }
        if (state->function_count != 1) {
            dtintutils_set_error(
                error, error_size, "containing functions for '%s' produced %zu candidates; expected 1",
                state->anchor, state->function_count);
            goto cleanup;
        }
    }

    for (state_index = 0; state_index < anchor_count; ++state_index) {
        functions[state_index] = states[state_index].function;
    }
    result = 1;

cleanup:
    free(references);
    free(states);
    return result;
}
