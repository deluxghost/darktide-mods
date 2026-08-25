#include "../runtime_internal.h"

#include <string.h>
#include <wchar.h>

static int sa_final_path(const wchar_t *path, int directory, wchar_t *result, size_t capacity) {
    wchar_t raw[SA_MAX_STREAM_PATH];
    HANDLE handle;
    DWORD length;
    const wchar_t *source;

    handle = CreateFileW(
        path,
        FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL,
        OPEN_EXISTING,
        directory ? FILE_FLAG_BACKUP_SEMANTICS : 0,
        NULL);
    if (handle == INVALID_HANDLE_VALUE) {
        return 0;
    }
    length = GetFinalPathNameByHandleW(handle, raw, SA_ARRAY_COUNT(raw),
                                       FILE_NAME_NORMALIZED | VOLUME_NAME_DOS);
    CloseHandle(handle);
    if (length == 0 || length >= SA_ARRAY_COUNT(raw)) {
        return 0;
    }

    source = raw;
    if (wcsncmp(source, L"\\\\?\\UNC\\", 8) == 0) {
        if (wcslen(source + 8) + 3 > capacity) {
            return 0;
        }
        result[0] = L'\\';
        result[1] = L'\\';
        wcscpy_s(result + 2, capacity - 2, source + 8);
        return 1;
    }
    if (wcsncmp(source, L"\\\\?\\", 4) == 0) {
        source += 4;
    }
    if (wcslen(source) + 1 > capacity) {
        return 0;
    }
    wcscpy_s(result, capacity, source);
    return 1;
}

static int sa_is_absolute_path(const wchar_t *path) {
    size_t length = wcslen(path);

    return (length >= 3 && path[1] == L':' &&
            (path[2] == L'\\' || path[2] == L'/')) ||
        (length >= 2 && (path[0] == L'\\' || path[0] == L'/') &&
         (path[1] == L'\\' || path[1] == L'/'));
}

int sa_make_bundle_relative_path(const char *absolute_path, char *relative_path, size_t capacity) {
    wchar_t input_path[SA_MAX_STREAM_PATH];
    wchar_t full_input_path[SA_MAX_STREAM_PATH];
    wchar_t executable_path[SA_MAX_STREAM_PATH];
    wchar_t full_game_root[SA_MAX_STREAM_PATH];
    wchar_t final_input_path[SA_MAX_STREAM_PATH];
    wchar_t final_game_root[SA_MAX_STREAM_PATH];
    wchar_t *separator;
    const wchar_t *suffix;
    size_t game_root_length;
    DWORD length;

    if (absolute_path == NULL || relative_path == NULL || capacity <= 3 ||
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, absolute_path, -1,
                            input_path, SA_ARRAY_COUNT(input_path)) == 0 ||
        !sa_is_absolute_path(input_path)) {
        return 0;
    }
    length = GetFullPathNameW(input_path, SA_ARRAY_COUNT(full_input_path), full_input_path, NULL);
    if (length == 0 || length >= SA_ARRAY_COUNT(full_input_path)) {
        return 0;
    }
    length = GetModuleFileNameW(NULL, executable_path, SA_ARRAY_COUNT(executable_path));
    if (length == 0 || length >= SA_ARRAY_COUNT(executable_path)) {
        return 0;
    }

    separator = wcsrchr(executable_path, L'\\');
    if (separator == NULL) {
        return 0;
    }
    *separator = L'\0';
    separator = wcsrchr(executable_path, L'\\');
    if (separator == NULL || _wcsicmp(separator + 1, L"binaries") != 0) {
        return 0;
    }
    *separator = L'\0';
    length = GetFullPathNameW(executable_path, SA_ARRAY_COUNT(full_game_root), full_game_root, NULL);
    if (length == 0 || length >= SA_ARRAY_COUNT(full_game_root) ||
        !sa_final_path(full_game_root, 1, final_game_root, SA_ARRAY_COUNT(final_game_root)) ||
        !sa_final_path(full_input_path, 0, final_input_path, SA_ARRAY_COUNT(final_input_path))) {
        return 0;
    }

    game_root_length = wcslen(final_game_root);
    if (wcslen(final_input_path) <= game_root_length ||
        _wcsnicmp(final_input_path, final_game_root, game_root_length) != 0 ||
        final_input_path[game_root_length] != L'\\') {
        return 0;
    }
    suffix = final_input_path + game_root_length + 1;
    memcpy(relative_path, "..\\", 3);
    if (WideCharToMultiByte(
            CP_UTF8, WC_ERR_INVALID_CHARS, suffix, -1,
            relative_path + 3, (int)(capacity - 3), NULL, NULL) == 0) {
        relative_path[0] = '\0';
        return 0;
    }
    return 1;
}
