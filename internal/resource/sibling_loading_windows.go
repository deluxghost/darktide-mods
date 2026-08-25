package resource

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"darktide-simple-assets-runtime/internal/resource/native"
)

const (
	bonesResourceType = "bones"
	bonesExtension    = ".bones"
)

func PrepareWithBones(
	resourceType string,
	resourceName string,
	filePath string,
	carrierPath string,
	required bool,
) error {
	mainExtension := filepath.Ext(filePath)
	if mainExtension == "" {
		return errors.New("main resource path has no extension")
	}
	bonesPath := strings.TrimSuffix(filePath, mainExtension) + bonesExtension
	return startPreparation(
		preparationKey(resourceType, resourceName),
		filePath,
		func() (preparedRegistration, error) {
			mainData, err := readResourceFile(resourceType, filePath)
			if err != nil {
				return preparedRegistration{}, err
			}
			bonesData, exists, err := readOptionalResourceFile(bonesResourceType, bonesPath)
			if err != nil {
				return preparedRegistration{}, err
			}
			if required && !exists {
				return preparedRegistration{}, fmt.Errorf("required bones resource was not found: %s", bonesPath)
			}

			resources := make([]resourceReference, 0, 2)
			if exists {
				resources = append(resources, resourceReference{typeName: bonesResourceType, name: resourceName})
			}
			resources = append(resources, resourceReference{typeName: resourceType, name: resourceName})

			return preparedRegistration{
				resources: resources,
				register: func() error {
					if exists {
						if err := native.LoadResource(
							bonesResourceType,
							resourceName,
							bonesPath,
							carrierPath,
							bonesData,
						); err != nil {
							return err
						}
					}

					return native.LoadResource(resourceType, resourceName, filePath, carrierPath, mainData)
				},
			}, nil
		},
	)
}

func readOptionalResourceFile(resourceType string, filePath string) ([]byte, bool, error) {
	data, err := os.ReadFile(filePath)
	if errors.Is(err, os.ErrNotExist) {
		return nil, false, nil
	}
	if err != nil {
		return nil, false, fmt.Errorf("read external %s resource: %w", resourceType, err)
	}
	if len(data) == 0 {
		return nil, false, fmt.Errorf("external %s resource file is empty", resourceType)
	}

	return data, true, nil
}
