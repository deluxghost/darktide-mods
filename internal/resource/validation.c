#include "runtime_internal.h"

#include <string.h>

typedef int (*SaResourceValidator)(const uint8_t *, size_t, char *, size_t);

typedef struct {
    const char *type;
    SaResourceValidator validate;
} SaResourceValidatorEntry;

enum {
    SA_SLUG_ALBUM_HEADER_SIZE = 0x44,
    SA_SLUG_ALBUM_CURVE_WIDTH_OFFSET = 0x24,
    SA_SLUG_ALBUM_CURVE_HEIGHT_OFFSET = 0x28,
    SA_SLUG_ALBUM_BAND_WIDTH_OFFSET = 0x3c,
    SA_SLUG_ALBUM_BAND_HEIGHT_OFFSET = 0x40,
    SA_MAX_TEXTURE_DIMENSION = 16384,
};

static int sa_validate_slug_block(
    const uint8_t *data,
    size_t data_size,
    const char block[4],
    const char *description,
    char *error,
    size_t error_size
) {
    if (data_size < 12) {
        sa_set_error(error, error_size, "resource data is shorter than the 12-byte Slug header");
        return 0;
    }
    if (memcmp(data, "guls", 4) != 0 || memcmp(data + 8, block, 4) != 0) {
        sa_set_error(error, error_size, "resource data is not a Slug %s resource", description);
        return 0;
    }
    return 1;
}

static int sa_validate_slug(
    const uint8_t *data,
    size_t data_size,
    char *error,
    size_t error_size
) {
    return sa_validate_slug_block(data, data_size, "fnt\0", "font", error, error_size);
}

static int sa_validate_slug_album(
    const uint8_t *data,
    size_t data_size,
    char *error,
    size_t error_size
) {
    uint32_t curve_width;
    uint32_t curve_height;
    uint32_t band_width;
    uint32_t band_height;

    if (data_size < SA_SLUG_ALBUM_HEADER_SIZE) {
        sa_set_error(error, error_size, "resource data is shorter than the 68-byte Slug album header");
        return 0;
    }
    if (memcmp(data, "guls", 4) != 0 || memcmp(data + 8, "alb\0", 4) != 0) {
        sa_set_error(error, error_size, "resource data is not a Slug album resource");
        return 0;
    }

    memcpy(&curve_width, data + SA_SLUG_ALBUM_CURVE_WIDTH_OFFSET, sizeof(curve_width));
    memcpy(&curve_height, data + SA_SLUG_ALBUM_CURVE_HEIGHT_OFFSET, sizeof(curve_height));
    memcpy(&band_width, data + SA_SLUG_ALBUM_BAND_WIDTH_OFFSET, sizeof(band_width));
    memcpy(&band_height, data + SA_SLUG_ALBUM_BAND_HEIGHT_OFFSET, sizeof(band_height));
    if (curve_width == 0 || curve_height == 0 ||
        curve_width > SA_MAX_TEXTURE_DIMENSION || curve_height > SA_MAX_TEXTURE_DIMENSION) {
        sa_set_error(error, error_size, "Slug album curve texture dimensions are invalid: %u x %u",
                     curve_width, curve_height);
        return 0;
    }
    if (band_width == 0 || band_height == 0 ||
        band_width > SA_MAX_TEXTURE_DIMENSION || band_height > SA_MAX_TEXTURE_DIMENSION) {
        sa_set_error(error, error_size, "Slug album band texture dimensions are invalid: %u x %u",
                     band_width, band_height);
        return 0;
    }
    return 1;
}

int sa_validate_mouse_cursor_data(
    const void *data,
    size_t data_size,
    char *error,
    size_t error_size
) {
    uint32_t header[5];
    uint64_t expected_pixels;
    uint64_t expected_size;

    if (data == NULL || data_size < sizeof(header)) {
        sa_set_error(error, error_size, "mouse cursor data is shorter than its 20-byte header");
        return 0;
    }
    memcpy(header, data, sizeof(header));
    if (header[0] == 0 || header[1] == 0 ||
        header[0] > SA_MAX_TEXTURE_DIMENSION || header[1] > SA_MAX_TEXTURE_DIMENSION) {
        sa_set_error(error, error_size, "mouse cursor dimensions are invalid");
        return 0;
    }
    if (header[2] >= header[0] || header[3] >= header[1]) {
        sa_set_error(error, error_size, "mouse cursor hotspot is outside its dimensions");
        return 0;
    }
    expected_pixels = (uint64_t)header[0] * header[1] * 4;
    expected_size = sizeof(header) + expected_pixels;
    if (header[4] != expected_pixels || data_size != expected_size) {
        sa_set_error(error, error_size, "mouse cursor BGRA payload size does not match its dimensions");
        return 0;
    }
    return 1;
}

static int sa_validate_mouse_cursor(
    const uint8_t *data,
    size_t data_size,
    char *error,
    size_t error_size
) {
    return sa_validate_mouse_cursor_data(data, data_size, error, error_size);
}

static SaResourceValidator sa_validator_for_type(const char *resource_type) {
    static const SaResourceValidatorEntry validators[] = {
        {"mouse_cursor", sa_validate_mouse_cursor},
        {"slug", sa_validate_slug},
        {"slug_album", sa_validate_slug_album},
    };
    size_t index;

    for (index = 0; index < SA_ARRAY_COUNT(validators); ++index) {
        if (strcmp(validators[index].type, resource_type) == 0) {
            return validators[index].validate;
        }
    }
    return NULL;
}

int sa_validate_resource_data(
    const char *resource_type,
    const void *data,
    size_t data_size,
    char *error,
    size_t error_size
) {
    SaResourceValidator validator;

    if (resource_type == NULL || data == NULL || data_size == 0) {
        sa_set_error(error, error_size, "resource type and non-empty data are required");
        return 0;
    }

    validator = sa_validator_for_type(resource_type);
    if (validator != NULL && !validator((const uint8_t *)data, data_size, error, error_size)) {
        return 0;
    }

    return 1;
}
