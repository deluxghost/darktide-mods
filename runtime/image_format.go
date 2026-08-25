package main

/*
#include <stdint.h>
*/
import "C"

import (
	"errors"
	"fmt"
	"os"

	"darktide-simple-assets-runtime/internal/imageformat"
)

//export SimpleAssetsRuntime_DetectImageFormat
func SimpleAssetsRuntime_DetectImageFormat(path *C.char) C.int {
	if path == nil {
		setLastError(errors.New("asset path is null"))
		return -1
	}

	filePath, err := resolveAssetFile(C.GoString(path))
	if err != nil {
		setLastError(err)
		return -1
	}

	file, err := os.Open(filePath)
	if err != nil {
		setLastError(fmt.Errorf("open asset file for image format detection: %w", err))
		return -1
	}
	defer file.Close()

	format, err := imageformat.Detect(file)
	if err != nil {
		setLastError(fmt.Errorf("read asset file for image format detection: %w", err))
		return -1
	}

	setLastError(nil)
	return C.int(format)
}
