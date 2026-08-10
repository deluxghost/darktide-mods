package main

import "C"

import (
	"errors"

	"darktide-simple-assets-runtime/internal/resource"
)

//export SimpleAssetsRuntime_ResourceLoad
func SimpleAssetsRuntime_ResourceLoad(resourceType *C.char, resourceName *C.char, filePath *C.char) C.int {
	if resourceType == nil || resourceName == nil || filePath == nil {
		setLastError(errors.New("resource type, name, and path must not be null"))
		return 0
	}

	resolvedPath, err := resolveAssetFile(C.GoString(filePath))
	if err != nil {
		setLastError(err)
		return 0
	}

	carrierPath := getResourceCarrierPath()
	if carrierPath == "" {
		setLastError(errors.New("resource I/O carrier path is unavailable"))
		return 0
	}

	if err := resource.Load(C.GoString(resourceType), C.GoString(resourceName), resolvedPath, carrierPath); err != nil {
		setLastError(err)
		return 0
	}

	setLastError(nil)
	return 1
}

//export SimpleAssetsRuntime_ResourceState
func SimpleAssetsRuntime_ResourceState(resourceType *C.char, resourceName *C.char) C.int {
	if resourceType == nil || resourceName == nil {
		setLastError(errors.New("resource type and name must not be empty"))
		return -1
	}

	typeName := C.GoString(resourceType)
	name := C.GoString(resourceName)
	if typeName == "" || name == "" {
		setLastError(errors.New("resource type and name must not be empty"))
		return -1
	}

	state, err := resource.State(typeName, name)
	if err != nil {
		setLastError(err)
		return -1
	}

	setLastError(nil)
	return C.int(state)
}
