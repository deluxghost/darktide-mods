#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "dtintutils.h"
#include "log_capture.h"

#define RAW_QUEUE_BYTES (512u * 1024u)
#define RAW_RECORD_BYTES (64u * 1024u)
#define SEARCH_FORWARD_BYTES 96u

typedef void (*buffer_write_fn)(void *destination, const void *source, uint32_t length);

static SRWLOCK queue_lock = SRWLOCK_INIT;
static uint8_t raw_queue[RAW_QUEUE_BYTES];
static uint32_t queue_read;
static uint32_t queue_write;
static uint32_t queue_used;
static volatile LONG64 dropped_bytes;
static buffer_write_fn original_buffer_write;
static DtIntUtilsCallPatch capture_patch;
static volatile LONG capture_enabled;
static volatile LONG start_state;
static char start_error[512];

static void set_error(const char *message)
{
    snprintf(start_error, sizeof(start_error), "%s", message);
}

static void copy_error(char *buffer, int buffer_size)
{
    if (buffer == NULL || buffer_size <= 0) {
        return;
    }

    snprintf(buffer, (size_t)buffer_size, "%s", start_error);
}

static void queue_copy_in(const uint8_t *source, uint32_t length)
{
    uint32_t first = RAW_QUEUE_BYTES - queue_write;
    if (first > length) {
        first = length;
    }

    memcpy(raw_queue + queue_write, source, first);
    memcpy(raw_queue, source + first, length - first);
    queue_write = (queue_write + length) % RAW_QUEUE_BYTES;
    queue_used += length;
}

static void queue_copy_out(uint8_t *destination, uint32_t length)
{
    uint32_t first = RAW_QUEUE_BYTES - queue_read;
    if (first > length) {
        first = length;
    }

    memcpy(destination, raw_queue + queue_read, first);
    memcpy(destination + first, raw_queue, length - first);
    queue_read = (queue_read + length) % RAW_QUEUE_BYTES;
    queue_used -= length;
}

static void capture_bytes(const void *source, uint32_t length)
{
    uint32_t record_count;
    uint64_t required_size;

    if (source == NULL || length == 0 || InterlockedCompareExchange(&capture_enabled, 0, 0) == 0) {
        return;
    }

    record_count = (length - 1) / RAW_RECORD_BYTES + 1;
    required_size = (uint64_t)length + (uint64_t)record_count * sizeof(uint32_t);
    if (required_size > RAW_QUEUE_BYTES) {
        InterlockedAdd64(&dropped_bytes, length);
        return;
    }
    if (!TryAcquireSRWLockExclusive(&queue_lock)) {
        InterlockedAdd64(&dropped_bytes, length);
        return;
    }

    if (required_size > RAW_QUEUE_BYTES - queue_used) {
        ReleaseSRWLockExclusive(&queue_lock);
        InterlockedAdd64(&dropped_bytes, length);
        return;
    }

    const uint8_t *cursor = (const uint8_t *)source;
    uint32_t remaining = length;
    while (remaining > 0) {
        uint32_t record_length = remaining > RAW_RECORD_BYTES ? RAW_RECORD_BYTES : remaining;
        queue_copy_in((const uint8_t *)&record_length, (uint32_t)sizeof(record_length));
        queue_copy_in(cursor, record_length);
        cursor += record_length;
        remaining -= record_length;
    }

    ReleaseSRWLockExclusive(&queue_lock);
}

static void capture_buffer_write(void *destination, const void *source, uint32_t length)
{
    original_buffer_write(destination, source, length);
    capture_bytes(source, length);
}

static int install_capture_hook(void)
{
    DtIntUtilsModule module;
    char utility_error[512] = {0};
    const uint8_t *resolved_call_site;
    DtIntUtilsInstruction call_instruction;
    uint8_t *call_site;
    const DtIntUtilsLocatorStep locator_steps[] = {
        DTINTUTILS_LOCATE_EXACT_STRING("stingray::FileStream::flush_buffer", 1, 1),
        DTINTUTILS_LOCATE_RIP_REFERENCES(DTINTUTILS_MNEMONIC_LEA, ".text", 1, 1),
        DTINTUTILS_LOCATE_IDA_PATTERN_NEAR(
            "44 8B 43 08 48 8D 53 10 48 8D 4F 78 E8 ?? ?? ?? ?? 80 BF 98 00 00 00 00",
            0,
            SEARCH_FORWARD_BYTES,
            1,
            1),
        DTINTUTILS_LOCATE_ADD_OFFSET(12, 1, 1),
        DTINTUTILS_LOCATE_REQUIRE_DIRECT_CALL(1, 1),
        DTINTUTILS_LOCATE_RESOLVE_DIRECT_CALL(1, 1),
    };
    DtIntUtilsLocator locator = {
        "FileStream console write call",
        locator_steps,
        5,
    };

    if (!dtintutils_module_init_current(&module, utility_error, sizeof(utility_error))) {
        set_error(utility_error);
        return 0;
    }
    if (!dtintutils_locate_unique_address(
            &module,
            &locator,
            &resolved_call_site,
            utility_error,
            sizeof(utility_error))) {
        set_error(utility_error);
        return 0;
    }
    call_site = (uint8_t *)resolved_call_site;
    if (!dtintutils_decode(call_site, 5, &call_instruction) ||
        call_instruction.length != 5 ||
        call_instruction.mnemonic != DTINTUTILS_MNEMONIC_CALL ||
        call_instruction.operand_count != 1 ||
        call_instruction.operands[0].type != DTINTUTILS_OPERAND_IMMEDIATE ||
        !call_instruction.operands[0].has_absolute) {
        set_error("located FileStream console write instruction is not a direct rel32 CALL");
        return 0;
    }
    original_buffer_write = (buffer_write_fn)(uintptr_t)call_instruction.operands[0].absolute;
    if (!dtintutils_call_patch_install(
            &capture_patch,
            call_site,
            (void *)&capture_buffer_write,
            (void *)original_buffer_write,
            utility_error,
            sizeof(utility_error))) {
        set_error(utility_error);
        return 0;
    }

    InterlockedExchange(&capture_enabled, 1);
    return 1;
}

int LuaExecLogCapture_Start(char *error_buffer, int error_buffer_size)
{
    LONG state = InterlockedCompareExchange(&start_state, 1, 0);
    if (state == 2) {
        return 1;
    }
    if (state == 3) {
        copy_error(error_buffer, error_buffer_size);
        return 0;
    }
    if (state == 1) {
        while ((state = InterlockedCompareExchange(&start_state, 0, 0)) == 1) {
            Sleep(1);
        }
        if (state == 2) {
            return 1;
        }
        copy_error(error_buffer, error_buffer_size);
        return 0;
    }

    if (!install_capture_hook()) {
        InterlockedExchange(&start_state, 3);
        copy_error(error_buffer, error_buffer_size);
        return 0;
    }

    InterlockedExchange(&start_state, 2);
    return 1;
}

int LuaExecLogCapture_Pop(
    char *buffer,
    uint32_t buffer_size,
    uint32_t *length,
    uint64_t *dropped)
{
    uint32_t record_length;

    if (buffer == NULL || length == NULL || dropped == NULL) {
        return -1;
    }

    AcquireSRWLockExclusive(&queue_lock);
    *dropped = (uint64_t)InterlockedExchange64(&dropped_bytes, 0);
    if (queue_used < sizeof(record_length)) {
        *length = 0;
        ReleaseSRWLockExclusive(&queue_lock);
        return 0;
    }

    queue_copy_out((uint8_t *)&record_length, (uint32_t)sizeof(record_length));
    if (record_length > buffer_size || record_length > queue_used) {
        *length = 0;
        ReleaseSRWLockExclusive(&queue_lock);
        return -1;
    }

    queue_copy_out((uint8_t *)buffer, record_length);
    *length = record_length;
    ReleaseSRWLockExclusive(&queue_lock);
    return 1;
}
