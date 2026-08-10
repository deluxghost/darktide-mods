#ifndef SIMPLE_ASSETS_RESOURCE_RUNTIME_WINDOWS_H
#define SIMPLE_ASSETS_RESOURCE_RUNTIME_WINDOWS_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

int simple_assets_resource_load(
    const char *resource_type,
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    char *error_buffer,
    size_t error_buffer_size
);

int simple_assets_resource_state(
    const char *resource_type,
    const char *resource_name,
    char *error_buffer,
    size_t error_buffer_size
);

#ifdef __cplusplus
}
#endif

#endif
