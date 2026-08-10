#include <windows.h>

#include <limits.h>
#include <stdlib.h>
#include <string.h>

#include "dtintutils_internal.h"
#include <MinHook.h>

static int dtintutils_minhook_ok(MH_STATUS status, MH_STATUS allowed) {
    return status == MH_OK || status == allowed;
}

int dtintutils_hook_install(
    DtIntUtilsHook *hook,
    void *target,
    void *detour,
    const DtIntUtilsPatternByte *expected,
    size_t expected_size,
    char *error,
    size_t error_size
) {
    DtIntUtilsHookRequest request;

    request.hook = hook;
    request.target = target;
    request.detour = detour;
    request.expected = expected;
    request.expected_size = expected_size;
    return dtintutils_hooks_install(&request, 1, error, error_size);
}

static MH_STATUS dtintutils_hooks_cleanup(
    const DtIntUtilsHookRequest *requests,
    size_t created_count,
    int may_be_enabled
) {
    size_t index;
    MH_STATUS first_error = MH_OK;

    if (created_count == 0) {
        return MH_OK;
    }
    if (may_be_enabled) {
        for (index = 0; index < created_count; ++index) {
            MH_STATUS status = MH_QueueDisableHook(requests[index].target);

            if (status != MH_OK && first_error == MH_OK) {
                first_error = status;
            }
        }
        {
            MH_STATUS status = MH_ApplyQueued();

            if (status != MH_OK && first_error == MH_OK) {
                first_error = status;
            }
        }
    }
    for (index = 0; index < created_count; ++index) {
        MH_STATUS status = MH_RemoveHook(requests[index].target);

        if (status == MH_OK) {
            memset(requests[index].hook, 0, sizeof(*requests[index].hook));
        } else {
            requests[index].hook->active = 1;
            if (first_error == MH_OK) {
                first_error = status;
            }
        }
    }
    return first_error;
}

int dtintutils_hooks_install(
    const DtIntUtilsHookRequest *requests,
    size_t request_count,
    char *error,
    size_t error_size
) {
    MH_STATUS status;
    size_t index;
    size_t compare_index;
    size_t created_count = 0;

    if (requests == NULL || request_count == 0) {
        dtintutils_set_error(error, error_size, "inline hook batch is empty");
        return 0;
    }
    for (index = 0; index < request_count; ++index) {
        const DtIntUtilsHookRequest *request = &requests[index];

        if (request->hook == NULL || request->target == NULL || request->detour == NULL ||
            request->hook->target != NULL || request->hook->trampoline != NULL || request->hook->active) {
            dtintutils_set_error(error, error_size,
                                 "inline hook request %zu is invalid or already initialized", index);
            return 0;
        }
        if (request->expected_size != 0 &&
            (request->expected == NULL ||
             !dtintutils_is_readable_range(request->target, request->expected_size) ||
             !dtintutils_match_pattern((const uint8_t *)request->target,
                                       request->expected, request->expected_size))) {
            dtintutils_set_error(error, error_size,
                                 "inline hook request %zu does not match its required entry pattern", index);
            return 0;
        }
        for (compare_index = 0; compare_index < index; ++compare_index) {
            if (requests[compare_index].hook == request->hook ||
                requests[compare_index].target == request->target) {
                dtintutils_set_error(error, error_size,
                                     "inline hook request %zu duplicates an earlier hook or target", index);
                return 0;
            }
        }
    }

    status = MH_Initialize();
    if (!dtintutils_minhook_ok(status, MH_ERROR_ALREADY_INITIALIZED)) {
        dtintutils_set_error(error, error_size, "MinHook initialization failed: %s", MH_StatusToString(status));
        return 0;
    }
    for (index = 0; index < request_count; ++index) {
        void *trampoline = NULL;

        status = MH_CreateHook(requests[index].target, requests[index].detour, &trampoline);
        if (status != MH_OK) {
            MH_STATUS cleanup_status = dtintutils_hooks_cleanup(requests, created_count, 0);

            if (cleanup_status == MH_OK) {
                dtintutils_set_error(error, error_size,
                                     "MinHook could not create hook request %zu: %s",
                                     index, MH_StatusToString(status));
            } else {
                dtintutils_set_error(error, error_size,
                                     "MinHook could not create hook request %zu: %s; cleanup failed: %s",
                                     index, MH_StatusToString(status), MH_StatusToString(cleanup_status));
            }
            return 0;
        }
        requests[index].hook->target = requests[index].target;
        requests[index].hook->trampoline = trampoline;
        ++created_count;
    }

    for (index = 0; index < request_count; ++index) {
        status = MH_QueueEnableHook(requests[index].target);
        if (status != MH_OK) {
            MH_STATUS cleanup_status = dtintutils_hooks_cleanup(requests, created_count, 0);

            if (cleanup_status == MH_OK) {
                dtintutils_set_error(error, error_size,
                                     "MinHook could not queue hook request %zu: %s",
                                     index, MH_StatusToString(status));
            } else {
                dtintutils_set_error(error, error_size,
                                     "MinHook could not queue hook request %zu: %s; cleanup failed: %s",
                                     index, MH_StatusToString(status), MH_StatusToString(cleanup_status));
            }
            return 0;
        }
    }
    status = MH_ApplyQueued();
    if (status != MH_OK) {
        MH_STATUS cleanup_status = dtintutils_hooks_cleanup(requests, created_count, 1);

        if (cleanup_status == MH_OK) {
            dtintutils_set_error(error, error_size,
                                 "MinHook could not apply the hook batch: %s", MH_StatusToString(status));
        } else {
            dtintutils_set_error(error, error_size,
                                 "MinHook could not apply the hook batch: %s; cleanup failed: %s",
                                 MH_StatusToString(status), MH_StatusToString(cleanup_status));
        }
        return 0;
    }

    for (index = 0; index < request_count; ++index) {
        requests[index].hook->active = 1;
    }
    if (error != NULL && error_size != 0) {
        error[0] = '\0';
    }
    return 1;
}

int dtintutils_hook_install_exact(
    DtIntUtilsHook *hook,
    void *target,
    void *detour,
    const uint8_t *expected,
    size_t expected_size,
    char *error,
    size_t error_size
) {
    if (expected == NULL || expected_size == 0 ||
        !dtintutils_is_readable_range(target, expected_size) ||
        memcmp(target, expected, expected_size) != 0) {
        dtintutils_set_error(error, error_size, "inline hook target does not match its required entry bytes");
        return 0;
    }
    return dtintutils_hook_install(hook, target, detour, NULL, 0, error, error_size);
}

int dtintutils_hook_remove(
    DtIntUtilsHook *hook,
    char *error,
    size_t error_size
) {
    MH_STATUS status;

    if (hook == NULL) {
        dtintutils_set_error(error, error_size, "inline hook state is null");
        return 0;
    }
    if (!hook->active) {
        return 1;
    }

    status = MH_DisableHook(hook->target);
    if (!dtintutils_minhook_ok(status, MH_ERROR_DISABLED)) {
        dtintutils_set_error(error, error_size, "MinHook could not disable the hook: %s", MH_StatusToString(status));
        return 0;
    }
    status = MH_RemoveHook(hook->target);
    if (status != MH_OK) {
        dtintutils_set_error(error, error_size, "MinHook could not remove the hook: %s", MH_StatusToString(status));
        return 0;
    }

    memset(hook, 0, sizeof(*hook));
    if (error != NULL && error_size != 0) {
        error[0] = '\0';
    }
    return 1;
}

static void *dtintutils_allocate_near(const uint8_t *target) {
    SYSTEM_INFO information;
    uintptr_t granularity;
    uintptr_t target_value = (uintptr_t)target;
    uintptr_t lower;
    uintptr_t upper;
    uintptr_t distance;

    GetSystemInfo(&information);
    granularity = information.dwAllocationGranularity;
    lower = target_value > UINT64_C(0x7fff0000) ? target_value - UINT64_C(0x7fff0000) : 0;
    upper = target_value <= UINTPTR_MAX - UINT64_C(0x7fff0000)
        ? target_value + UINT64_C(0x7fff0000)
        : UINTPTR_MAX;
    lower = (lower + granularity - 1) & ~(granularity - 1);
    upper &= ~(granularity - 1);

    for (distance = 0; distance <= UINT64_C(0x7fff0000); distance += granularity) {
        uintptr_t candidates[2];
        size_t candidate_count = 0;
        size_t index;

        if (target_value <= UINTPTR_MAX - distance) {
            candidates[candidate_count++] = target_value + distance;
        }
        if (distance != 0 && target_value >= distance) {
            candidates[candidate_count++] = target_value - distance;
        }
        for (index = 0; index < candidate_count; ++index) {
            uintptr_t address = candidates[index] & ~(granularity - 1);
            void *allocation;
            if (address < lower || address > upper) {
                continue;
            }
            allocation = VirtualAlloc((void *)address, granularity, MEM_RESERVE | MEM_COMMIT,
                                      PAGE_EXECUTE_READWRITE);
            if (allocation != NULL) {
                return allocation;
            }
        }
    }
    return NULL;
}

static int dtintutils_atomic_replace_word(
    uintptr_t word_address,
    int64_t expected,
    int64_t replacement,
    char *error,
    size_t error_size
) {
    DWORD old_protection;
    LONG64 observed;
    LONG64 rollback_observed;
    DWORD ignored;
    DWORD failure;

    if (!VirtualProtect((void *)word_address, sizeof(LONG64), PAGE_EXECUTE_READWRITE, &old_protection)) {
        dtintutils_set_error(error, error_size, "VirtualProtect(call patch) failed with Win32 error %lu",
                            GetLastError());
        return 0;
    }
    observed = InterlockedCompareExchange64((volatile LONG64 *)word_address, replacement, expected);
    if (observed != expected) {
        failure = GetLastError();
        if (!VirtualProtect((void *)word_address, sizeof(LONG64), old_protection, &ignored)) {
            dtintutils_set_error(error, error_size,
                                "the aligned call-site word changed and restoring its protection failed with Win32 error %lu",
                                GetLastError());
            return 0;
        }
        SetLastError(failure);
        dtintutils_set_error(error, error_size, "the aligned call-site word changed before the atomic patch");
        return 0;
    }

    if (FlushInstructionCache(GetCurrentProcess(), (const void *)word_address, sizeof(LONG64)) &&
        VirtualProtect((void *)word_address, sizeof(LONG64), old_protection, &ignored)) {
        return 1;
    }

    failure = GetLastError();
    rollback_observed = InterlockedCompareExchange64((volatile LONG64 *)word_address, expected, replacement);
    if (rollback_observed != replacement ||
        !FlushInstructionCache(GetCurrentProcess(), (const void *)word_address, sizeof(LONG64))) {
        RaiseFailFastException(NULL, NULL, 0);
    }
    if (!VirtualProtect((void *)word_address, sizeof(LONG64), old_protection, &ignored)) {
        dtintutils_set_error(error, error_size,
                            "the call patch was rolled back, but restoring its protection failed with Win32 error %lu",
                            GetLastError());
        return 0;
    }

    dtintutils_set_error(error, error_size,
                        "the call patch was rolled back after a cache flush or protection restore failure with Win32 error %lu",
                        failure);
    return 0;
}

int dtintutils_call_patch_install(
    DtIntUtilsCallPatch *patch,
    uint8_t *call_site,
    void *detour,
    void *expected_original_target,
    char *error,
    size_t error_size
) {
    DtIntUtilsInstruction instruction;
    void *original_target;
    HMODULE pinned_module;
    uint8_t *relay;
    DWORD relay_old_protection;
    uintptr_t word_address;
    size_t call_offset;
    uint8_t original_bytes[sizeof(LONG64)];
    uint8_t patched_bytes[sizeof(LONG64)];
    int64_t original_word;
    int64_t patched_word;
    intptr_t relay_displacement;
    int32_t displacement;

    if (patch == NULL || call_site == NULL || detour == NULL || patch->active) {
        dtintutils_set_error(error, error_size, "relative call patch arguments or state are invalid");
        return 0;
    }
    if (!dtintutils_decode(call_site, 5, &instruction) || instruction.length != 5 ||
        instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL || instruction.operand_count < 1 ||
        instruction.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
        !instruction.operands[0].has_absolute) {
        dtintutils_set_error(error, error_size, "call patch target is not a direct five-byte CALL instruction");
        return 0;
    }
    original_target = (void *)(uintptr_t)instruction.operands[0].absolute;
    if (expected_original_target != NULL && original_target != expected_original_target) {
        dtintutils_set_error(error, error_size, "call patch original target does not match the validated target");
        return 0;
    }
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
                            (LPCWSTR)(uintptr_t)detour, &pinned_module)) {
        dtintutils_set_error(error, error_size, "failed to pin the detour module with Win32 error %lu", GetLastError());
        return 0;
    }

    relay = (uint8_t *)dtintutils_allocate_near(call_site);
    if (relay == NULL) {
        dtintutils_set_error(error, error_size, "could not allocate a relay within rel32 range");
        return 0;
    }
    relay[0] = 0x48;
    relay[1] = 0xb8;
    memcpy(relay + 2, &detour, sizeof(detour));
    relay[10] = 0xff;
    relay[11] = 0xe0;
    if (!FlushInstructionCache(GetCurrentProcess(), relay, 12) ||
        !VirtualProtect(relay, 12, PAGE_EXECUTE_READ, &relay_old_protection)) {
        DWORD native_error = GetLastError();
        VirtualFree(relay, 0, MEM_RELEASE);
        dtintutils_set_error(error, error_size, "could not finalize the call relay: Win32 error %lu", native_error);
        return 0;
    }

    relay_displacement = (intptr_t)((uintptr_t)relay - (uintptr_t)(call_site + 5));
    if (relay_displacement < INT32_MIN || relay_displacement > INT32_MAX) {
        VirtualFree(relay, 0, MEM_RELEASE);
        dtintutils_set_error(error, error_size, "allocated call relay is outside rel32 range");
        return 0;
    }
    displacement = (int32_t)relay_displacement;

    word_address = (uintptr_t)call_site & ~(uintptr_t)7;
    call_offset = (size_t)((uintptr_t)call_site - word_address);
    if (call_offset + 5 > sizeof(LONG64)) {
        VirtualFree(relay, 0, MEM_RELEASE);
        dtintutils_set_error(error, error_size, "direct CALL is not contained in one aligned eight-byte word");
        return 0;
    }
    memcpy(original_bytes, (const void *)word_address, sizeof(original_bytes));
    memcpy(patched_bytes, original_bytes, sizeof(patched_bytes));
    if (original_bytes[call_offset] != 0xe8) {
        VirtualFree(relay, 0, MEM_RELEASE);
        dtintutils_set_error(error, error_size, "direct CALL opcode changed before installation");
        return 0;
    }
    memcpy(patched_bytes + call_offset + 1, &displacement, sizeof(displacement));
    memcpy(&original_word, original_bytes, sizeof(original_word));
    memcpy(&patched_word, patched_bytes, sizeof(patched_word));

    if (!dtintutils_atomic_replace_word(word_address, original_word, patched_word, error, error_size)) {
        VirtualFree(relay, 0, MEM_RELEASE);
        return 0;
    }

    patch->call_site = call_site;
    patch->original_target = original_target;
    patch->relay = relay;
    patch->word_address = word_address;
    patch->original_word = original_word;
    patch->patched_word = patched_word;
    patch->active = 1;
    if (error != NULL && error_size != 0) {
        error[0] = '\0';
    }
    return 1;
}

int dtintutils_call_patch_remove(
    DtIntUtilsCallPatch *patch,
    char *error,
    size_t error_size
) {
    if (patch == NULL) {
        dtintutils_set_error(error, error_size, "relative call patch state is null");
        return 0;
    }
    if (!patch->active) {
        return 1;
    }
    if (!dtintutils_atomic_replace_word(
            patch->word_address,
            patch->patched_word,
            patch->original_word,
            error,
            error_size)) {
        return 0;
    }

    /* A thread can still be executing the relay after the call site is restored. */
    memset(patch, 0, sizeof(*patch));
    if (error != NULL && error_size != 0) {
        error[0] = '\0';
    }
    return 1;
}
