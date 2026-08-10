#include "runtime_internal.h"

#include <string.h>

typedef int (*SaResourceValidator)(HANDLE, char *, size_t);

typedef struct {
    const char *type_name;
    SaResourceValidator validate;
} SaResourceValidatorEntry;

static int sa_validate_slug(HANDLE file, char *error, size_t error_size) {
    uint8_t header[12];
    DWORD bytes_read = 0;

    if (!ReadFile(file, header, sizeof(header), &bytes_read, NULL)) {
        sa_set_error(error, error_size, "Slug file header could not be read: Win32 error %lu", GetLastError());
        return 0;
    }
    if (bytes_read != sizeof(header)) {
        sa_set_error(error, error_size, "resource file is shorter than the 12-byte Slug header");
        return 0;
    }
    if (memcmp(header, "guls", 4) != 0 || memcmp(header + 8, "fnt\0", 4) != 0) {
        sa_set_error(error, error_size, "resource file is not a Slug fnt resource");
        return 0;
    }
    return 1;
}

static SaResourceValidator sa_validator_for_type(const char *resource_type) {
    static const SaResourceValidatorEntry validators[] = {
        {"slug", sa_validate_slug},
    };
    size_t index;

    for (index = 0; index < SA_ARRAY_COUNT(validators); ++index) {
        if (strcmp(validators[index].type_name, resource_type) == 0) {
            return validators[index].validate;
        }
    }
    return NULL;
}

int sa_validate_resource_file(
    const char *resource_type,
    const char *path,
    uint64_t *file_size,
    char *error,
    size_t error_size
) {
    int wide_length;
    WCHAR wide_path[SA_MAX_STREAM_PATH];
    DWORD attributes;
    HANDLE file;
    LARGE_INTEGER size;
    SaResourceValidator validator;
    int valid = 1;

    if (file_size == NULL) {
        sa_set_error(error, error_size, "resource file size pointer is null");
        return 0;
    }
    wide_length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide_path,
                                      SA_ARRAY_COUNT(wide_path));
    if (wide_length == 0) {
        sa_set_error(error, error_size, "resource path is not valid UTF-8 or is too long");
        return 0;
    }
    attributes = GetFileAttributesW(wide_path);
    if (attributes == INVALID_FILE_ATTRIBUTES) {
        sa_set_error(error, error_size, "resource file is not accessible: Win32 error %lu", GetLastError());
        return 0;
    }
    if ((attributes & FILE_ATTRIBUTE_DIRECTORY) != 0) {
        sa_set_error(error, error_size, "resource path refers to a directory");
        return 0;
    }

    file = CreateFileW(wide_path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                       NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) {
        sa_set_error(error, error_size, "resource file could not be opened: Win32 error %lu", GetLastError());
        return 0;
    }

    if (!GetFileSizeEx(file, &size)) {
        sa_set_error(error, error_size, "resource file size could not be read: Win32 error %lu", GetLastError());
        CloseHandle(file);
        return 0;
    }
    if (size.QuadPart <= 0) {
        sa_set_error(error, error_size, "resource file is empty");
        CloseHandle(file);
        return 0;
    }

    validator = sa_validator_for_type(resource_type);
    if (validator != NULL) {
        valid = validator(file, error, error_size);
    }
    *file_size = (uint64_t)size.QuadPart;
    CloseHandle(file);
    return valid;
}
