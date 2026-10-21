package resource

import "darktide-simple-assets-runtime/internal/resource/native"

func PrepareMouseCursor(
	resourceName string,
	filePath string,
	carrierPath string,
	hotspotX uint32,
	hotspotY uint32,
) error {
	return startPreparation(
		preparationKey("mouse_cursor", resourceName),
		filePath,
		func() (preparedRegistration, error) {
			data, err := compileMouseCursor(filePath, hotspotX, hotspotY)
			if err != nil {
				return preparedRegistration{}, err
			}

			return preparedRegistration{
				resources: []resourceReference{{typeName: "mouse_cursor", name: resourceName}},
				register: func() error {
					return native.LoadMouseCursor(resourceName, filePath, carrierPath, data)
				},
			}, nil
		},
	)
}
