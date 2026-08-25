package resource

import "darktide-simple-assets-runtime/internal/resource/native"

func LoadIVFVideo(resourceName string, filePath string, carrierPath string) error {
	return native.LoadIVFVideo(resourceName, filePath, carrierPath)
}

func LoadBinkVideo(resourceName string, filePath string, carrierPath string) error {
	return native.LoadBinkVideo(resourceName, filePath, carrierPath)
}

func Replace(resourceType string, targetResourceName string, sourceResourceName string) error {
	return native.Replace(resourceType, targetResourceName, sourceResourceName)
}

func State(resourceType string, resourceName string) (int, error) {
	resources := preparationResources(resourceType, resourceName)
	if len(resources) == 0 {
		resources = []resourceReference{{typeName: resourceType, name: resourceName}}
	}

	state := 1
	for _, current := range resources {
		currentState, err := native.State(current.typeName, current.name)
		if err != nil {
			return -1, err
		}
		if currentState == 0 {
			state = 0
		}
	}

	return state, nil
}
