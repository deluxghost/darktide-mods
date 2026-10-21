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

var simpleAudioRuntimeLastWindowsError atomic.Uint32

func captureSimpleAudioRuntimeLastWindowsError() {
	simpleAudioRuntimeLastWindowsError.Store(uint32(C.GetLastError()))
}

//export SimpleAudioRuntime_GetLastError
func SimpleAudioRuntime_GetLastError() C.uint32_t {
	return C.uint32_t(simpleAudioRuntimeLastWindowsError.Load())
}

//export SimpleAudioRuntime_MultiByteToWideChar
func SimpleAudioRuntime_MultiByteToWideChar(
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
	captureSimpleAudioRuntimeLastWindowsError()

	return result
}

//export SimpleAudioRuntime_WideCharToMultiByte
func SimpleAudioRuntime_WideCharToMultiByte(
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
	captureSimpleAudioRuntimeLastWindowsError()

	return result
}

//export SimpleAudioRuntime_FindFirstFileW
func SimpleAudioRuntime_FindFirstFileW(fileName unsafe.Pointer, findData unsafe.Pointer) unsafe.Pointer {
	result := C.FindFirstFileW((*C.WCHAR)(fileName), (*C.WIN32_FIND_DATAW)(findData))
	captureSimpleAudioRuntimeLastWindowsError()

	return unsafe.Pointer(result)
}

//export SimpleAudioRuntime_FindNextFileW
func SimpleAudioRuntime_FindNextFileW(findHandle unsafe.Pointer, findData unsafe.Pointer) C.int {
	result := C.FindNextFileW(C.HANDLE(findHandle), (*C.WIN32_FIND_DATAW)(findData))
	captureSimpleAudioRuntimeLastWindowsError()

	return C.int(result)
}

//export SimpleAudioRuntime_FindClose
func SimpleAudioRuntime_FindClose(findHandle unsafe.Pointer) C.int {
	result := C.FindClose(C.HANDLE(findHandle))
	captureSimpleAudioRuntimeLastWindowsError()

	return C.int(result)
}
