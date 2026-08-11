package resource

/*
#cgo windows CFLAGS: -I${SRCDIR}/../../../darktide-internal-utils/include
#cgo windows LDFLAGS: -L${SRCDIR}/../../../darktide-internal-utils/bin/ucrt64/Release -ldtintutils-core
#include <stdlib.h>
#include "runtime_windows.h"
*/
import "C"

import (
	"encoding/binary"
	"errors"
	"fmt"
	"image/color"
	"image/png"
	"os"
	"unsafe"
)

const (
	mouseCursorHeaderSize   = 20
	maxMouseCursorDimension = 16384
)

func compileMouseCursor(filePath string, hotspotX uint32, hotspotY uint32) ([]byte, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("open mouse cursor image: %w", err)
	}
	defer file.Close()

	configuration, err := png.DecodeConfig(file)
	if err != nil {
		return nil, fmt.Errorf("decode mouse cursor PNG header: %w", err)
	}
	if configuration.Width <= 0 || configuration.Height <= 0 ||
		configuration.Width > maxMouseCursorDimension || configuration.Height > maxMouseCursorDimension {
		return nil, fmt.Errorf("mouse cursor PNG dimensions must be between 1 and %d", maxMouseCursorDimension)
	}
	if hotspotX >= uint32(configuration.Width) || hotspotY >= uint32(configuration.Height) {
		return nil, errors.New("mouse cursor hotspot is outside the PNG dimensions")
	}

	pixelBytes := uint64(configuration.Width) * uint64(configuration.Height) * 4
	maxInt := uint64(^uint(0) >> 1)
	if pixelBytes > uint64(^uint32(0)) || pixelBytes > maxInt-mouseCursorHeaderSize {
		return nil, errors.New("mouse cursor PNG dimensions exceed the compiled resource size")
	}
	if _, err := file.Seek(0, 0); err != nil {
		return nil, fmt.Errorf("rewind mouse cursor PNG: %w", err)
	}
	imageData, err := png.Decode(file)
	if err != nil {
		return nil, fmt.Errorf("decode mouse cursor PNG: %w", err)
	}
	if imageData.Bounds().Dx() != configuration.Width || imageData.Bounds().Dy() != configuration.Height {
		return nil, errors.New("mouse cursor PNG dimensions changed while decoding")
	}

	compiled := make([]byte, mouseCursorHeaderSize+int(pixelBytes))
	binary.LittleEndian.PutUint32(compiled[0:4], uint32(configuration.Width))
	binary.LittleEndian.PutUint32(compiled[4:8], uint32(configuration.Height))
	binary.LittleEndian.PutUint32(compiled[8:12], hotspotX)
	binary.LittleEndian.PutUint32(compiled[12:16], hotspotY)
	binary.LittleEndian.PutUint32(compiled[16:20], uint32(pixelBytes))

	bounds := imageData.Bounds()
	offset := mouseCursorHeaderSize
	for y := bounds.Max.Y - 1; y >= bounds.Min.Y; y-- {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			pixel := color.NRGBAModel.Convert(imageData.At(x, y)).(color.NRGBA)
			compiled[offset] = pixel.B
			compiled[offset+1] = pixel.G
			compiled[offset+2] = pixel.R
			compiled[offset+3] = pixel.A
			offset += 4
		}
	}

	return compiled, nil
}

func registerMouseCursor(
	resourceName string,
	filePath string,
	carrierPath string,
	compiled []byte,
) error {
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

	if C.simple_assets_mouse_cursor_load(
		cResourceName,
		cFilePath,
		cCarrierPath,
		unsafe.Pointer(&compiled[0]),
		C.size_t(len(compiled)),
		errorBuffer,
		errorBufferSize,
	) == 0 {
		return runtimeError(errorBuffer)
	}

	return nil
}
