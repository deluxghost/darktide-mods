package link

import (
	"os"

	"golang.org/x/sys/windows"
)

const (
	swNormal = 1
)

func IsElevated() bool {
	return windows.GetCurrentProcessToken().IsElevated()
}

func RunElevated(command string) error {
	exePath, err := os.Executable()
	if err != nil {
		return err
	}

	verb, _ := windows.UTF16PtrFromString("runas")
	file, _ := windows.UTF16PtrFromString(exePath)
	params, _ := windows.UTF16PtrFromString(command)

	return windows.ShellExecute(0, verb, file, params, nil, swNormal)
}
