#include "runtime_internal.h"
#include "runtime_windows.h"

#include <string.h>

#define SA_IVF_HEADER_SIZE 32
#define SA_IVF_FRAME_HEADER_SIZE 12
#define SA_IVF_RESOURCE_VERSION 3

static uint16_t sa_read_u16_le(const uint8_t *value) {
    return (uint16_t)value[0] | (uint16_t)((uint16_t)value[1] << 8);
}

static uint32_t sa_read_u32_le(const uint8_t *value) {
    return (uint32_t)value[0] |
        ((uint32_t)value[1] << 8) |
        ((uint32_t)value[2] << 16) |
        ((uint32_t)value[3] << 24);
}

static void sa_write_u32_le(uint8_t *destination, uint32_t value) {
    destination[0] = (uint8_t)value;
    destination[1] = (uint8_t)(value >> 8);
    destination[2] = (uint8_t)(value >> 16);
    destination[3] = (uint8_t)(value >> 24);
}

static int sa_parse_ivf_resource(
    const char *path,
    uint8_t metadata[20],
    uint64_t *stream_range,
    char *error,
    size_t error_size
) {
    WCHAR wide_path[SA_MAX_STREAM_PATH];
    HANDLE file;
    LARGE_INTEGER file_size;
    uint8_t header[SA_IVF_HEADER_SIZE + SA_IVF_FRAME_HEADER_SIZE];
    DWORD bytes_read = 0;
    uint16_t width;
    uint16_t height;
    uint32_t rate;
    uint32_t scale;
    uint32_t frame_count;
    uint32_t frame_size;
    uint32_t frame_rate;
    uint64_t stream_size;

    if (path == NULL || metadata == NULL || stream_range == NULL) {
        sa_set_error(error, error_size, "video path and output pointers must not be null");
        return 0;
    }
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide_path,
                            SA_ARRAY_COUNT(wide_path)) == 0) {
        sa_set_error(error, error_size, "video path is not valid UTF-8 or is too long");
        return 0;
    }
    file = CreateFileW(wide_path, GENERIC_READ,
                       FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                       NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) {
        sa_set_error(error, error_size, "video file could not be opened: Win32 error %lu", GetLastError());
        return 0;
    }
    if (!GetFileSizeEx(file, &file_size) || file_size.QuadPart <
        SA_IVF_HEADER_SIZE + SA_IVF_FRAME_HEADER_SIZE) {
        sa_set_error(error, error_size, "video file is shorter than an IVF header and one frame record");
        CloseHandle(file);
        return 0;
    }
    if ((uint64_t)file_size.QuadPart - SA_IVF_HEADER_SIZE > UINT32_MAX) {
        sa_set_error(error, error_size, "video stream exceeds the engine's 32-bit stream range");
        CloseHandle(file);
        return 0;
    }
    if (!ReadFile(file, header, sizeof(header), &bytes_read, NULL) || bytes_read != sizeof(header)) {
        sa_set_error(error, error_size, "video IVF header could not be read");
        CloseHandle(file);
        return 0;
    }
    CloseHandle(file);

    if (memcmp(header, "DKIF", 4) != 0 || sa_read_u16_le(header + 4) != 0 ||
        sa_read_u16_le(header + 6) != SA_IVF_HEADER_SIZE || memcmp(header + 8, "VP80", 4) != 0) {
        sa_set_error(error, error_size, "video file is not a standard VP8 IVF resource");
        return 0;
    }
    width = sa_read_u16_le(header + 12);
    height = sa_read_u16_le(header + 14);
    rate = sa_read_u32_le(header + 16);
    scale = sa_read_u32_le(header + 20);
    frame_count = sa_read_u32_le(header + 24);
    frame_size = sa_read_u32_le(header + SA_IVF_HEADER_SIZE);
    stream_size = (uint64_t)file_size.QuadPart - SA_IVF_HEADER_SIZE;

    if (width == 0 || height == 0 || rate == 0 || scale == 0 || frame_count == 0) {
        sa_set_error(error, error_size, "video IVF dimensions, time base, and frame count must be nonzero");
        return 0;
    }
    if (rate % scale != 0 || rate / scale == 0) {
        sa_set_error(error, error_size, "video IVF frame rate must be a positive whole number");
        return 0;
    }
    if (frame_size == 0 || frame_size > stream_size - SA_IVF_FRAME_HEADER_SIZE) {
        sa_set_error(error, error_size, "video IVF first frame record exceeds the file size");
        return 0;
    }
    frame_rate = rate / scale;
    sa_write_u32_le(metadata, SA_IVF_RESOURCE_VERSION);
    sa_write_u32_le(metadata + 4, width);
    sa_write_u32_le(metadata + 8, height);
    sa_write_u32_le(metadata + 12, frame_rate);
    sa_write_u32_le(metadata + 16, frame_count);

    *stream_range = (stream_size << 32) | SA_IVF_HEADER_SIZE;
    return 1;
}

int simple_assets_video_load(
    const char *resource_name,
    const char *file_path,
    const char *io_carrier_path,
    char *error_buffer,
    size_t error_buffer_size
) {
    uint8_t metadata[20];
    uint64_t stream_range;

    if (resource_name == NULL || file_path == NULL || io_carrier_path == NULL) {
        sa_set_error(error_buffer, error_buffer_size, "video name, path, and I/O carrier must not be null");
        return 0;
    }
    if (!sa_parse_ivf_resource(file_path, metadata, &stream_range, error_buffer, error_buffer_size)) {
        return 0;
    }
    return sa_load_external_resource(
        "ivf", resource_name, file_path, io_carrier_path,
        metadata, sizeof(metadata), file_path, stream_range,
        error_buffer, error_buffer_size);
}
