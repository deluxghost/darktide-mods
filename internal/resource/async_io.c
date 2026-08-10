#include "runtime_internal.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SA_ASYNC_READ_CHUNK_SIZE UINT64_C(0x1000000)
#define SA_ASYNC_EXCEPTION_CODE ((DWORD)0xe0425341)
#define SA_ASYNC_BATCH_BUCKET_COUNT 256

typedef struct {
    OVERLAPPED overlapped;
    DWORD expected_size;
} SaAsyncReadChunk;

typedef struct SaAsyncRead {
    struct SaAsyncRead *next;
    HANDLE file;
    DWORD owner_thread;
    void *reader;
    uint32_t chunk_count;
    uint64_t type_hash;
    uint64_t resource_hash;
    char path[SA_MAX_STREAM_PATH];
    SaAsyncReadChunk chunks[];
} SaAsyncRead;

typedef struct SaAsyncBatch {
    struct SaAsyncBatch *next;
    SaAsyncRead *reads;
    HANDLE complete_event;
    void *reader;
    uint32_t token;
    volatile LONG wait_started;
    volatile LONG completed;
    DWORD error_code;
    uint64_t error_type_hash;
    uint64_t error_resource_hash;
    char error_path[SA_MAX_STREAM_PATH];
} SaAsyncBatch;

static SRWLOCK g_async_lock = SRWLOCK_INIT;
static SaAsyncRead *g_pending_reads;
static volatile LONG g_pending_read_count;
static SaAsyncBatch *volatile g_batch_buckets[SA_ASYNC_BATCH_BUCKET_COUNT];

static DECLSPEC_NORETURN void sa_async_fatal(DWORD error_code, const char *path) {
    char message[SA_MAX_STREAM_PATH + 128];
    ULONG_PTR arguments[2];

    snprintf(message, sizeof(message),
             "SimpleAssets asynchronous resource read failed for `%s` with Win32 error %lu.\n",
             path != NULL ? path : "<unknown>", error_code);
    message[sizeof(message) - 1] = '\0';
    OutputDebugStringA(message);
    arguments[0] = error_code;
    arguments[1] = (ULONG_PTR)path;
    RaiseException(SA_ASYNC_EXCEPTION_CODE, EXCEPTION_NONCONTINUABLE,
                   SA_ARRAY_COUNT(arguments), arguments);
    TerminateProcess(GetCurrentProcess(), error_code != 0 ? error_code : ERROR_READ_FAULT);
    abort();
}

static DECLSPEC_NORETURN void sa_async_resource_fatal(
    DWORD error_code,
    const char *path,
    uint64_t type_hash,
    uint64_t resource_hash
) {
    sa_fail_resource(type_hash, resource_hash,
                     "asynchronous resource read failed with Win32 error %lu", error_code);
    sa_async_fatal(error_code, path);
}

static void sa_async_release_read(SaAsyncRead *read) {
    uint32_t index;

    if (read == NULL) {
        return;
    }
    for (index = 0; index < read->chunk_count; ++index) {
        if (read->chunks[index].overlapped.hEvent != NULL) {
            CloseHandle(read->chunks[index].overlapped.hEvent);
        }
    }
    if (read->file != INVALID_HANDLE_VALUE) {
        CloseHandle(read->file);
    }
    HeapFree(GetProcessHeap(), 0, read);
}

static void sa_async_cancel_read(SaAsyncRead *read, uint32_t issued_count) {
    uint32_t index;

    CancelIoEx(read->file, NULL);
    for (index = 0; index < issued_count; ++index) {
        DWORD transferred;
        GetOverlappedResult(read->file, &read->chunks[index].overlapped, &transferred, TRUE);
    }
    sa_async_release_read(read);
}

void sa_async_read_start(
    const char *path,
    void *destination,
    uint64_t size,
    void *reader,
    uint64_t type_hash,
    uint64_t resource_hash
) {
    wchar_t wide_path[SA_MAX_STREAM_PATH];
    LARGE_INTEGER file_size;
    uint64_t chunk_count64;
    size_t allocation_size;
    SaAsyncRead *read;
    uint64_t offset;
    uint32_t index;
    DWORD error_code;

    if (path == NULL || destination == NULL || reader == NULL || size == 0 || size > SIZE_MAX) {
        sa_async_resource_fatal(ERROR_INVALID_PARAMETER, path, type_hash, resource_hash);
    }
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path, -1, wide_path,
                            SA_ARRAY_COUNT(wide_path)) == 0) {
        sa_async_resource_fatal(GetLastError(), path, type_hash, resource_hash);
    }

    chunk_count64 = (size - 1) / SA_ASYNC_READ_CHUNK_SIZE + 1;
    if (chunk_count64 == 0 || chunk_count64 > UINT32_MAX ||
        chunk_count64 > (SIZE_MAX - offsetof(SaAsyncRead, chunks)) / sizeof(SaAsyncReadChunk)) {
        sa_async_resource_fatal(ERROR_ARITHMETIC_OVERFLOW, path, type_hash, resource_hash);
    }
    allocation_size = offsetof(SaAsyncRead, chunks) +
        (size_t)chunk_count64 * sizeof(SaAsyncReadChunk);
    read = (SaAsyncRead *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, allocation_size);
    if (read == NULL) {
        sa_async_resource_fatal(ERROR_OUTOFMEMORY, path, type_hash, resource_hash);
    }
    read->file = INVALID_HANDLE_VALUE;
    read->owner_thread = GetCurrentThreadId();
    read->reader = reader;
    read->chunk_count = (uint32_t)chunk_count64;
    read->type_hash = type_hash;
    read->resource_hash = resource_hash;
    memcpy(read->path, path, strlen(path) + 1);

    read->file = CreateFileW(
        wide_path, GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED | FILE_FLAG_SEQUENTIAL_SCAN,
        NULL);
    if (read->file == INVALID_HANDLE_VALUE) {
        error_code = GetLastError();
        sa_async_release_read(read);
        sa_async_resource_fatal(error_code, path, type_hash, resource_hash);
    }
    if (!GetFileSizeEx(read->file, &file_size)) {
        error_code = GetLastError();
        sa_async_release_read(read);
        sa_async_resource_fatal(error_code, path, type_hash, resource_hash);
    }
    if (file_size.QuadPart < 0 || (uint64_t)file_size.QuadPart != size) {
        sa_async_release_read(read);
        sa_async_resource_fatal(ERROR_HANDLE_EOF, path, type_hash, resource_hash);
    }

    offset = 0;
    for (index = 0; index < read->chunk_count; ++index) {
        SaAsyncReadChunk *chunk = &read->chunks[index];
        uint64_t remaining = size - offset;
        DWORD chunk_size = (DWORD)(remaining < SA_ASYNC_READ_CHUNK_SIZE ?
                                   remaining : SA_ASYNC_READ_CHUNK_SIZE);

        chunk->overlapped.Offset = (DWORD)offset;
        chunk->overlapped.OffsetHigh = (DWORD)(offset >> 32);
        chunk->overlapped.hEvent = CreateEventW(NULL, TRUE, FALSE, NULL);
        chunk->expected_size = chunk_size;
        if (chunk->overlapped.hEvent == NULL) {
            error_code = GetLastError();
            sa_async_release_read(read);
            sa_async_resource_fatal(error_code, path, type_hash, resource_hash);
        }
        offset += chunk_size;
    }

    offset = 0;
    for (index = 0; index < read->chunk_count; ++index) {
        SaAsyncReadChunk *chunk = &read->chunks[index];
        BOOL started;

        started = ReadFile(read->file, (uint8_t *)destination + (size_t)offset,
                           chunk->expected_size, NULL, &chunk->overlapped);
        error_code = started ? ERROR_SUCCESS : GetLastError();
        if (!started && error_code != ERROR_IO_PENDING) {
            sa_async_cancel_read(read, index);
            sa_async_resource_fatal(error_code, path, type_hash, resource_hash);
        }
        offset += chunk->expected_size;
    }

    AcquireSRWLockExclusive(&g_async_lock);
    read->next = g_pending_reads;
    g_pending_reads = read;
    InterlockedIncrement(&g_pending_read_count);
    ReleaseSRWLockExclusive(&g_async_lock);
}

static SaAsyncRead *sa_async_detach_pending_reads(DWORD owner_thread, void *reader) {
    SaAsyncRead **cursor;
    SaAsyncRead *reads = NULL;
    LONG detached_count = 0;

    if (InterlockedCompareExchange(&g_pending_read_count, 0, 0) == 0) {
        return NULL;
    }

    AcquireSRWLockExclusive(&g_async_lock);
    cursor = &g_pending_reads;
    while (*cursor != NULL) {
        SaAsyncRead *read = *cursor;

        if (read->owner_thread != owner_thread || read->reader != reader) {
            cursor = &read->next;
            continue;
        }
        *cursor = read->next;
        read->next = reads;
        reads = read;
        ++detached_count;
    }
    if (detached_count != 0) {
        InterlockedAdd(&g_pending_read_count, -detached_count);
    }
    ReleaseSRWLockExclusive(&g_async_lock);
    return reads;
}

static size_t sa_async_batch_bucket(void *reader, uint32_t token) {
    uintptr_t value = (uintptr_t)reader;
    value ^= value >> 17;
    value ^= (uintptr_t)token * (uintptr_t)0x9e3779b1u;
    return (size_t)(value & (SA_ASYNC_BATCH_BUCKET_COUNT - 1));
}

static void sa_async_publish_batch(SaAsyncBatch *batch) {
    SaAsyncBatch *head;
    SaAsyncBatch *published;
    size_t bucket = sa_async_batch_bucket(batch->reader, batch->token);

    do {
        head = (SaAsyncBatch *)InterlockedCompareExchangePointer(
            (PVOID volatile *)&g_batch_buckets[bucket], NULL, NULL);
        batch->next = head;
        published = (SaAsyncBatch *)InterlockedCompareExchangePointer(
            (PVOID volatile *)&g_batch_buckets[bucket], batch, head);
    } while (published != head);
}

static void sa_async_complete_batch(SaAsyncBatch *batch) {
    if (InterlockedCompareExchange(&batch->wait_started, 1, 0) == 0) {
        SaAsyncRead *read = batch->reads;
        DWORD first_error = ERROR_SUCCESS;

        batch->reads = NULL;
        while (read != NULL) {
            SaAsyncRead *next = read->next;
            uint32_t index;

            for (index = 0; index < read->chunk_count; ++index) {
                DWORD transferred = 0;
                BOOL completed = GetOverlappedResult(
                    read->file, &read->chunks[index].overlapped, &transferred, TRUE);

                if (!completed && first_error == ERROR_SUCCESS) {
                    first_error = GetLastError();
                    batch->error_type_hash = read->type_hash;
                    batch->error_resource_hash = read->resource_hash;
                    memcpy(batch->error_path, read->path, sizeof(batch->error_path));
                } else if (completed && transferred != read->chunks[index].expected_size &&
                           first_error == ERROR_SUCCESS) {
                    first_error = ERROR_HANDLE_EOF;
                    batch->error_type_hash = read->type_hash;
                    batch->error_resource_hash = read->resource_hash;
                    memcpy(batch->error_path, read->path, sizeof(batch->error_path));
                }
            }
            sa_async_release_read(read);
            read = next;
        }
        batch->error_code = first_error;
        InterlockedExchange(&batch->completed, 1);
        SetEvent(batch->complete_event);
    } else if (WaitForSingleObject(batch->complete_event, INFINITE) != WAIT_OBJECT_0) {
        sa_async_fatal(GetLastError(), "<SimpleAssets async completion event>");
    }

    if (batch->error_code != ERROR_SUCCESS) {
        sa_async_resource_fatal(batch->error_code, batch->error_path,
                                batch->error_type_hash, batch->error_resource_hash);
    }
}

uint32_t sa_io_submit_hook(void *reader) {
    SaIoSubmitFn original = (SaIoSubmitFn)g_io_submit_hook_state.trampoline;
    SaAsyncRead *reads = sa_async_detach_pending_reads(GetCurrentThreadId(), reader);
    SaAsyncBatch *batch = NULL;
    uint32_t token;

    if (reads != NULL) {
        batch = (SaAsyncBatch *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*batch));
        if (batch == NULL) {
            sa_async_resource_fatal(ERROR_OUTOFMEMORY, reads->path,
                                    reads->type_hash, reads->resource_hash);
        }
        batch->complete_event = CreateEventW(NULL, TRUE, FALSE, NULL);
        if (batch->complete_event == NULL) {
            sa_async_resource_fatal(GetLastError(), reads->path,
                                    reads->type_hash, reads->resource_hash);
        }
        batch->reads = reads;
        batch->reader = reader;
    }

    token = original(reader);
    if (batch == NULL) {
        return token;
    }
    batch->token = token;

    /* Keep completed batches because the engine may wait on the same token more than once. */
    sa_async_publish_batch(batch);
    return token;
}

void sa_io_wait_hook(void *reader, uint32_t token) {
    SaIoWaitFn original = (SaIoWaitFn)g_io_wait_hook_state.trampoline;

    original(reader, token);

    for (;;) {
        SaAsyncBatch *batch;

        batch = (SaAsyncBatch *)InterlockedCompareExchangePointer(
            (PVOID volatile *)&g_batch_buckets[sa_async_batch_bucket(reader, token)], NULL, NULL);
        for (; batch != NULL; batch = batch->next) {
            if (batch->reader == reader && batch->token == token &&
                InterlockedCompareExchange(&batch->completed, 0, 0) == 0) {
                break;
            }
        }

        if (batch == NULL) {
            return;
        }
        sa_async_complete_batch(batch);
    }
}
