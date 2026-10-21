#include "../runtime_internal.h"
#include "../runtime_windows.h"

#include <stdint.h>

int simple_assets_texture_resource_load(
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    const void *resource_data,
    size_t resource_data_size,
    const char *stream_path,
    size_t stream_data_size,
    char *error_buffer,
    size_t error_buffer_size
) {
    uint64_t stream_location = 0;

    if (resource_name == NULL || file_path == NULL || io_carrier_path == NULL ||
        resource_data == NULL) {
        sa_set_error(error_buffer, error_buffer_size,
                     "texture resource name, path, I/O carrier, and data must not be null");
        return 0;
    }
    if ((stream_path == NULL) != (stream_data_size == 0)) {
        sa_set_error(error_buffer, error_buffer_size,
                     "texture stream path and size must either both be present or both be absent");
        return 0;
    }
    if (stream_data_size > UINT32_MAX) {
        sa_set_error(error_buffer, error_buffer_size,
                     "texture stream exceeds the engine's 32-bit stream range");
        return 0;
    }
    if (!sa_validate_texture_data(
            resource_data, resource_data_size,
            error_buffer, error_buffer_size)) {
        return 0;
    }
    if (stream_path != NULL) {
        /* The texture loader keeps streamed mips only when its packed stream range is nonzero. */
        stream_location = (uint64_t)stream_data_size << 32;
    }

    return sa_load_external_resource(
        "texture", resource_name, file_path, io_carrier_path,
        resource_data, resource_data_size,
        stream_path, stream_location,
        error_buffer, error_buffer_size);
}
