package resource

/*
#cgo windows CFLAGS: -I${SRCDIR}/../../../darktide-internal-utils/include
#cgo windows LDFLAGS: -L${SRCDIR}/../../../darktide-internal-utils/bin/ucrt64/Release -ldtintutils-core
#include <stdlib.h>
#include "runtime_windows.h"
*/
import "C"

import (
	"errors"
	"unsafe"
)

const errorBufferSize = 1024

func runtimeError(buffer *C.char) error {
	message := C.GoString(buffer)
	if message == "" {
		message = "external resource runtime failed without an error message"
	}

	return errors.New(message)
}

func registerResource(
	resourceType string,
	resourceName string,
	filePath string,
	carrierPath string,
	data []byte,
) error {
	if len(data) == 0 {
		return errors.New("external resource data is empty")
	}

	cResourceType := C.CString(resourceType)
	defer C.free(unsafe.Pointer(cResourceType))

	cResourceName := C.CString(resourceName)
	defer C.free(unsafe.Pointer(cResourceName))

	cFilePath := C.CString(filePath)
	defer C.free(unsafe.Pointer(cFilePath))

	cCarrierPath := C.CString(carrierPath)
	defer C.free(unsafe.Pointer(cCarrierPath))

	errorBuffer := (*C.char)(C.malloc(errorBufferSize))
	if errorBuffer == nil {
		return errors.New("failed to allocate the external resource error buffer")
	}
	defer C.free(unsafe.Pointer(errorBuffer))

	if C.simple_assets_resource_load(
		cResourceType,
		cResourceName,
		cFilePath,
		cCarrierPath,
		unsafe.Pointer(&data[0]),
		C.size_t(len(data)),
		errorBuffer,
		errorBufferSize,
	) == 0 {
		return runtimeError(errorBuffer)
	}

	return nil
}

func LoadVideo(resourceName string, filePath string, carrierPath string) error {
	cResourceName := C.CString(resourceName)
	defer C.free(unsafe.Pointer(cResourceName))

	cFilePath := C.CString(filePath)
	defer C.free(unsafe.Pointer(cFilePath))

	cCarrierPath := C.CString(carrierPath)
	defer C.free(unsafe.Pointer(cCarrierPath))

	errorBuffer := (*C.char)(C.malloc(errorBufferSize))
	if errorBuffer == nil {
		return errors.New("failed to allocate the external resource error buffer")
	}
	defer C.free(unsafe.Pointer(errorBuffer))

	if C.simple_assets_video_load(cResourceName, cFilePath, cCarrierPath, errorBuffer, errorBufferSize) == 0 {
		return runtimeError(errorBuffer)
	}

	return nil
}

func State(resourceType string, resourceName string) (int, error) {
	cResourceType := C.CString(resourceType)
	defer C.free(unsafe.Pointer(cResourceType))

	cResourceName := C.CString(resourceName)
	defer C.free(unsafe.Pointer(cResourceName))

	errorBuffer := (*C.char)(C.malloc(errorBufferSize))
	if errorBuffer == nil {
		return -1, errors.New("failed to allocate the external resource error buffer")
	}
	defer C.free(unsafe.Pointer(errorBuffer))

	state := C.simple_assets_resource_state(cResourceType, cResourceName, errorBuffer, errorBufferSize)
	if state < 0 {
		return -1, runtimeError(errorBuffer)
	}

	return int(state), nil
}
