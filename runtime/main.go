package main

/*
#include <stdlib.h>
*/
import "C"

import (
	"errors"
	"sync"
	"unsafe"

	"darktide-simple-assets-runtime/internal/assetserver"
	"darktide-simple-assets-runtime/internal/runtimepaths"
)

var runtimeServer = assetserver.New()

var stringsMu sync.Mutex
var gameDirString *C.char
var userDirString *C.char
var listenInfoString *C.char
var assetURLString *C.char
var lastErrorString *C.char

func main() {}

//export SimpleAssetsRuntime_Start
func SimpleAssetsRuntime_Start() C.int {
	info, err := runtimepaths.Resolve()
	if err != nil {
		setLastError(err)
		return 0
	}

	if err := runtimeServer.Start(info.Roots); err != nil {
		setLastError(err)
		return 0
	}

	setGameDir(info.GameDir)
	setUserDir(info.UserDir)
	setListenInfo(runtimeServer.ListenInfo())
	setLastError(nil)

	return 1
}

//export SimpleAssetsRuntime_GameDir
func SimpleAssetsRuntime_GameDir() *C.char {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	return gameDirString
}

//export SimpleAssetsRuntime_UserDir
func SimpleAssetsRuntime_UserDir() *C.char {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	return userDirString
}

//export SimpleAssetsRuntime_ListenInfo
func SimpleAssetsRuntime_ListenInfo() *C.char {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	return listenInfoString
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
	stringsMu.Lock()
	defer stringsMu.Unlock()

	return lastErrorString
}

//export SimpleAssetsRuntime_Shutdown
func SimpleAssetsRuntime_Shutdown() {
	runtimeServer.Shutdown()
	clearGameDir()
	clearUserDir()
	clearListenInfo()
	clearAssetURL()
	setLastError(nil)
}

func setGameDir(value string) {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	replaceCString(&gameDirString, value)
}

func clearGameDir() {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	freeCString(&gameDirString)
}

func setUserDir(value string) {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	replaceCString(&userDirString, value)
}

func clearUserDir() {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	freeCString(&userDirString)
}

func setListenInfo(value string) {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	replaceCString(&listenInfoString, value)
}

func clearListenInfo() {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	freeCString(&listenInfoString)
}

func replaceAssetURL(value string) *C.char {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	replaceCString(&assetURLString, value)

	return assetURLString
}

func clearAssetURL() {
	stringsMu.Lock()
	defer stringsMu.Unlock()

	freeCString(&assetURLString)
}

func setLastError(err error) {
	message := ""
	if err != nil {
		message = err.Error()
	}

	stringsMu.Lock()
	defer stringsMu.Unlock()

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
