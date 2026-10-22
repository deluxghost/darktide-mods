package native

/*
#include <stdlib.h>
#include "runtime_windows.h"
*/
import "C"

import (
	"errors"
	"unsafe"
)

const errorBufferSize = 1024

type errorBuffer [errorBufferSize]C.char

func (buffer *errorBuffer) pointer() *C.char {
	return &buffer[0]
}

func (buffer *errorBuffer) err() error {
	message := C.GoString(buffer.pointer())
	if message == "" {
		message = "external resource runtime failed without an error message"
	}

	return errors.New(message)
}

func LoadResource(
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

	var buffer errorBuffer
	if C.simple_assets_resource_load(
		cResourceType,
		cResourceName,
		cFilePath,
		cCarrierPath,
		unsafe.Pointer(&data[0]),
		C.size_t(len(data)),
		buffer.pointer(),
		C.size_t(errorBufferSize),
	) == 0 {
		return buffer.err()
	}

	return nil
}

func LoadTexture(
	resourceName string,
	filePath string,
	carrierPath string,
	data []byte,
	streamPath string,
	streamSize uint64,
) error {
	if len(data) == 0 {
		return errors.New("external texture resource data is empty")
	}

	cResourceName := C.CString(resourceName)
	defer C.free(unsafe.Pointer(cResourceName))
	cFilePath := C.CString(filePath)
	defer C.free(unsafe.Pointer(cFilePath))
	cCarrierPath := C.CString(carrierPath)
	defer C.free(unsafe.Pointer(cCarrierPath))

	var cStreamPath *C.char
	if streamPath != "" {
		cStreamPath = C.CString(streamPath)
		defer C.free(unsafe.Pointer(cStreamPath))
	}

	var buffer errorBuffer
	if C.simple_assets_texture_resource_load(
		cResourceName,
		cFilePath,
		cCarrierPath,
		unsafe.Pointer(&data[0]),
		C.size_t(len(data)),
		cStreamPath,
		C.size_t(streamSize),
		buffer.pointer(),
		C.size_t(errorBufferSize),
	) == 0 {
		return buffer.err()
	}

	return nil
}

func LoadMouseCursor(
	resourceName string,
	filePath string,
	carrierPath string,
	compiled []byte,
) error {
	if len(compiled) == 0 {
		return errors.New("compiled mouse cursor data is empty")
	}

	cResourceName := C.CString(resourceName)
	defer C.free(unsafe.Pointer(cResourceName))
	cFilePath := C.CString(filePath)
	defer C.free(unsafe.Pointer(cFilePath))
	cCarrierPath := C.CString(carrierPath)
	defer C.free(unsafe.Pointer(cCarrierPath))

	var buffer errorBuffer
	if C.simple_assets_mouse_cursor_load(
		cResourceName,
		cFilePath,
		cCarrierPath,
		unsafe.Pointer(&compiled[0]),
		C.size_t(len(compiled)),
		buffer.pointer(),
		C.size_t(errorBufferSize),
	) == 0 {
		return buffer.err()
	}

	return nil
}

func LoadIVFVideo(resourceName string, filePath string, carrierPath string) error {
	cResourceName := C.CString(resourceName)
	defer C.free(unsafe.Pointer(cResourceName))
	cFilePath := C.CString(filePath)
	defer C.free(unsafe.Pointer(cFilePath))
	cCarrierPath := C.CString(carrierPath)
	defer C.free(unsafe.Pointer(cCarrierPath))

	var buffer errorBuffer
	if C.simple_assets_ivf_video_load(
		cResourceName,
		cFilePath,
		cCarrierPath,
		buffer.pointer(),
		C.size_t(errorBufferSize),
	) == 0 {
		return buffer.err()
	}

	return nil
}

func LoadBinkVideo(resourceName string, filePath string, carrierPath string) error {
	cResourceName := C.CString(resourceName)
	defer C.free(unsafe.Pointer(cResourceName))
	cFilePath := C.CString(filePath)
	defer C.free(unsafe.Pointer(cFilePath))
	cCarrierPath := C.CString(carrierPath)
	defer C.free(unsafe.Pointer(cCarrierPath))

	var buffer errorBuffer
	if C.simple_assets_bink_video_load(
		cResourceName,
		cFilePath,
		cCarrierPath,
		buffer.pointer(),
		C.size_t(errorBufferSize),
	) == 0 {
		return buffer.err()
	}

	return nil
}
func Replace(resourceType string, targetResourceName string, sourceResourceName string) error {
	cResourceType := C.CString(resourceType)
	defer C.free(unsafe.Pointer(cResourceType))
	cTargetResourceName := C.CString(targetResourceName)
	defer C.free(unsafe.Pointer(cTargetResourceName))
	cSourceResourceName := C.CString(sourceResourceName)
	defer C.free(unsafe.Pointer(cSourceResourceName))

	var buffer errorBuffer
	if C.simple_assets_resource_replace(
		cResourceType,
		cTargetResourceName,
		cSourceResourceName,
		buffer.pointer(),
		C.size_t(errorBufferSize),
	) == 0 {
		return buffer.err()
	}

	return nil
}

func State(resourceType string, resourceName string) (int, error) {
	cResourceType := C.CString(resourceType)
	defer C.free(unsafe.Pointer(cResourceType))
	cResourceName := C.CString(resourceName)
	defer C.free(unsafe.Pointer(cResourceName))

	var buffer errorBuffer
	state := C.simple_assets_resource_state(
		cResourceType,
		cResourceName,
		buffer.pointer(),
		C.size_t(errorBufferSize),
	)
	if state < 0 {
		return -1, buffer.err()
	}

	return int(state), nil
}
