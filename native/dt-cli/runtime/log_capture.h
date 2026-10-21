#ifndef LUAEXEC_LOG_CAPTURE_H
#define LUAEXEC_LOG_CAPTURE_H

#include <stdint.h>

int LuaExecLogCapture_Start(char *error_buffer, int error_buffer_size);
int LuaExecLogCapture_Pop(
    char *buffer,
    uint32_t buffer_size,
    uint32_t *length,
    uint64_t *dropped_bytes);

#endif
