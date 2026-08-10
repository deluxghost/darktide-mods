#include "runtime_internal.h"

#include <string.h>
#include <wchar.h>

static int sa_function_has_request_stride(const SaImage *image, const uint8_t *address) {
    SaFunction function;
    size_t offset;

    if (!dtintutils_function_containing(image, address, &function)) {
        return 0;
    }
    for (offset = 0; offset + 7 <= function.size; ++offset) {
        const uint8_t *instruction = function.start + offset;
        DtIntUtilsInstruction decoded;

        if (dtintutils_decode(instruction, function.size - offset, &decoded) &&
            decoded.mnemonic == DTINTUTILS_MNEMONIC_IMUL && decoded.operand_count >= 3 &&
            decoded.operands[2].type == DTINTUTILS_OPERAND_IMMEDIATE &&
            decoded.operands[2].immediate == 0xd8) {
            return 1;
        }
    }
    return 0;
}

int sa_locate_queue_push(
    const SaImage *image,
    const SaFunction *queue_request,
    const SaFunction *input_transfer,
    const uint8_t **queue_push,
    char *error,
    size_t error_size
) {
    const uint8_t *request_targets[64];
    const uint8_t *transfer_targets[64];
    size_t request_count = dtintutils_collect_direct_call_targets(
        image, queue_request, request_targets, SA_ARRAY_COUNT(request_targets));
    size_t transfer_count = dtintutils_collect_direct_call_targets(
        image, input_transfer, transfer_targets, SA_ARRAY_COUNT(transfer_targets));
    size_t request_index;
    size_t transfer_index;
    size_t matches = 0;

    if (request_count == 0 || request_count > SA_ARRAY_COUNT(request_targets) || transfer_count == 0 ||
        transfer_count > SA_ARRAY_COUNT(transfer_targets)) {
        sa_set_error(error, error_size, "resource queue functions have an unbounded direct-call set");
        return 0;
    }
    for (request_index = 0; request_index < request_count; ++request_index) {
        for (transfer_index = 0; transfer_index < transfer_count; ++transfer_index) {
            if (request_targets[request_index] != transfer_targets[transfer_index] ||
                !sa_function_has_request_stride(image, request_targets[request_index])) {
                continue;
            }
            *queue_push = request_targets[request_index];
            ++matches;
        }
    }
    if (matches != 1) {
        sa_set_error(error, error_size,
                     "queue_request and input transfer share %zu request-copy helpers; expected 1", matches);
        return 0;
    }
    return 1;
}

int sa_analyze_input_queue_offset(
    const SaFunction *queue_request,
    const uint8_t *queue_push,
    uint32_t *input_queue_offset,
    char *error,
    size_t error_size
) {
    int worker_registers[8];
    size_t worker_count = sa_collect_argument_registers(queue_request, 1, worker_registers,
                                                        SA_ARRAY_COUNT(worker_registers));
    size_t offset;
    size_t matches = 0;

    if (worker_count == 0 || worker_count > SA_ARRAY_COUNT(worker_registers)) {
        sa_set_error(error, error_size, "queue_request has no bounded worker-register set");
        return 0;
    }
    for (offset = 0; offset + 5 <= queue_request->size; ++offset) {
        const uint8_t *call = queue_request->start + offset;
        const uint8_t *target;
        const uint8_t *cursor;
        const uint8_t *search_start;
        DtIntUtilsInstruction decoded;

        if (!dtintutils_decode(call, queue_request->size - offset, &decoded) || decoded.length != 5 ||
            decoded.mnemonic != DTINTUTILS_MNEMONIC_CALL || decoded.operand_count != 1 ||
            decoded.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
            !decoded.operands[0].has_absolute) {
            continue;
        }
        target = (const uint8_t *)(uintptr_t)decoded.operands[0].absolute;
        if (target != queue_push) {
            continue;
        }
        search_start = call - queue_request->start > 48 ? call - 48 : queue_request->start;
        for (cursor = search_start; cursor < call; ++cursor) {
            SaMemoryOperand operand;
            int destination;
            size_t length;

            if (!sa_parse_reg_memory_instruction(cursor, call, 0x8d, 1, &destination, &operand, &length) ||
                destination != 1 || operand.displacement <= 0 || operand.displacement > 0x10000 ||
                !sa_register_in_set(operand.base_register, worker_registers, worker_count)) {
                continue;
            }
            *input_queue_offset = (uint32_t)operand.displacement;
            ++matches;
        }
    }
    if (matches != 1) {
        sa_set_error(error, error_size, "queue_request input-queue analysis produced %zu candidates; expected 1",
                     matches);
        return 0;
    }
    return 1;
}

int sa_validate_queue_read_shape(
    const SaFunction *queue_read,
    SaQueueReadShape *shape,
    char *error,
    size_t error_size
) {
    int worker_registers[8];
    int request_registers[8];
    size_t worker_count = sa_collect_argument_registers(queue_read, 1, worker_registers,
                                                        SA_ARRAY_COUNT(worker_registers));
    size_t request_count = sa_collect_argument_registers(queue_read, 2, request_registers,
                                                         SA_ARRAY_COUNT(request_registers));
    size_t offset;
    size_t io_loader_loads = 0;
    int package_id_load = 0;
    int type_hash_load = 0;
    int name_hash_load = 0;
    int data_access = 0;
    int size_access = 0;
    int handle_access = 0;
    int worker_allocate_slot = 0;
    int io_open_slot = 0;
    int io_size_slot = 0;
    int io_read_slot = 0;

    if (worker_count == 0 || worker_count > SA_ARRAY_COUNT(worker_registers) || request_count == 0 ||
        request_count > SA_ARRAY_COUNT(request_registers)) {
        sa_set_error(error, error_size, "queue_read has unbounded worker or request register candidates");
        return 0;
    }

    for (offset = 0; offset < queue_read->size; ++offset) {
        const uint8_t *instruction = queue_read->start + offset;
        const uint8_t *limit = queue_read->start + queue_read->size;
        SaMemoryOperand operand;
        int reg;
        size_t length;

        if (sa_parse_reg_memory_instruction(instruction, limit, 0x8b, 0, &reg, &operand, &length)) {
            if (sa_register_in_set(operand.base_register, worker_registers, worker_count) &&
                operand.displacement == 0x228) {
                ++io_loader_loads;
            }
            if (sa_register_in_set(operand.base_register, request_registers, request_count)) {
                package_id_load |= operand.displacement == 4;
                type_hash_load |= operand.displacement == 8;
                name_hash_load |= operand.displacement == 0x10;
                data_access |= operand.displacement == 0xa8;
                size_access |= operand.displacement == 0xb0;
                handle_access |= operand.displacement == 0xc0;
            }
            worker_allocate_slot |= operand.displacement == 0x80;
            io_open_slot |= operand.displacement == 8;
            io_size_slot |= operand.displacement == 0x20;
            io_read_slot |= operand.displacement == 0x28;
        }
        if (sa_parse_memory_reg_instruction(instruction, limit, 0x89, 1, &operand, &reg, &length) &&
            sa_register_in_set(operand.base_register, request_registers, request_count)) {
            data_access |= operand.displacement == 0xa8;
            size_access |= operand.displacement == 0xb0;
            handle_access |= operand.displacement == 0xc0;
        }
        {
            DtIntUtilsInstruction decoded;
            if (dtintutils_decode(instruction, (size_t)(limit - instruction), &decoded) &&
                decoded.mnemonic == DTINTUTILS_MNEMONIC_CALL && decoded.operand_count == 1 &&
                decoded.operands[0].type == DTINTUTILS_OPERAND_MEMORY) {
                worker_allocate_slot |= decoded.operands[0].displacement == 0x80;
                io_read_slot |= decoded.operands[0].displacement == 0x28;
            }
        }
    }

    if (io_loader_loads < 3 || !package_id_load || !type_hash_load || !name_hash_load || !data_access ||
        !size_access || !handle_access || !worker_allocate_slot || !io_open_slot || !io_size_slot ||
        !io_read_slot) {
        sa_set_error(error, error_size, "queue_read no longer matches the validated external-read contract");
        return 0;
    }

    shape->package_id_offset = 4;
    shape->type_hash_offset = 8;
    shape->name_hash_offset = 0x10;
    shape->data_offset = 0xa8;
    shape->size_offset = 0xb0;
    shape->handle_offset = 0xc0;
    shape->io_loader_offset = 0x228;
    shape->worker_allocate_slot = 0x80;
    shape->io_open_slot = 8;
    shape->io_size_slot = 0x20;
    shape->io_read_slot = 0x28;
    return 1;
}

static int sa_function_has_indirect_call_slot(const SaFunction *function, int64_t slot) {
    size_t offset;

    for (offset = 0; offset < function->size; ++offset) {
        DtIntUtilsInstruction decoded;

        if (!dtintutils_decode(function->start + offset, function->size - offset, &decoded) ||
            decoded.mnemonic != DTINTUTILS_MNEMONIC_CALL || decoded.operand_count != 1 ||
            decoded.operands[0].type != DTINTUTILS_OPERAND_MEMORY) {
            continue;
        }
        if (decoded.operands[0].displacement == slot) {
            return 1;
        }
    }
    return 0;
}

int sa_validate_direct_storage_hook_shapes(
    const SaFunction *submit,
    const SaFunction *wait,
    char *error,
    size_t error_size
) {
    if (submit->size < 0x80 || submit->size > 0x400 ||
        !sa_function_has_indirect_call_slot(submit, 0x20) ||
        !sa_function_has_indirect_call_slot(submit, 0x30)) {
        sa_set_error(error, error_size,
                     "DirectStorage submit no longer matches the validated queue/status contract");
        return 0;
    }
    if (wait->size < 0x80 || wait->size > 0x400 ||
        !sa_function_has_indirect_call_slot(wait, 0x20)) {
        sa_set_error(error, error_size,
                     "DirectStorage wait no longer matches the validated status contract");
        return 0;
    }
    return 1;
}

static int sa_final_path(const wchar_t *path, int directory, wchar_t *result, size_t capacity) {
    wchar_t raw[SA_MAX_STREAM_PATH];
    HANDLE handle;
    DWORD length;
    const wchar_t *source;

    handle = CreateFileW(
        path,
        FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL,
        OPEN_EXISTING,
        directory ? FILE_FLAG_BACKUP_SEMANTICS : 0,
        NULL);
    if (handle == INVALID_HANDLE_VALUE) {
        return 0;
    }
    length = GetFinalPathNameByHandleW(handle, raw, SA_ARRAY_COUNT(raw),
                                       FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    CloseHandle(handle);
    if (length == 0 || length >= SA_ARRAY_COUNT(raw)) {
        return 0;
    }

    source = raw;
    if (wcsncmp(source, L"\\\\?\\UNC\\", 8) == 0) {
        if (wcslen(source + 8) + 3 > capacity) {
            return 0;
        }
        result[0] = L'\\';
        result[1] = L'\\';
        wcscpy_s(result + 2, capacity - 2, source + 8);
        return 1;
    }
    if (wcsncmp(source, L"\\\\?\\", 4) == 0) {
        source += 4;
    }
    if (wcslen(source) + 1 > capacity) {
        return 0;
    }
    wcscpy_s(result, capacity, source);
    return 1;
}

int sa_make_bundle_relative_path(const char *absolute_path, char *relative_path, size_t capacity) {
    wchar_t input_path[SA_MAX_STREAM_PATH];
    wchar_t full_input_path[SA_MAX_STREAM_PATH];
    wchar_t executable_path[SA_MAX_STREAM_PATH];
    wchar_t full_game_root[SA_MAX_STREAM_PATH];
    wchar_t final_input_path[SA_MAX_STREAM_PATH];
    wchar_t final_game_root[SA_MAX_STREAM_PATH];
    wchar_t *separator;
    const wchar_t *suffix;
    size_t game_root_length;
    DWORD length;

    if (absolute_path == NULL || relative_path == NULL || capacity <= 3 ||
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, absolute_path, -1,
                            input_path, SA_ARRAY_COUNT(input_path)) == 0 ||
        wcslen(input_path) < 3 || input_path[1] != L':' ||
        (input_path[2] != L'\\' && input_path[2] != L'/')) {
        return 0;
    }
    length = GetFullPathNameW(input_path, SA_ARRAY_COUNT(full_input_path), full_input_path, NULL);
    if (length == 0 || length >= SA_ARRAY_COUNT(full_input_path)) {
        return 0;
    }
    length = GetModuleFileNameW(NULL, executable_path, SA_ARRAY_COUNT(executable_path));
    if (length == 0 || length >= SA_ARRAY_COUNT(executable_path)) {
        return 0;
    }

    separator = wcsrchr(executable_path, L'\\');
    if (separator == NULL) {
        return 0;
    }
    *separator = L'\0';
    separator = wcsrchr(executable_path, L'\\');
    if (separator == NULL || _wcsicmp(separator + 1, L"binaries") != 0) {
        return 0;
    }
    *separator = L'\0';
    length = GetFullPathNameW(executable_path, SA_ARRAY_COUNT(full_game_root), full_game_root, NULL);
    if (length == 0 || length >= SA_ARRAY_COUNT(full_game_root) ||
        !sa_final_path(full_game_root, 1, final_game_root, SA_ARRAY_COUNT(final_game_root)) ||
        !sa_final_path(full_input_path, 0, final_input_path, SA_ARRAY_COUNT(final_input_path))) {
        return 0;
    }

    game_root_length = wcslen(final_game_root);
    if (wcslen(final_input_path) <= game_root_length ||
        _wcsnicmp(final_input_path, final_game_root, game_root_length) != 0 ||
        final_input_path[game_root_length] != L'\\') {
        return 0;
    }
    suffix = final_input_path + game_root_length + 1;
    memcpy(relative_path, "..\\", 3);
    if (WideCharToMultiByte(
            CP_UTF8, WC_ERR_INVALID_CHARS, suffix, -1,
            relative_path + 3, (int)(capacity - 3), NULL, NULL) == 0) {
        relative_path[0] = '\0';
        return 0;
    }
    return 1;
}

static uint64_t sa_queue_failure(uint64_t type_hash, uint64_t name_hash, const char *message) {
    sa_fail_resource(type_hash, name_hash, "%s", message);
    return 0;
}

static int sa_is_read_only_image_range(const SaImage *image, const void *address, size_t size) {
    const DtIntUtilsSection *section = dtintutils_section_for_address(image, address);
    const uint8_t *start = (const uint8_t *)address;

    if (section == NULL || size == 0 || start > section->start + section->size ||
        size > (size_t)(section->start + section->size - start)) {
        return 0;
    }
    return (section->characteristics & IMAGE_SCN_MEM_READ) != 0 &&
        (section->characteristics & (IMAGE_SCN_MEM_WRITE | IMAGE_SCN_MEM_EXECUTE)) == 0;
}

uint64_t sa_queue_request_hook(void *worker, void *request) {
    const SaQueueReadShape *shape = &g_engine.queue_shape;
    uint8_t *request_bytes = (uint8_t *)request;
    SaQueueRequestFn original = (SaQueueRequestFn)g_queue_request_hook_state.trampoline;
    uint64_t type_hash;
    uint64_t name_hash;
    uint32_t package_id;
    char path[SA_MAX_STREAM_PATH];
    char io_path[SA_MAX_STREAM_PATH];
    void *io_loader;
    void **io_vtable;
    void **worker_vtable;
    SaIoOpenFn io_open;
    SaIoSizeFn io_size;
    SaWorkerAllocateFn allocate;
    uint64_t handle;
    uint64_t carrier_size;
    uint64_t size;
    SaWorkerAllocation allocation = {0};

    if (worker == NULL || request == NULL) {
        return original(worker, request);
    }
    if (!dtintutils_is_readable_range(request, shape->handle_offset + sizeof(uint64_t))) {
        return original(worker, request);
    }
    memcpy(&type_hash, request_bytes + shape->type_hash_offset, sizeof(type_hash));
    memcpy(&name_hash, request_bytes + shape->name_hash_offset, sizeof(name_hash));
    if (!sa_find_resource_paths(
            type_hash, name_hash, path, sizeof(path), io_path, sizeof(io_path), &size)) {
        return original(worker, request);
    }

    if (!dtintutils_is_readable_range(worker, shape->io_loader_offset + sizeof(void *)) ||
        !dtintutils_is_writable_range(request, shape->handle_offset + sizeof(uint64_t))) {
        return sa_queue_failure(type_hash, name_hash, "resource loader request memory is unavailable");
    }
    memcpy(&package_id, request_bytes + shape->package_id_offset, sizeof(package_id));
    memcpy(&io_loader, (uint8_t *)worker + shape->io_loader_offset, sizeof(io_loader));
    memcpy(&worker_vtable, worker, sizeof(worker_vtable));
    if (io_loader == NULL || worker_vtable == NULL ||
        !dtintutils_is_readable_range(io_loader, sizeof(void *))) {
        return sa_queue_failure(type_hash, name_hash, "resource loader objects are unavailable");
    }
    memcpy(&io_vtable, io_loader, sizeof(io_vtable));
    if (io_vtable == NULL ||
        !sa_is_read_only_image_range(&g_image, worker_vtable, shape->worker_allocate_slot + sizeof(void *)) ||
        !sa_is_read_only_image_range(&g_image, io_vtable, shape->io_read_slot + sizeof(void *))) {
        return sa_queue_failure(type_hash, name_hash, "resource loader vtables failed validation");
    }
    memcpy(&io_open, (uint8_t *)io_vtable + shape->io_open_slot, sizeof(io_open));
    memcpy(&io_size, (uint8_t *)io_vtable + shape->io_size_slot, sizeof(io_size));
    memcpy(&allocate, (uint8_t *)worker_vtable + shape->worker_allocate_slot, sizeof(allocate));
    if (!dtintutils_is_executable_address(&g_image, (const void *)io_open) ||
        !dtintutils_is_executable_address(&g_image, (const void *)io_size) ||
        !dtintutils_is_executable_address(&g_image, (const void *)allocate) ||
        !dtintutils_is_executable_address(&g_image, (const void *)g_engine.queue_push)) {
        return sa_queue_failure(type_hash, name_hash, "resource loader functions failed validation");
    }

    handle = io_open(io_loader, io_path, type_hash, name_hash, package_id, worker, 0);
    memcpy(request_bytes + shape->handle_offset, &handle, sizeof(handle));
    carrier_size = io_size(io_loader, handle);
    memcpy(request_bytes + shape->size_offset, &size, sizeof(size));
    if (carrier_size == 0 || size == 0 || size > SIZE_MAX) {
        return sa_queue_failure(type_hash, name_hash, "external resource file or I/O carrier size is invalid");
    }

    allocate(worker, &allocation, size, 8);
    if (allocation.data == NULL) {
        return sa_queue_failure(type_hash, name_hash, "resource loader could not allocate the destination buffer");
    }
    memcpy(request_bytes + shape->data_offset, &allocation.data, sizeof(allocation.data));
    sa_async_read_start(path, allocation.data, size, io_loader, type_hash, name_hash);

    ((SaQueuePushFn)g_engine.queue_push)((uint8_t *)worker + shape->input_queue_offset, request);
    return 1;
}
