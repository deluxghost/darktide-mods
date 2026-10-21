#include "internal.h"

#include <string.h>

int sa_format_resource_stream_identity(
    uint64_t type_hash,
    uint64_t resource_hash,
    char *identity,
    size_t identity_size
) {
    static const char alphabet[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    uint8_t input[16];
    uint32_t accumulator = 0;
    unsigned int bits = 0;
    size_t output_index = 0;
    size_t index;

    if (identity == NULL || identity_size < SA_STREAM_IDENTITY_SIZE) {
        return 0;
    }
    for (index = 0; index < 8; ++index) {
        input[index] = (uint8_t)(type_hash >> ((7 - index) * 8));
        input[index + 8] = (uint8_t)(resource_hash >> ((7 - index) * 8));
    }
    for (index = 0; index < sizeof(input); ++index) {
        accumulator = (accumulator << 8) | input[index];
        bits += 8;
        while (bits >= 6) {
            bits -= 6;
            identity[output_index++] = alphabet[(accumulator >> bits) & 0x3f];
        }
    }
    if (bits != 0) {
        identity[output_index++] = alphabet[(accumulator << (6 - bits)) & 0x3f];
    }
    identity[output_index] = '\0';
    return 1;
}

int sa_resolve_resource_stream_identity(
    const char *identity,
    char *path,
    size_t path_size
) {
    SaResourceMapping *mapping;
    size_t required;
    size_t index;

    if (identity == NULL || path == NULL) {
        return 0;
    }
    for (index = 0; index < SA_STREAM_IDENTITY_SIZE - 1; ++index) {
        unsigned char current = (unsigned char)identity[index];

        if (!((current >= 'A' && current <= 'Z') ||
              (current >= 'a' && current <= 'z') ||
              (current >= '0' && current <= '9') ||
              current == '-' || current == '_')) {
            return 0;
        }
    }
    if (identity[SA_STREAM_IDENTITY_SIZE - 1] != '\0') {
        return 0;
    }

    mapping = sa_find_mapping_by_stream_identity(identity);
    if (mapping == NULL) {
        return 0;
    }
    required = strlen(mapping->stream_path) + 1;
    if (required > path_size) {
        return 0;
    }
    memcpy(path, mapping->stream_path, required);
    return 1;
}

int sa_is_resource_stream_path(const char *path) {
    return path != NULL && sa_find_mapping_by_stream_path(path) != NULL;
}