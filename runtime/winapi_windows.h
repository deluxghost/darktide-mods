#ifndef SIMPLE_ASSETS_RUNTIME_WINAPI_WINDOWS_H
#define SIMPLE_ASSETS_RUNTIME_WINAPI_WINDOWS_H

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>

DWORD SimpleAssetsRuntimeCall_GetFileAttributesW(LPCWSTR file_name, DWORD *last_error);
int SimpleAssetsRuntimeCall_MultiByteToWideChar(
    UINT code_page,
    DWORD flags,
    LPCCH multi_byte_text,
    int multi_byte_length,
    LPWSTR wide_text,
    int wide_length,
    DWORD *last_error
);
int SimpleAssetsRuntimeCall_WideCharToMultiByte(
    UINT code_page,
    DWORD flags,
    LPCWCH wide_text,
    int wide_length,
    LPSTR multi_byte_text,
    int multi_byte_length,
    LPCCH default_char,
    LPBOOL used_default_char,
    DWORD *last_error
);
HANDLE SimpleAssetsRuntimeCall_FindFirstFileW(
    LPCWSTR file_name,
    LPWIN32_FIND_DATAW find_data,
    DWORD *last_error
);
BOOL SimpleAssetsRuntimeCall_FindNextFileW(
    HANDLE find_handle,
    LPWIN32_FIND_DATAW find_data,
    DWORD *last_error
);
BOOL SimpleAssetsRuntimeCall_FindClose(HANDLE find_handle, DWORD *last_error);

#endif
