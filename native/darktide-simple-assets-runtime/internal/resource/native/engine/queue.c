#include "../runtime_internal.h"

#include <string.h>

enum { SA_IO_OPEN_FLAGS = 0 };

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

static size_t sa_request_extent(size_t extent, uint32_t offset, size_t size) {
    size_t end = (size_t)offset + size;

    return end > extent ? end : extent;
}

uint64_t sa_queue_request_hook(void *worker, void *request) {
    const SaQueueReadShape *shape = &g_engine.queue_shape;
    const SaStreamRequestShape *stream_shape = &g_engine.stream_request_shape;
    uint8_t *request_bytes = (uint8_t *)request;
    SaQueueRequestFn original = (SaQueueRequestFn)g_queue_request_hook_state.trampoline;
    uint64_t type_hash;
    uint64_t name_hash;
    uint32_t package_id;
    char io_path[SA_MAX_STREAM_PATH];
    char stream_path[SA_MAX_STREAM_PATH];
    const uint8_t *resource_data;
    size_t resource_data_size;
    void *io_loader;
    void **io_vtable;
    void **worker_vtable;
    SaIoOpenFn io_open;
    SaIoSizeFn io_size;
    SaWorkerAllocateFn allocate;
    uint64_t handle;
    uint64_t carrier_size;
    uint64_t stream_range;
    size_t request_extent;
    size_t io_vtable_size;
    int has_stream;
    SaWorkerAllocation allocation = {0};

    if (worker == NULL || request == NULL) {
        return original(worker, request);
    }
    request_extent = sa_request_extent(0, shape->type_hash_offset, sizeof(type_hash));
    request_extent = sa_request_extent(request_extent, shape->name_hash_offset, sizeof(name_hash));
    if (!dtintutils_is_readable_range(request, request_extent)) {
        return original(worker, request);
    }
    memcpy(&type_hash, request_bytes + shape->type_hash_offset, sizeof(type_hash));
    memcpy(&name_hash, request_bytes + shape->name_hash_offset, sizeof(name_hash));
    if (!sa_find_resource_data(
            type_hash, name_hash, io_path, sizeof(io_path),
            &resource_data, &resource_data_size)) {
        return original(worker, request);
    }
    has_stream = sa_find_resource_stream(
        type_hash, name_hash, stream_path, sizeof(stream_path), &stream_range);

    request_extent = sa_request_extent(request_extent, shape->package_id_offset, sizeof(package_id));
    request_extent = sa_request_extent(request_extent, shape->handle_offset, sizeof(handle));
    request_extent = sa_request_extent(request_extent, shape->size_offset, sizeof(uint64_t));
    request_extent = sa_request_extent(request_extent, shape->data_offset, sizeof(void *));
    if (has_stream) {
        request_extent = sa_request_extent(
            request_extent, stream_shape->flag_offset, sizeof(uint8_t));
        request_extent = sa_request_extent(
            request_extent, stream_shape->location_offset, stream_shape->location_size);
    }
    if (!dtintutils_is_readable_range(worker, shape->io_loader_offset + sizeof(void *)) ||
        !dtintutils_is_writable_range(request, request_extent)) {
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
    io_vtable_size = (size_t)(shape->io_open_slot > shape->io_size_slot
        ? shape->io_open_slot
        : shape->io_size_slot) + sizeof(void *);
    if (io_vtable == NULL ||
        !sa_is_read_only_image_range(&g_image, worker_vtable, shape->worker_allocate_slot + sizeof(void *)) ||
        !sa_is_read_only_image_range(&g_image, io_vtable, io_vtable_size)) {
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

    handle = io_open(
        io_loader, io_path, type_hash, name_hash, package_id, worker,
        SA_IO_OPEN_FLAGS);
    memcpy(request_bytes + shape->handle_offset, &handle, sizeof(handle));
    carrier_size = io_size(io_loader, handle);
    {
        uint64_t size = resource_data_size;
        memcpy(request_bytes + shape->size_offset, &size, sizeof(size));
    }
    if (carrier_size == 0 || (resource_data_size != 0 && resource_data == NULL)) {
        return sa_queue_failure(type_hash, name_hash, "external resource data or I/O carrier size is invalid");
    }

    if (resource_data_size != 0) {
        allocate(worker, &allocation, resource_data_size, sizeof(void *));
        if (allocation.data == NULL) {
            return sa_queue_failure(type_hash, name_hash, "resource loader could not allocate the destination buffer");
        }
        memcpy(allocation.data, resource_data, resource_data_size);
    }
    memcpy(request_bytes + shape->data_offset, &allocation.data, sizeof(allocation.data));

    if (has_stream) {
        uint8_t *location = request_bytes + stream_shape->location_offset;

        memset(location, 0, stream_shape->location_size);
        if (!sa_format_resource_stream_identity(
                type_hash, name_hash, (char *)location, stream_shape->path_size)) {
            return sa_queue_failure(type_hash, name_hash,
                                    "resource stream identity storage is unavailable");
        }
        memcpy(request_bytes + stream_shape->range_offset,
               &stream_range, sizeof(stream_range));
        request_bytes[stream_shape->flag_offset] = 1;
    }

    ((SaQueuePushFn)g_engine.queue_push)((uint8_t *)worker + shape->input_queue_offset, request);
    return 1;
}
