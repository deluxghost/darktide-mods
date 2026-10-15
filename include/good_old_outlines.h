#pragma once
#include <stdint.h>

#define GOOD_OLD_OUTLINES_API __declspec(dllexport)

#ifdef __cplusplus
extern "C" {
#endif

// All exports run on the game's Lua thread, with no concurrent lifecycle calls.
// Error buffers belong to the caller. 1 means success, 0 means failure.
// GetConfig returns a native-owned snapshot, never the engine's writable address.
// The snapshot remains valid until the next successful GetConfig call.
GOOD_OLD_OUTLINES_API const void *GoodOldOutlines_GetConfig(uint32_t *size, char *error,
                                                            int capacity);
GOOD_OLD_OUTLINES_API int GoodOldOutlines_ApplyConfig(const void *data, uint32_t size, char *error,
                                                      int capacity);
GOOD_OLD_OUTLINES_API int GoodOldOutlines_RestoreConfig(char *error, int capacity);

// The caller must synchronize the renderer before changing config or removing hooks.
// ApplyConfig/RestoreConfig rebuild only render graph layers, generators and viewport templates.
GOOD_OLD_OUTLINES_API int GoodOldOutlines_Start(const char *shader_directory, char *error,
                                                int capacity);
GOOD_OLD_OUTLINES_API int GoodOldOutlines_SetEnabled(int enabled);
// GetError returns null until a render-thread failure occurs. The first error is retained;
// its native-owned text is immutable and valid until process exit. Reading it never blocks.
GOOD_OLD_OUTLINES_API const char *GoodOldOutlines_GetError(void);
GOOD_OLD_OUTLINES_API int GoodOldOutlines_Remove(char *error, int capacity);

#ifdef __cplusplus
}
#endif
