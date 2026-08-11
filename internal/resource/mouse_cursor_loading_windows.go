package resource

import (
	"fmt"
)

func PrepareMouseCursor(
	resourceName string,
	filePath string,
	carrierPath string,
	hotspotX uint32,
	hotspotY uint32,
) error {
	return startPreparation(
		preparationKey("mouse_cursor", resourceName),
		fmt.Sprintf("%s\x00%s\x00%d\x00%d", filePath, carrierPath, hotspotX, hotspotY),
		func() ([]byte, error) {
			return compileMouseCursor(filePath, hotspotX, hotspotY)
		},
		func(data []byte) error {
			return registerMouseCursor(resourceName, filePath, carrierPath, data)
		},
	)
}
