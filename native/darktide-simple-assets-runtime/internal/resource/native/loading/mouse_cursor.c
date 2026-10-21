#include "../runtime_internal.h"
#include "../runtime_windows.h"

int simple_assets_mouse_cursor_load(
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    const void *compiled_data,
    size_t compiled_data_size,
    char *error_buffer,
    size_t error_buffer_size
) {
    if (resource_name == NULL || file_path == NULL || io_carrier_path == NULL) {
        sa_set_error(error_buffer, error_buffer_size,
                     "mouse cursor name, path, and I/O carrier must not be null");
        return 0;
    }
    return sa_load_external_resource(
        "mouse_cursor", resource_name, file_path, io_carrier_path,
        compiled_data, compiled_data_size,
        NULL, 0, error_buffer, error_buffer_size);
}
