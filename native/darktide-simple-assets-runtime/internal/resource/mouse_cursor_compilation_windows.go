package resource

import (
	"encoding/binary"
	"errors"
	"fmt"
	"image/color"
	"image/png"
	"os"
)

const mouseCursorHeaderSize = 20

func compileMouseCursor(filePath string, hotspotX uint32, hotspotY uint32) ([]byte, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("open mouse cursor image: %w", err)
	}
	defer file.Close()

	imageData, err := png.Decode(file)
	if err != nil {
		return nil, fmt.Errorf("decode mouse cursor PNG: %w", err)
	}
	bounds := imageData.Bounds()
	width := bounds.Dx()
	height := bounds.Dy()
	if width <= 0 || height <= 0 {
		return nil, errors.New("mouse cursor PNG dimensions must be positive")
	}
	if hotspotX >= uint32(width) || hotspotY >= uint32(height) {
		return nil, errors.New("mouse cursor hotspot is outside the PNG dimensions")
	}

	pixelBytes := uint64(width) * uint64(height) * 4
	maxInt := uint64(^uint(0) >> 1)
	if pixelBytes > uint64(^uint32(0)) || pixelBytes > maxInt-mouseCursorHeaderSize {
		return nil, errors.New("mouse cursor PNG dimensions exceed the compiled resource size")
	}

	compiled := make([]byte, mouseCursorHeaderSize+int(pixelBytes))
	binary.LittleEndian.PutUint32(compiled[0:4], uint32(width))
	binary.LittleEndian.PutUint32(compiled[4:8], uint32(height))
	binary.LittleEndian.PutUint32(compiled[8:12], hotspotX)
	binary.LittleEndian.PutUint32(compiled[12:16], hotspotY)
	binary.LittleEndian.PutUint32(compiled[16:20], uint32(pixelBytes))

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
