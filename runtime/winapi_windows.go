package main

/*
#include <stdint.h>
#include "winapi_windows.h"
*/
import "C"

import (
	"sync/atomic"
	"unsafe"
)

var simpleAssetsRuntimeLastWindowsError atomic.Uint32

func storeSimpleAssetsRuntimeLastWindowsError(lastError C.DWORD) {
	simpleAssetsRuntimeLastWindowsError.Store(uint32(lastError))
}

//export SimpleAssetsRuntime_GetLastError
func SimpleAssetsRuntime_GetLastError() C.uint32_t {
	return C.uint32_t(simpleAssetsRuntimeLastWindowsError.Load())
}

//export SimpleAssetsRuntime_GetFileAttributesW
func SimpleAssetsRuntime_GetFileAttributesW(fileName unsafe.Pointer) C.uint32_t {
	var lastError C.DWORD
	result := C.SimpleAssetsRuntimeCall_GetFileAttributesW((*C.WCHAR)(fileName), &lastError)
	storeSimpleAssetsRuntimeLastWindowsError(lastError)

	return C.uint32_t(result)
}

//export SimpleAssetsRuntime_MultiByteToWideChar
func SimpleAssetsRuntime_MultiByteToWideChar(
	codePage C.uint,
	flags C.uint32_t,
	multiByteText *C.char,
	multiByteLength C.int,
	wideText unsafe.Pointer,
	wideLength C.int,
) C.int {
	var lastError C.DWORD
	result := C.SimpleAssetsRuntimeCall_MultiByteToWideChar(
		C.UINT(codePage),
		C.DWORD(flags),
		multiByteText,
		multiByteLength,
		(*C.WCHAR)(wideText),
		wideLength,
		&lastError,
	)
	storeSimpleAssetsRuntimeLastWindowsError(lastError)

	return result
}

//export SimpleAssetsRuntime_WideCharToMultiByte
func SimpleAssetsRuntime_WideCharToMultiByte(
	codePage C.uint,
	flags C.uint32_t,
	wideText unsafe.Pointer,
	wideLength C.int,
	multiByteText *C.char,
	multiByteLength C.int,
	defaultChar *C.char,
	usedDefaultChar unsafe.Pointer,
) C.int {
	var lastError C.DWORD
	result := C.SimpleAssetsRuntimeCall_WideCharToMultiByte(
		C.UINT(codePage),
		C.DWORD(flags),
		(*C.WCHAR)(wideText),
		wideLength,
		multiByteText,
		multiByteLength,
		defaultChar,
		(*C.BOOL)(usedDefaultChar),
		&lastError,
	)
	storeSimpleAssetsRuntimeLastWindowsError(lastError)

	return result
}

//export SimpleAssetsRuntime_FindFirstFileW
func SimpleAssetsRuntime_FindFirstFileW(fileName unsafe.Pointer, findData unsafe.Pointer) unsafe.Pointer {
	var lastError C.DWORD
	result := C.SimpleAssetsRuntimeCall_FindFirstFileW(
		(*C.WCHAR)(fileName),
		(*C.WIN32_FIND_DATAW)(findData),
		&lastError,
	)
	storeSimpleAssetsRuntimeLastWindowsError(lastError)

	return unsafe.Pointer(result)
}

//export SimpleAssetsRuntime_FindNextFileW
func SimpleAssetsRuntime_FindNextFileW(findHandle unsafe.Pointer, findData unsafe.Pointer) C.int {
	var lastError C.DWORD
	result := C.SimpleAssetsRuntimeCall_FindNextFileW(
		C.HANDLE(findHandle),
		(*C.WIN32_FIND_DATAW)(findData),
		&lastError,
	)
	storeSimpleAssetsRuntimeLastWindowsError(lastError)

	return C.int(result)
}

//export SimpleAssetsRuntime_FindClose
func SimpleAssetsRuntime_FindClose(findHandle unsafe.Pointer) C.int {
	var lastError C.DWORD
	result := C.SimpleAssetsRuntimeCall_FindClose(C.HANDLE(findHandle), &lastError)
	storeSimpleAssetsRuntimeLastWindowsError(lastError)

	return C.int(result)
}
