package link

import (
	"errors"
	"fmt"
	"os"

	"golang.org/x/sys/windows/registry"
)

const (
	registryAccess = registry.READ | registry.WRITE | registry.WOW64_64KEY
)

type registryValue struct {
	path  string
	name  string
	value string
}

func expectedRegistryValues() ([]registryValue, error) {
	exePath, err := os.Executable()
	if err != nil {
		return nil, err
	}

	rootPath := `SOFTWARE\Classes\` + scheme

	return []registryValue{
		{path: rootPath, name: "", value: "Darktide"},
		{path: rootPath, name: "URL Protocol", value: ""},
		{path: rootPath + `\DefaultIcon`, name: "", value: fmt.Sprintf("%q,0", exePath)},
		{path: rootPath + `\Shell\Open\Command`, name: "", value: fmt.Sprintf("%q open \"%%1\"", exePath)},
	}, nil
}

func readString(path string, name string) (string, error) {
	key, err := registry.OpenKey(registry.LOCAL_MACHINE, path, registry.QUERY_VALUE|registry.WOW64_64KEY)
	if err != nil {
		return "", err
	}
	defer key.Close()

	value, _, err := key.GetStringValue(name)
	if err != nil {
		return "", err
	}

	return value, nil
}

func setString(path string, name string, value string) error {
	key, _, err := registry.CreateKey(registry.LOCAL_MACHINE, path, registryAccess)
	if err != nil {
		return err
	}
	defer key.Close()

	return key.SetStringValue(name, value)
}

func deleteTree(path string) error {
	key, err := registry.OpenKey(registry.LOCAL_MACHINE, path, registry.READ|registry.WOW64_64KEY)
	if err != nil {
		if errors.Is(err, registry.ErrNotExist) {
			return nil
		}

		return err
	}

	subKeys, err := key.ReadSubKeyNames(-1)
	key.Close()
	if err != nil {
		return err
	}

	for _, subKey := range subKeys {
		if err := deleteTree(path + `\` + subKey); err != nil {
			return err
		}
	}

	err = registry.DeleteKey(registry.LOCAL_MACHINE, path)
	if errors.Is(err, registry.ErrNotExist) {
		return nil
	}

	return err
}

func RegisterNeeded() (bool, error) {
	values, err := expectedRegistryValues()
	if err != nil {
		return true, err
	}

	for _, expected := range values {
		actual, err := readString(expected.path, expected.name)
		if err != nil {
			if errors.Is(err, registry.ErrNotExist) {
				return true, nil
			}

			return true, err
		}
		if actual != expected.value {
			return true, nil
		}
	}

	return false, nil
}

func UnregisterNeeded() (bool, error) {
	key, err := registry.OpenKey(registry.LOCAL_MACHINE, `SOFTWARE\Classes\`+scheme, registry.READ|registry.WOW64_64KEY)
	if err != nil {
		if errors.Is(err, registry.ErrNotExist) {
			return false, nil
		}

		return true, err
	}
	key.Close()

	return true, nil
}

func Register() error {
	values, err := expectedRegistryValues()
	if err != nil {
		return err
	}

	for _, value := range values {
		if err := setString(value.path, value.name, value.value); err != nil {
			return err
		}
	}

	return nil
}

func Unregister() error {
	if err := deleteTree(`SOFTWARE\Classes\` + scheme); err != nil {
		return err
	}

	return nil
}
