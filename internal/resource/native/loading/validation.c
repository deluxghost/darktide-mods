#include "../runtime_internal.h"

#include <string.h>

typedef struct {
    const char *type;
    uint32_t version;
} SaVersionedResourceFormat;

static uint32_t sa_read_u32(const uint8_t *data) {
    uint32_t value;

    memcpy(&value, data, sizeof(value));
    return value;
}

static int sa_validate_slug_format(
    const uint8_t *data,
    size_t data_size,
    const char block[4],
    const char *description,
    char *error,
    size_t error_size
) {
    if (data_size < 12 ||
        memcmp(data, "guls", 4) != 0 ||
        memcmp(data + 8, block, 4) != 0) {
        sa_set_error(error, error_size,
                     "resource data does not match the Slug %s format",
                     description);
        return 0;
    }
    return 1;
}

static int sa_validate_resource_format(
    const char *resource_type,
    const uint8_t *data,
    size_t data_size,
    char *error,
    size_t error_size
) {
    static const SaVersionedResourceFormat formats[] = {
        {"material", 61},
        {"particles", 102},
        {"unit", 115},
    };
    size_t index;

    if (strcmp(resource_type, "slug") == 0) {
        return sa_validate_slug_format(
            data, data_size, "fnt\0", "font", error, error_size);
    }
    if (strcmp(resource_type, "slug_album") == 0) {
        return sa_validate_slug_format(
            data, data_size, "alb\0", "album", error, error_size);
    }

    for (index = 0; index < SA_ARRAY_COUNT(formats); ++index) {
        const SaVersionedResourceFormat *format = &formats[index];

        if (strcmp(format->type, resource_type) != 0) {
            continue;
        }
        if (data_size < sizeof(uint32_t) || sa_read_u32(data) != format->version) {
            sa_set_error(error, error_size,
                         "resource data does not match the current %s format",
                         resource_type);
            return 0;
        }
        return 1;
    }

    return 1;
}

int sa_validate_resource_data(
    const char *resource_type,
    const void *data,
    size_t data_size,
    char *error,
    size_t error_size
) {
    if (resource_type == NULL || data == NULL || data_size == 0) {
        sa_set_error(error, error_size,
                     "resource type and non-empty data are required");
        return 0;
    }

    return sa_validate_resource_format(
        resource_type, (const uint8_t *)data, data_size, error, error_size);
}

int sa_validate_texture_data(
    const void *data,
    size_t data_size,
    char *error,
    size_t error_size
) {
    const uint8_t *bytes = (const uint8_t *)data;
    uint32_t compressor;
    uint32_t compressed_size;

    if (data == NULL || data_size <= 12) {
        sa_set_error(error, error_size,
                     "texture data does not contain an envelope and payload");
        return 0;
    }
    compressor = sa_read_u32(bytes);
    compressed_size = sa_read_u32(bytes + 4);
    if (compressed_size == 0) {
        return 1;
    }
    if (compressor != 1 && compressor != 2) {
        sa_set_error(error, error_size,
                     "texture data uses an unsupported engine compressor");
        return 0;
    }
    if (compressed_size > data_size - 12) {
        sa_set_error(error, error_size,
                     "texture compressed payload exceeds the file size");
        return 0;
    }
    return 1;
}
