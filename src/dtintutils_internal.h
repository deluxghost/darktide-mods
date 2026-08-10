#ifndef DTINTUTILS_INTERNAL_H
#define DTINTUTILS_INTERNAL_H

#include "../include/dtintutils.h"

#define DTINTUTILS_ARRAY_COUNT(values) (sizeof(values) / sizeof((values)[0]))

void dtintutils_set_error(char *buffer, size_t buffer_size, const char *format, ...);

#endif
