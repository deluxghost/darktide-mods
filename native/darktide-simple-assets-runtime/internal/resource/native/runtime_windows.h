#ifndef SIMPLE_ASSETS_RESOURCE_RUNTIME_WINDOWS_H
#define SIMPLE_ASSETS_RESOURCE_RUNTIME_WINDOWS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int simple_assets_resource_load(
    const char *resource_type,
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    const void *resource_data,
    size_t resource_data_size,
    char *error_buffer,
    size_t error_buffer_size
);

int simple_assets_resource_state(
    const char *resource_type,
    const char *resource_name,
    char *error_buffer,
    size_t error_buffer_size
);

int simple_assets_resource_replace(
    const char *resource_type,
    const char *target_resource_name,
    const char *source_resource_name,
    char *error_buffer,
    size_t error_buffer_size
);

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
);

int simple_assets_ivf_video_load(
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    char *error_buffer,
    size_t error_buffer_size
);

int simple_assets_bink_video_load(
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    char *error_buffer,
    size_t error_buffer_size
);

int simple_assets_mouse_cursor_load(
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    const void *compiled_data,
    size_t compiled_data_size,
    char *error_buffer,
    size_t error_buffer_size
);

#ifdef __cplusplus
}
#endif

#endif
