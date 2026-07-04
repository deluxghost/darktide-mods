package runtimepaths

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"unsafe"
)

const (
	errorInsufficientBuffer = syscall.Errno(122)
	appmodelErrorNoPackage  = syscall.Errno(15700)
)

var (
	kernel32 = syscall.NewLazyDLL("kernel32.dll")

	procGetCurrentPackageFullName = kernel32.NewProc("GetCurrentPackageFullName")
	procGetModuleFileNameW        = kernel32.NewProc("GetModuleFileNameW")
)

type Info struct {
	GameDir string
	UserDir string
	Roots   []string
}

func Resolve() (Info, error) {
	fallbackGameDir, err := cleanAbsPath("..")
	if err != nil {
		return Info{}, fmt.Errorf("failed to resolve runtime game directory: %w", err)
	}

	_, isPackaged, err := currentPackageFullName()
	if err != nil {
		return Info{}, err
	}

	gameDir := fallbackGameDir
	if isPackaged {
		gameDir, err = packagedGameDir()
		if err != nil {
			return Info{}, err
		}
	}

	userDir, err := userDir(isPackaged)
	if err != nil {
		return Info{}, err
	}

	roots := make([]string, 0, 2)
	appendUniquePath(&roots, gameDir)
	appendUniquePath(&roots, userDir)

	if len(roots) == 0 {
		return Info{}, errors.New("no asset roots were resolved")
	}

	return Info{
		GameDir: gameDir,
		UserDir: userDir,
		Roots:   roots,
	}, nil
}

func currentPackageFullName() (string, bool, error) {
	var length uint32
	result, _, _ := procGetCurrentPackageFullName.Call(
		uintptr(unsafe.Pointer(&length)),
		0,
	)

	if syscall.Errno(result) == appmodelErrorNoPackage {
		return "", false, nil
	}
	if result != uintptr(errorInsufficientBuffer) {
		return "", false, fmt.Errorf("GetCurrentPackageFullName failed: %w", syscall.Errno(result))
	}

	buffer := make([]uint16, length)
	result, _, _ = procGetCurrentPackageFullName.Call(
		uintptr(unsafe.Pointer(&length)),
		uintptr(unsafe.Pointer(&buffer[0])),
	)

	if result != 0 {
		return "", false, fmt.Errorf("GetCurrentPackageFullName failed: %w", syscall.Errno(result))
	}

	return syscall.UTF16ToString(buffer), true, nil
}

func userDir(isPackaged bool) (string, error) {
	appData := os.Getenv("AppData")
	if appData == "" {
		return "", errors.New("AppData environment variable is not set")
	}

	if isPackaged {
		return normalizePath(filepath.Join(appData, "Fatshark", "MicrosoftStore", "Darktide")), nil
	}

	return normalizePath(filepath.Join(appData, "Fatshark", "Darktide")), nil
}

func packagedGameDir() (string, error) {
	executablePath, err := currentExecutablePath()
	if err != nil {
		return "", err
	}

	binariesDir := filepath.Dir(executablePath)
	if !strings.EqualFold(filepath.Base(binariesDir), "binaries") {
		return "", fmt.Errorf("packaged executable is not in a binaries directory: %s", executablePath)
	}

	gameDir := normalizePath(filepath.Dir(binariesDir))
	if !isDirectory(gameDir) {
		return "", fmt.Errorf("packaged game directory does not exist: %s", gameDir)
	}

	return gameDir, nil
}

func currentExecutablePath() (string, error) {
	size := uint32(260)
	for {
		buffer := make([]uint16, size)
		length, _, err := procGetModuleFileNameW.Call(
			0,
			uintptr(unsafe.Pointer(&buffer[0])),
			uintptr(size),
		)

		if length == 0 {
			return "", fmt.Errorf("GetModuleFileNameW failed: %w", err)
		}

		if uint32(length) < size-1 {
			return normalizePath(syscall.UTF16ToString(buffer[:int(length)])), nil
		}

		size *= 2
	}
}

func cleanAbsPath(path string) (string, error) {
	absolutePath, err := filepath.Abs(filepath.Clean(path))
	if err != nil {
		return "", err
	}

	return normalizePath(absolutePath), nil
}

func normalizePath(path string) string {
	return strings.TrimRight(strings.ReplaceAll(path, "\\", "/"), "/")
}

func isDirectory(path string) bool {
	info, err := os.Stat(path)

	return err == nil && info.IsDir()
}

func appendUniquePath(paths *[]string, path string) {
	normalizedPath := normalizePath(path)
	for _, existing := range *paths {
		if strings.EqualFold(existing, normalizedPath) {
			return
		}
	}

	*paths = append(*paths, normalizedPath)
}
