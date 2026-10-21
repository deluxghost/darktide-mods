package resource

import (
	"errors"
	"fmt"
	"os"

	"darktide-simple-assets-runtime/internal/resource/native"
)

const textureStreamSuffix = ".stream"

func PrepareTextureResource(resourceName string, filePath string, carrierPath string) error {
	streamPath := filePath + textureStreamSuffix
	return startPreparation(
		preparationKey("texture", resourceName),
		filePath,
		func() (preparedRegistration, error) {
			data, err := readResourceFile("texture", filePath)
			if err != nil {
				return preparedRegistration{}, err
			}

			streamSize, err := textureStreamSize(streamPath)
			if err != nil {
				return preparedRegistration{}, err
			}
			preparedStreamPath := ""
			if streamSize != 0 {
				preparedStreamPath = streamPath
			}

			return preparedRegistration{
				resources: []resourceReference{{typeName: "texture", name: resourceName}},
				register: func() error {
					return native.LoadTexture(
						resourceName,
						filePath,
						carrierPath,
						data,
						preparedStreamPath,
						streamSize,
					)
				},
			}, nil
		},
	)
}

func textureStreamSize(filePath string) (uint64, error) {
	info, err := os.Stat(filePath)
	if errors.Is(err, os.ErrNotExist) {
		return 0, nil
	}
	if err != nil {
		return 0, fmt.Errorf("inspect external texture stream: %w", err)
	}
	if !info.Mode().IsRegular() {
		return 0, errors.New("external texture stream is not a regular file")
	}
	if info.Size() <= 0 {
		return 0, errors.New("external texture stream file is empty")
	}
	if uint64(info.Size()) > uint64(^uint32(0)) {
		return 0, errors.New("external texture stream exceeds the engine's 32-bit stream range")
	}

	return uint64(info.Size()), nil
}
