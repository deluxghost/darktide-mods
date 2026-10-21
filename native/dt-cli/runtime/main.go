package main

/*
#include <stdint.h>
*/
import "C"

import (
	"os"
	"unsafe"

	"dt-cli/internal/gameinstance"
	"dt-cli/internal/runtimepipe"
)

const requestBufferTooSmall = -2

var runtimeServer = runtimepipe.New()
var logRuntime nativeLogRuntime

func main() {}

func copyMessage(buffer *C.char, bufferSize C.int, message string) C.int {
	if buffer == nil || bufferSize <= 0 {
		return -1
	}

	target := unsafe.Slice((*byte)(unsafe.Pointer(buffer)), int(bufferSize))
	if len(target) == 0 {
		return -1
	}

	maxLen := len(target) - 1
	if len(message) > maxLen {
		copy(target, message[:maxLen])
		target[maxLen] = 0
		return -2
	}

	copy(target, message)
	target[len(message)] = 0

	return 1
}

func fail(buffer *C.char, bufferSize C.int, err error) C.int {
	if err == nil {
		return 0
	}

	copyMessage(buffer, bufferSize, err.Error())
	return 0
}

func clearBuffer(buffer *C.char, bufferSize C.int) {
	if buffer != nil && bufferSize > 0 {
		unsafe.Slice((*byte)(unsafe.Pointer(buffer)), int(bufferSize))[0] = 0
	}
}

//export LuaExecRuntime_Start
func LuaExecRuntime_Start(errorBuffer *C.char, errorBufferSize C.int) C.int {
	pid := uint32(os.Getpid())
	if err := runtimeServer.Start(gameinstance.ExecPipeName(pid)); err != nil {
		return fail(errorBuffer, errorBufferSize, err)
	}

	logRuntime.Start(gameinstance.LogsPipeName(pid))
	clearBuffer(errorBuffer, errorBufferSize)
	return 1
}

//export LuaExecRuntime_Stop
func LuaExecRuntime_Stop() {
	runtimeServer.Stop()
}

//export LuaExecRuntime_PollRequest
func LuaExecRuntime_PollRequest(
	requestID *C.int,
	buffer *C.char,
	bufferSize C.int,
	errorBuffer *C.char,
	errorBufferSize C.int,
) C.int {
	if requestID == nil || buffer == nil || bufferSize <= 0 {
		copyMessage(errorBuffer, errorBufferSize, "request output buffer is invalid")
		return -1
	}

	request, ok := runtimeServer.PollRequest()
	if !ok {
		clearBuffer(errorBuffer, errorBufferSize)
		return 0
	}

	target := unsafe.Slice((*byte)(unsafe.Pointer(buffer)), int(bufferSize))
	maxLen := len(target) - 1
	if len(request.Payload) > maxLen {
		_ = runtimeServer.Respond(request.ID, []byte(`{"ok":false,"error":"LuaExec request is too large for the runtime buffer"}`))
		copyMessage(errorBuffer, errorBufferSize, "request buffer is too small")
		return requestBufferTooSmall
	}

	*requestID = C.int(request.ID)
	copy(target, request.Payload)
	target[len(request.Payload)] = 0
	clearBuffer(errorBuffer, errorBufferSize)

	return 1
}

//export LuaExecRuntime_SendResponse
func LuaExecRuntime_SendResponse(requestID C.int, payload *C.char, errorBuffer *C.char, errorBufferSize C.int) C.int {
	if payload == nil {
		copyMessage(errorBuffer, errorBufferSize, "response payload is null")
		return 0
	}

	if err := runtimeServer.Respond(int(requestID), []byte(C.GoString(payload))); err != nil {
		return fail(errorBuffer, errorBufferSize, err)
	}

	clearBuffer(errorBuffer, errorBufferSize)
	return 1
}
