package imageformat

import (
	"bytes"
	"errors"
	"io"
)

type Format int

const (
	Unknown Format = 0
	PNG     Format = 1
	JPEG    Format = 2
	DDS     Format = 3
)

const (
	pngMediaType  = "image/png"
	jpegMediaType = "image/jpeg"
	ddsMediaType  = "image/vnd.ms-dds"
)

var pngSignature = []byte{0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a}

func Detect(reader io.ReaderAt) (Format, error) {
	var header [8]byte
	read, err := reader.ReadAt(header[:], 0)
	if err != nil && !errors.Is(err, io.EOF) {
		return Unknown, err
	}

	if read >= len(pngSignature) && bytes.Equal(header[:len(pngSignature)], pngSignature) {
		return PNG, nil
	}
	if read >= 3 && header[0] == 0xff && header[1] == 0xd8 && header[2] == 0xff {
		return JPEG, nil
	}
	if read >= 4 && bytes.Equal(header[:4], []byte("DDS ")) {
		return DDS, nil
	}

	return Unknown, nil
}

func (format Format) MediaType() string {
	switch format {
	case PNG:
		return pngMediaType
	case JPEG:
		return jpegMediaType
	case DDS:
		return ddsMediaType
	default:
		return ""
	}
}
