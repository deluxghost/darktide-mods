#include <windows.h>

#include <stdlib.h>
#include <string.h>

#include "dtintutils_locator_internal.h"

static int dtintutils_locator_append_call_targets(
    const DtIntUtilsModule *module,
    const DtIntUtilsCandidateList *input,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    size_t index;

    for (index = 0; index < input->count; ++index) {
        DtIntUtilsFunction function;
        const uint8_t **targets;
        size_t count;

        if (!dtintutils_function_containing(module, input->items[index], &function)) {
            continue;
        }
        count = dtintutils_collect_direct_call_targets(module, &function, NULL, 0);
        if (count == 0) {
            continue;
        }
        if (count > DTINTUTILS_LOCATOR_MAX_CANDIDATES) {
            dtintutils_locator_set_error(
                error, error_size, "function call scan produced %zu raw candidates; limit is %u",
                count, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
            return 0;
        }
        targets = (const uint8_t **)malloc(count * sizeof(*targets));
        if (targets == NULL) {
            dtintutils_locator_set_error(
                error, error_size, "could not allocate %zu function call candidates", count);
            return 0;
        }
        count = dtintutils_collect_direct_call_targets(module, &function, targets, count);
        if (!dtintutils_locator_list_append_hits(output, targets, count, error, error_size)) {
            free(targets);
            return 0;
        }
        free(targets);
    }
    return 1;
}

static int dtintutils_locator_append_function_rip_targets(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    const DtIntUtilsCandidateList *input,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    size_t input_index;

    for (input_index = 0; input_index < input->count; ++input_index) {
        DtIntUtilsFunction function;
        size_t offset = 0;

        if (!dtintutils_function_containing(module, input->items[input_index], &function)) {
            continue;
        }
        while (offset < function.size) {
            DtIntUtilsInstruction instruction;
            size_t operand_index;

            if (!dtintutils_decode(function.start + offset, function.size - offset, &instruction)) {
                ++offset;
                continue;
            }
            offset += instruction.length;
            if (step->mnemonic != DTINTUTILS_MNEMONIC_ANY &&
                instruction.mnemonic != (DtIntUtilsMnemonic)step->mnemonic) {
                continue;
            }
            for (operand_index = 0; operand_index < instruction.operand_count; ++operand_index) {
                const DtIntUtilsOperand *operand = &instruction.operands[operand_index];
                const uint8_t *target;

                if (operand->type != DTINTUTILS_OPERAND_MEMORY ||
                    operand->memory_base != DTINTUTILS_REGISTER_RIP || !operand->has_absolute) {
                    continue;
                }
                target = (const uint8_t *)(uintptr_t)operand->absolute;
                if (dtintutils_section_for_address(module, target) != NULL &&
                    !dtintutils_locator_list_append_unique(output, target, error, error_size)) {
                    return 0;
                }
            }
        }
    }
    return 1;
}

static int dtintutils_locator_filter_call_targets(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    const DtIntUtilsCandidateList *input,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    DtIntUtilsFunction function;
    const uint8_t **targets;
    size_t target_count;
    size_t input_index;
    size_t target_index;

    if (step->text == NULL ||
        !dtintutils_function_containing(module, step->text, &function)) {
        dtintutils_locator_set_error(error, error_size, "call-target filter function is invalid");
        return 0;
    }
    target_count = dtintutils_collect_direct_call_targets(module, &function, NULL, 0);
    if (target_count == 0) {
        return 1;
    }
    if (target_count > DTINTUTILS_LOCATOR_MAX_CANDIDATES) {
        dtintutils_locator_set_error(
            error, error_size, "call-target filter produced %zu raw candidates; limit is %u",
            target_count, DTINTUTILS_LOCATOR_MAX_CANDIDATES);
        return 0;
    }
    targets = (const uint8_t **)malloc(target_count * sizeof(*targets));
    if (targets == NULL) {
        dtintutils_locator_set_error(
            error, error_size, "could not allocate %zu call-target filter candidates", target_count);
        return 0;
    }
    target_count = dtintutils_collect_direct_call_targets(
        module, &function, targets, target_count);
    for (input_index = 0; input_index < input->count; ++input_index) {
        for (target_index = 0; target_index < target_count; ++target_index) {
            if (input->items[input_index] != targets[target_index]) {
                continue;
            }
            if (!dtintutils_locator_list_append_unique(
                    output, input->items[input_index], error, error_size)) {
                free(targets);
                return 0;
            }
            break;
        }
    }
    free(targets);
    return 1;
}

static int dtintutils_locator_transform_step(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocatorStep *step,
    const DtIntUtilsCandidateList *input,
    DtIntUtilsCandidateList *output,
    char *error,
    size_t error_size
) {
    DtIntUtilsResolvedPattern pattern;
    const DtIntUtilsSection *section;
    size_t index;

    switch (step->operation) {
        case DTINTUTILS_LOCATOR_FIND_POINTER_SLOTS:
            for (index = 0; index < input->count; ++index) {
                if (!dtintutils_locator_append_pointer_slots(module, (uintptr_t)input->items[index], output, error, error_size)) {
                    return 0;
                }
            }
            return 1;

        case DTINTUTILS_LOCATOR_FIND_RIP_REFERENCES:
            section = dtintutils_section(module, step->section != NULL ? step->section : ".text");
            if (section == NULL) {
                dtintutils_locator_set_error(error, error_size, "RIP-reference section '%s' does not exist",
                                  step->section != NULL ? step->section : ".text");
                return 0;
            }
            for (index = 0; index < input->count; ++index) {
                if (!dtintutils_locator_append_rip_references(
                        section,
                        (uintptr_t)input->items[index],
                        (DtIntUtilsMnemonic)step->mnemonic,
                        output,
                        error,
                        error_size)) {
                    return 0;
                }
            }
            return 1;

        case DTINTUTILS_LOCATOR_CONTAINING_FUNCTIONS:
            for (index = 0; index < input->count; ++index) {
                DtIntUtilsFunction function;
                if (dtintutils_function_containing(module, input->items[index], &function) &&
                    !dtintutils_locator_list_append_unique(output, function.start, error, error_size)) {
                    return 0;
                }
            }
            return 1;

        case DTINTUTILS_LOCATOR_FIND_PATTERN_NEAR:
            if (step->range_size == 0 || !dtintutils_locator_resolve_pattern(step, &pattern, error, error_size)) {
                if (step->range_size == 0) {
                    dtintutils_locator_set_error(error, error_size, "nearby pattern search range is zero");
                }
                return 0;
            }
            for (index = 0; index < input->count; ++index) {
                const uint8_t *start;
                size_t size;
                if (dtintutils_locator_candidate_range(
                        module, input->items[index], 0, step->displacement, step->range_size, &start, &size) &&
                    !dtintutils_locator_append_pattern_hits(output, start, size, &pattern, error, error_size)) {
                    return 0;
                }
            }
            return 1;

        case DTINTUTILS_LOCATOR_ADD_OFFSET:
            for (index = 0; index < input->count; ++index) {
                const uint8_t *address;
                if (dtintutils_locator_address_with_displacement(module, input->items[index], step->displacement, &address) &&
                    !dtintutils_locator_list_append_unique(output, address, error, error_size)) {
                    return 0;
                }
            }
            return 1;

        case DTINTUTILS_LOCATOR_REQUIRE_DIRECT_CALL:
        case DTINTUTILS_LOCATOR_RESOLVE_DIRECT_CALL:
            for (index = 0; index < input->count; ++index) {
                const uint8_t *target;
                if (dtintutils_locator_direct_call_target(module, input->items[index], &target) &&
                    !dtintutils_locator_list_append_unique(
                        output,
                        step->operation == DTINTUTILS_LOCATOR_RESOLVE_DIRECT_CALL ? target : input->items[index],
                        error,
                        error_size)) {
                    return 0;
                }
            }
            return 1;

        case DTINTUTILS_LOCATOR_COLLECT_FUNCTION_CALL_TARGETS:
            return dtintutils_locator_append_call_targets(
                module, input, output, error, error_size);

        case DTINTUTILS_LOCATOR_COLLECT_FUNCTION_RIP_TARGETS:
            return dtintutils_locator_append_function_rip_targets(
                module, step, input, output, error, error_size);

        case DTINTUTILS_LOCATOR_FILTER_CALL_TARGETS_OF:
            return dtintutils_locator_filter_call_targets(
                module, step, input, output, error, error_size);

        case DTINTUTILS_LOCATOR_FILTER_PATTERN_NEAR:
        case DTINTUTILS_LOCATOR_FILTER_FUNCTION_PATTERN:
            if (!dtintutils_locator_resolve_pattern(step, &pattern, error, error_size)) {
                return 0;
            }
            for (index = 0; index < input->count; ++index) {
                const uint8_t *start;
                size_t size;
                if (dtintutils_locator_candidate_range(
                        module,
                        input->items[index],
                        step->operation == DTINTUTILS_LOCATOR_FILTER_FUNCTION_PATTERN,
                        step->displacement,
                        step->range_size,
                        &start,
                        &size) &&
                    dtintutils_find_pattern(start, size, pattern.bytes, pattern.size, NULL, 0) != 0 &&
                    !dtintutils_locator_list_append_unique(output, input->items[index], error, error_size)) {
                    return 0;
                }
            }
            return 1;

        case DTINTUTILS_LOCATOR_FILTER_SECTION:
            if (step->section == NULL && step->required_section_flags == 0) {
                dtintutils_locator_set_error(error, error_size, "section filter requires a section name or required flags");
                return 0;
            }
            if ((step->required_section_flags & ~(DTINTUTILS_SECTION_READABLE |
                  DTINTUTILS_SECTION_WRITABLE | DTINTUTILS_SECTION_EXECUTABLE)) != 0) {
                dtintutils_locator_set_error(error, error_size, "section filter contains unknown required flags");
                return 0;
            }
            for (index = 0; index < input->count; ++index) {
                if (dtintutils_locator_section_matches(dtintutils_section_for_address(module, input->items[index]), step) &&
                    !dtintutils_locator_list_append_unique(output, input->items[index], error, error_size)) {
                    return 0;
                }
            }
            return 1;

        case DTINTUTILS_LOCATOR_FILTER_FUNCTION_ENTRIES:
            for (index = 0; index < input->count; ++index) {
                DtIntUtilsFunction function;
                if (dtintutils_function_containing(module, input->items[index], &function) &&
                    function.start == input->items[index] &&
                    !dtintutils_locator_list_append_unique(output, input->items[index], error, error_size)) {
                    return 0;
                }
            }
            return 1;

        default:
            dtintutils_locator_set_error(error, error_size, "unknown locator operation %u", step->operation);
            return 0;
    }
}

static int dtintutils_locator_validate_step_count(
    const DtIntUtilsLocator *locator,
    size_t step_index,
    const DtIntUtilsLocatorStep *step,
    size_t count,
    char *error,
    size_t error_size
) {
    if (count < step->minimum_results ||
        (step->maximum_results != 0 && count > step->maximum_results)) {
        if (step->maximum_results == 0) {
            dtintutils_locator_set_error(
                error,
                error_size,
                "locator '%s' step %zu (%s) produced %zu unique candidates; expected at least %u",
                dtintutils_locator_name(locator),
                step_index + 1,
                dtintutils_locator_operation_name(step->operation),
                count,
                step->minimum_results);
        } else {
            dtintutils_locator_set_error(
                error,
                error_size,
                "locator '%s' step %zu (%s) produced %zu unique candidates; expected %u..%u",
                dtintutils_locator_name(locator),
                step_index + 1,
                dtintutils_locator_operation_name(step->operation),
                count,
                step->minimum_results,
                step->maximum_results);
        }
        return 0;
    }
    return 1;
}

static int dtintutils_locator_execute(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocator *locator,
    DtIntUtilsCandidateList *result,
    char *error,
    size_t error_size
) {
    DtIntUtilsCandidateList current = {0};
    size_t step_index;

    if (module == NULL || locator == NULL || locator->steps == NULL || locator->step_count == 0 ||
        locator->step_count > DTINTUTILS_LOCATOR_MAX_STEPS) {
        dtintutils_locator_set_error(error, error_size, "locator arguments or step count are invalid");
        return 0;
    }
    for (step_index = 0; step_index < locator->step_count; ++step_index) {
        const DtIntUtilsLocatorStep *step = &locator->steps[step_index];
        DtIntUtilsCandidateList next = {0};
        int source_operation = step->operation == DTINTUTILS_LOCATOR_FIND_EXACT_STRING ||
            step->operation == DTINTUTILS_LOCATOR_FIND_STRING_PREFIX ||
            step->operation == DTINTUTILS_LOCATOR_FIND_PATTERN ||
            step->operation == DTINTUTILS_LOCATOR_SOURCE_ADDRESS;
        int succeeded;

        if (step->reserved != 0 ||
            (step->maximum_results != 0 && step->maximum_results < step->minimum_results)) {
            dtintutils_locator_set_error(error, error_size, "locator '%s' step %zu has invalid bounds or reserved fields",
                              dtintutils_locator_name(locator), step_index + 1);
            dtintutils_locator_list_free(&current);
            return 0;
        }
        if ((step_index == 0) != source_operation) {
            dtintutils_locator_set_error(error, error_size,
                              "locator '%s' must have exactly one source operation as its first step",
                              dtintutils_locator_name(locator));
            dtintutils_locator_list_free(&current);
            return 0;
        }

        switch (step->operation) {
            case DTINTUTILS_LOCATOR_FIND_EXACT_STRING:
                succeeded = dtintutils_locator_find_exact_string(module, step, &next, error, error_size);
                break;
            case DTINTUTILS_LOCATOR_FIND_STRING_PREFIX:
                succeeded = dtintutils_locator_find_string_prefix(module, step, &next, error, error_size);
                break;
            case DTINTUTILS_LOCATOR_FIND_PATTERN:
                succeeded = dtintutils_locator_find_pattern_source(module, step, &next, error, error_size);
                break;
            case DTINTUTILS_LOCATOR_SOURCE_ADDRESS:
                if (step->text == NULL ||
                    dtintutils_section_for_address(module, step->text) == NULL) {
                    dtintutils_locator_set_error(
                        error, error_size, "locator '%s' address source is outside the module",
                        dtintutils_locator_name(locator));
                    succeeded = 0;
                } else {
                    succeeded = dtintutils_locator_list_append_unique(
                        &next, (const uint8_t *)step->text, error, error_size);
                }
                break;
            default:
                succeeded = dtintutils_locator_transform_step(module, step, &current, &next, error, error_size);
                break;
        }
        if (!succeeded || !dtintutils_locator_validate_step_count(locator, step_index, step, next.count, error, error_size)) {
            dtintutils_locator_list_free(&next);
            dtintutils_locator_list_free(&current);
            return 0;
        }
        dtintutils_locator_list_free(&current);
        current = next;
    }
    *result = current;
    return 1;
}

static int dtintutils_locator_finish_unique_address(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocator *locator,
    DtIntUtilsLocatorValidator validator,
    void *validator_context,
    const uint8_t **address,
    char *error,
    size_t error_size
) {
    DtIntUtilsCandidateList candidates = {0};
    const uint8_t *accepted = NULL;
    size_t accepted_count = 0;
    size_t index;

    if (address == NULL) {
        dtintutils_locator_set_error(error, error_size, "locator address output is null");
        return 0;
    }
    *address = NULL;
    if (!dtintutils_locator_execute(module, locator, &candidates, error, error_size)) {
        return 0;
    }
    if (validator == NULL) {
        accepted_count = candidates.count;
        accepted = candidates.count == 1 ? candidates.items[0] : NULL;
    } else {
        for (index = 0; index < candidates.count; ++index) {
            if (validator(module, candidates.items[index], validator_context)) {
                accepted = candidates.items[index];
                ++accepted_count;
            }
        }
    }
    if (accepted_count != 1) {
        if (validator == NULL) {
            dtintutils_locator_set_error(error, error_size, "locator '%s' ended with %zu candidates; expected exactly 1",
                              dtintutils_locator_name(locator), candidates.count);
        } else {
            dtintutils_locator_set_error(
                error,
                error_size,
                "locator '%s' validator accepted %zu of %zu candidates; expected exactly 1",
                dtintutils_locator_name(locator),
                accepted_count,
                candidates.count);
        }
        dtintutils_locator_list_free(&candidates);
        return 0;
    }
    *address = accepted;
    dtintutils_locator_list_free(&candidates);
    if (error != NULL && error_size != 0) {
        error[0] = '\0';
    }
    return 1;
}

int dtintutils_locate_unique_address(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocator *locator,
    const uint8_t **address,
    char *error,
    size_t error_size
) {
    return dtintutils_locator_finish_unique_address(module, locator, NULL, NULL, address, error, error_size);
}

int dtintutils_locate_unique_address_with_validator(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocator *locator,
    DtIntUtilsLocatorValidator validator,
    void *validator_context,
    const uint8_t **address,
    char *error,
    size_t error_size
) {
    if (validator == NULL) {
        dtintutils_locator_set_error(error, error_size, "locator validator is null");
        return 0;
    }
    return dtintutils_locator_finish_unique_address(
        module,
        locator,
        validator,
        validator_context,
        address,
        error,
        error_size);
}

int dtintutils_locate_unique_function(
    const DtIntUtilsModule *module,
    const DtIntUtilsLocator *locator,
    DtIntUtilsFunction *function,
    char *error,
    size_t error_size
) {
    const uint8_t *address;

    if (function == NULL) {
        dtintutils_locator_set_error(error, error_size, "locator function output is null");
        return 0;
    }
    memset(function, 0, sizeof(*function));
    if (!dtintutils_locate_unique_address(module, locator, &address, error, error_size)) {
        return 0;
    }
    if (!dtintutils_function_containing(module, address, function) || function->start != address) {
        dtintutils_locator_set_error(error, error_size, "locator '%s' did not end at a unique .pdata function entry",
                          dtintutils_locator_name(locator));
        memset(function, 0, sizeof(*function));
        return 0;
    }
    if (error != NULL && error_size != 0) {
        error[0] = '\0';
    }
    return 1;
}
