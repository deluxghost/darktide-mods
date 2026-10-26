#include "winapi_windows.h"

// Capture the thread-local error before returning through the cgo runtime.
#define SIMPLE_AUDIO_CAPTURE_RESULT(expression, result_type) \
    result_type result = (expression);                        \
    *last_error = GetLastError();                             \
    return result

int SimpleAudioRuntimeCall_MultiByteToWideChar(
    UINT code_page,
    DWORD flags,
    LPCCH multi_byte_text,
    int multi_byte_length,
    LPWSTR wide_text,
    int wide_length,
    DWORD *last_error
) {
    SIMPLE_AUDIO_CAPTURE_RESULT(
        MultiByteToWideChar(
            code_page, flags, multi_byte_text, multi_byte_length, wide_text, wide_length),
        int);
}

int SimpleAudioRuntimeCall_WideCharToMultiByte(
    UINT code_page,
    DWORD flags,
    LPCWCH wide_text,
    int wide_length,
    LPSTR multi_byte_text,
    int multi_byte_length,
    LPCCH default_char,
    LPBOOL used_default_char,
    DWORD *last_error
) {
    SIMPLE_AUDIO_CAPTURE_RESULT(
        WideCharToMultiByte(
            code_page, flags, wide_text, wide_length, multi_byte_text, multi_byte_length,
            default_char, used_default_char),
        int);
}

HANDLE SimpleAudioRuntimeCall_FindFirstFileW(
    LPCWSTR file_name,
    LPWIN32_FIND_DATAW find_data,
    DWORD *last_error
) {
    SIMPLE_AUDIO_CAPTURE_RESULT(FindFirstFileW(file_name, find_data), HANDLE);
}

BOOL SimpleAudioRuntimeCall_FindNextFileW(
    HANDLE find_handle,
    LPWIN32_FIND_DATAW find_data,
    DWORD *last_error
) {
    SIMPLE_AUDIO_CAPTURE_RESULT(FindNextFileW(find_handle, find_data), BOOL);
}

BOOL SimpleAudioRuntimeCall_FindClose(HANDLE find_handle, DWORD *last_error) {
    SIMPLE_AUDIO_CAPTURE_RESULT(FindClose(find_handle), BOOL);
}
