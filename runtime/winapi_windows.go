package main

/*
#define WIN32_LEAN_AND_MEAN
#include <stdint.h>
#include <windows.h>
*/
import "C"

import (
	"sync/atomic"
	"unsafe"
)

var simpleAssetsRuntimeLastWindowsError atomic.Uint32

func captureSimpleAssetsRuntimeLastWindowsError() {
	simpleAssetsRuntimeLastWindowsError.Store(uint32(C.GetLastError()))
}

//export SimpleAssetsRuntime_GetLastError
func SimpleAssetsRuntime_GetLastError() C.uint32_t {
	return C.uint32_t(simpleAssetsRuntimeLastWindowsError.Load())
}

//export SimpleAssetsRuntime_GetFileAttributesW
func SimpleAssetsRuntime_GetFileAttributesW(fileName unsafe.Pointer) C.uint32_t {
	result := C.GetFileAttributesW((*C.WCHAR)(fileName))
	captureSimpleAssetsRuntimeLastWindowsError()

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
	result := C.MultiByteToWideChar(
		C.UINT(codePage),
		C.DWORD(flags),
		multiByteText,
		multiByteLength,
		(*C.WCHAR)(wideText),
		wideLength,
	)
	captureSimpleAssetsRuntimeLastWindowsError()

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
	result := C.WideCharToMultiByte(
		C.UINT(codePage),
		C.DWORD(flags),
		(*C.WCHAR)(wideText),
		wideLength,
		multiByteText,
		multiByteLength,
		defaultChar,
		(*C.BOOL)(usedDefaultChar),
	)
	captureSimpleAssetsRuntimeLastWindowsError()

	return result
}

//export SimpleAssetsRuntime_FindFirstFileW
func SimpleAssetsRuntime_FindFirstFileW(fileName unsafe.Pointer, findData unsafe.Pointer) unsafe.Pointer {
	result := C.FindFirstFileW((*C.WCHAR)(fileName), (*C.WIN32_FIND_DATAW)(findData))
	captureSimpleAssetsRuntimeLastWindowsError()

	return unsafe.Pointer(result)
}

//export SimpleAssetsRuntime_FindNextFileW
func SimpleAssetsRuntime_FindNextFileW(findHandle unsafe.Pointer, findData unsafe.Pointer) C.int {
	result := C.FindNextFileW(C.HANDLE(findHandle), (*C.WIN32_FIND_DATAW)(findData))
	captureSimpleAssetsRuntimeLastWindowsError()

	return C.int(result)
}

//export SimpleAssetsRuntime_FindClose
func SimpleAssetsRuntime_FindClose(findHandle unsafe.Pointer) C.int {
	result := C.FindClose(C.HANDLE(findHandle))
	captureSimpleAssetsRuntimeLastWindowsError()

	return C.int(result)
}
