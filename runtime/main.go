package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"errors"
	"path/filepath"
	"sync"
	"unsafe"

	"darktide-simple-assets-runtime/internal/assetpaths"
	"darktide-simple-assets-runtime/internal/assetserver"
	"darktide-simple-assets-runtime/internal/runtimepaths"
)

var runtimeServer = assetserver.New()

var stateMu sync.Mutex
var gameDirString *C.char
var userDirString *C.char
var assetURLString *C.char
var canonicalAssetPathString *C.char
var lastErrorString *C.char
var assetPathResolver *assetpaths.Resolver
var resourceCarrierPath string

func main() {}

//export SimpleAssetsRuntime_Start
func SimpleAssetsRuntime_Start() C.int {
	info, err := runtimepaths.Resolve()
	if err != nil {
		setLastError(err)
		return 0
	}

	paths, err := assetpaths.New(info.GameDir, info.UserDir)
	if err != nil {
		setLastError(err)
		return 0
	}

	carrierPath, err := paths.ResolveFile(filepath.Join(info.GameDir, "binaries", "Darktide.exe"))
	if err != nil {
		setLastError(err)
		return 0
	}

	if err := runtimeServer.Start(paths); err != nil {
		setLastError(err)
		return 0
	}

	setGameDir(info.GameDir)
	setUserDir(info.UserDir)
	setAssetPathResolver(paths)
	setResourceCarrierPath(carrierPath)
	setLastError(nil)

	return 1
}

//export SimpleAssetsRuntime_CanonicalAssetPath
func SimpleAssetsRuntime_CanonicalAssetPath(path *C.char) *C.char {
	if path == nil {
		setLastError(errors.New("asset path is null"))
		return nil
	}

	virtualPath, err := canonicalAssetPath(C.GoString(path))
	if err != nil {
		setLastError(err)
		return nil
	}

	setLastError(nil)
	return replaceCanonicalAssetPath(virtualPath)
}

//export SimpleAssetsRuntime_GameDir
func SimpleAssetsRuntime_GameDir() *C.char {
	stateMu.Lock()
	defer stateMu.Unlock()

	return gameDirString
}

//export SimpleAssetsRuntime_UserDir
func SimpleAssetsRuntime_UserDir() *C.char {
	stateMu.Lock()
	defer stateMu.Unlock()

	return userDirString
}

//export SimpleAssetsRuntime_AssetUrl
func SimpleAssetsRuntime_AssetUrl(path *C.char) *C.char {
	if path == nil {
		setLastError(errors.New("asset path is null"))
		return nil
	}

	assetURL, err := runtimeServer.AssetURL(C.GoString(path))
	if err != nil {
		setLastError(err)
		return nil
	}

	setLastError(nil)

	return replaceAssetURL(assetURL)
}

//export SimpleAssetsRuntime_LastError
func SimpleAssetsRuntime_LastError() *C.char {
	stateMu.Lock()
	defer stateMu.Unlock()

	return lastErrorString
}

//export SimpleAssetsRuntime_Shutdown
func SimpleAssetsRuntime_Shutdown() {
	runtimeServer.Shutdown()
	clearGameDir()
	clearUserDir()
	clearAssetURL()
	clearCanonicalAssetPath()
	clearAssetPathResolver()
	clearResourceCarrierPath()
	setLastError(nil)
}

func setGameDir(value string) {
	stateMu.Lock()
	defer stateMu.Unlock()

	replaceCString(&gameDirString, value)
}

func clearGameDir() {
	stateMu.Lock()
	defer stateMu.Unlock()

	freeCString(&gameDirString)
}

func setUserDir(value string) {
	stateMu.Lock()
	defer stateMu.Unlock()

	replaceCString(&userDirString, value)
}

func clearUserDir() {
	stateMu.Lock()
	defer stateMu.Unlock()

	freeCString(&userDirString)
}

func replaceAssetURL(value string) *C.char {
	stateMu.Lock()
	defer stateMu.Unlock()

	replaceCString(&assetURLString, value)

	return assetURLString
}

func clearAssetURL() {
	stateMu.Lock()
	defer stateMu.Unlock()

	freeCString(&assetURLString)
}

func replaceCanonicalAssetPath(value string) *C.char {
	stateMu.Lock()
	defer stateMu.Unlock()

	replaceCString(&canonicalAssetPathString, value)

	return canonicalAssetPathString
}

func clearCanonicalAssetPath() {
	stateMu.Lock()
	defer stateMu.Unlock()

	freeCString(&canonicalAssetPathString)
}

func setAssetPathResolver(value *assetpaths.Resolver) {
	stateMu.Lock()
	defer stateMu.Unlock()

	assetPathResolver = value
}

func canonicalAssetPath(path string) (string, error) {
	stateMu.Lock()
	resolver := assetPathResolver
	stateMu.Unlock()

	if resolver == nil {
		return "", errors.New("asset path resolver is not initialized")
	}

	return resolver.VirtualPath(path)
}

func resolveAssetFile(path string) (string, error) {
	stateMu.Lock()
	resolver := assetPathResolver
	stateMu.Unlock()

	if resolver == nil {
		return "", errors.New("asset path resolver is not initialized")
	}

	return resolver.ResolveFile(path)
}

func clearAssetPathResolver() {
	stateMu.Lock()
	defer stateMu.Unlock()

	assetPathResolver = nil
}

func setResourceCarrierPath(value string) {
	stateMu.Lock()
	defer stateMu.Unlock()

	resourceCarrierPath = value
}

func getResourceCarrierPath() string {
	stateMu.Lock()
	defer stateMu.Unlock()

	return resourceCarrierPath
}

func clearResourceCarrierPath() {
	stateMu.Lock()
	defer stateMu.Unlock()

	resourceCarrierPath = ""
}

func setLastError(err error) {
	message := ""
	if err != nil {
		message = err.Error()
	}

	stateMu.Lock()
	defer stateMu.Unlock()

	replaceCString(&lastErrorString, message)
}

func replaceCString(target **C.char, value string) {
	freeCString(target)
	*target = C.CString(value)
}

func freeCString(target **C.char) {
	if *target == nil {
		return
	}

	C.free(unsafe.Pointer(*target))
	*target = nil
}
