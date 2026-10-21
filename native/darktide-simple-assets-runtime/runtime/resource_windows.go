package main

import "C"

import (
	"errors"
	"fmt"
	"path/filepath"
	"strings"

	"darktide-simple-assets-runtime/internal/assetpaths"
	"darktide-simple-assets-runtime/internal/resource"
)

type resourcePreparer func(resourceName string, filePath string, carrierPath string) error

type videoResource struct {
	typeName string
	prepare  resourcePreparer
}

func videoResourceForPath(assetPath string) (videoResource, error) {
	switch strings.ToLower(filepath.Ext(assetPath)) {
	case ".ivf":
		return videoResource{typeName: "ivf", prepare: resource.LoadIVFVideo}, nil
	case ".bk2":
		return videoResource{typeName: "bk2", prepare: resource.LoadBinkVideo}, nil
	default:
		return videoResource{}, errors.New("video asset path must refer to an .ivf or .bk2 file")
	}
}

//export SimpleAssetsRuntime_AnimationLoad
func SimpleAssetsRuntime_AnimationLoad(assetPath *C.char) C.int {
	return loadResource(assetPath, "animation", func(name string, filePath string, carrierPath string) error {
		return resource.PrepareWithBones("animation", name, filePath, carrierPath, true)
	})
}

//export SimpleAssetsRuntime_AnimationReplace
func SimpleAssetsRuntime_AnimationReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	return replaceResource(targetResourcePath, sourceAssetPath, "animation")
}

//export SimpleAssetsRuntime_MaterialLoad
func SimpleAssetsRuntime_MaterialLoad(assetPath *C.char) C.int {
	return loadResource(assetPath, "material", func(name string, filePath string, carrierPath string) error {
		return resource.Prepare("material", name, filePath, carrierPath)
	})
}

//export SimpleAssetsRuntime_MaterialReplace
func SimpleAssetsRuntime_MaterialReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	return replaceResource(targetResourcePath, sourceAssetPath, "material")
}

//export SimpleAssetsRuntime_ParticlesLoad
func SimpleAssetsRuntime_ParticlesLoad(assetPath *C.char) C.int {
	return loadResource(assetPath, "particles", func(name string, filePath string, carrierPath string) error {
		return resource.Prepare("particles", name, filePath, carrierPath)
	})
}

//export SimpleAssetsRuntime_ParticlesReplace
func SimpleAssetsRuntime_ParticlesReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	return replaceResource(targetResourcePath, sourceAssetPath, "particles")
}

//export SimpleAssetsRuntime_FontLoad
func SimpleAssetsRuntime_FontLoad(assetPath *C.char) C.int {
	return loadResource(assetPath, "slug", func(name string, filePath string, carrierPath string) error {
		return resource.Prepare("slug", name, filePath, carrierPath)
	})
}

//export SimpleAssetsRuntime_FontReplace
func SimpleAssetsRuntime_FontReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	return replaceResource(targetResourcePath, sourceAssetPath, "slug")
}

//export SimpleAssetsRuntime_SlugAlbumLoad
func SimpleAssetsRuntime_SlugAlbumLoad(assetPath *C.char) C.int {
	return loadResource(assetPath, "slug_album", func(name string, filePath string, carrierPath string) error {
		return resource.Prepare("slug_album", name, filePath, carrierPath)
	})
}

//export SimpleAssetsRuntime_SlugAlbumReplace
func SimpleAssetsRuntime_SlugAlbumReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	return replaceResource(targetResourcePath, sourceAssetPath, "slug_album")
}

//export SimpleAssetsRuntime_TextureLoad
func SimpleAssetsRuntime_TextureLoad(assetPath *C.char) C.int {
	return loadResource(assetPath, "texture", resource.PrepareTextureResource)
}

//export SimpleAssetsRuntime_TextureReplace
func SimpleAssetsRuntime_TextureReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	return replaceResource(targetResourcePath, sourceAssetPath, "texture")
}

//export SimpleAssetsRuntime_UnitLoad
func SimpleAssetsRuntime_UnitLoad(assetPath *C.char) C.int {
	return loadResource(assetPath, "unit", func(name string, filePath string, carrierPath string) error {
		return resource.PrepareWithBones("unit", name, filePath, carrierPath, false)
	})
}

//export SimpleAssetsRuntime_UnitReplace
func SimpleAssetsRuntime_UnitReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	return replaceResource(targetResourcePath, sourceAssetPath, "unit")
}

//export SimpleAssetsRuntime_VideoLoad
func SimpleAssetsRuntime_VideoLoad(assetPath *C.char) C.int {
	if assetPath == nil {
		setLastError(errors.New("video asset path must not be null"))
		return 0
	}

	video, err := videoResourceForPath(C.GoString(assetPath))
	if err != nil {
		setLastError(err)
		return 0
	}

	return loadResource(assetPath, video.typeName, video.prepare)
}

//export SimpleAssetsRuntime_VideoReplace
func SimpleAssetsRuntime_VideoReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	if targetResourcePath == nil || sourceAssetPath == nil {
		setLastError(errors.New("video target resource path and source asset path must not be null"))
		return 0
	}

	target, err := videoResourceForPath(C.GoString(targetResourcePath))
	if err != nil {
		setLastError(err)
		return 0
	}
	source, err := videoResourceForPath(C.GoString(sourceAssetPath))
	if err != nil {
		setLastError(err)
		return 0
	}
	if target.typeName != source.typeName {
		setLastError(errors.New("video target and source paths must use the same .ivf or .bk2 extension"))
		return 0
	}

	return replaceResource(targetResourcePath, sourceAssetPath, source.typeName)
}

//export SimpleAssetsRuntime_MouseCursorLoad
func SimpleAssetsRuntime_MouseCursorLoad(
	assetPath *C.char,
	hotspotX C.uint,
	hotspotY C.uint,
) C.int {
	if assetPath == nil {
		setLastError(errors.New("mouse cursor asset path must not be null"))
		return 0
	}

	name, resolvedPath, err := resolveResourceAsset(C.GoString(assetPath))
	if err != nil {
		setLastError(err)
		return 0
	}

	carrierPath := getResourceCarrierPath()
	if carrierPath == "" {
		setLastError(errors.New("resource I/O carrier path is unavailable"))
		return 0
	}

	if err := resource.PrepareMouseCursor(
		name,
		resolvedPath,
		carrierPath,
		uint32(hotspotX),
		uint32(hotspotY),
	); err != nil {
		setLastError(err)
		return 0
	}

	setLastError(nil)
	return 1
}

//export SimpleAssetsRuntime_MouseCursorReplace
func SimpleAssetsRuntime_MouseCursorReplace(targetResourcePath *C.char, sourceAssetPath *C.char) C.int {
	return replaceResource(targetResourcePath, sourceAssetPath, "mouse_cursor")
}

//export SimpleAssetsRuntime_ResourceState
func SimpleAssetsRuntime_ResourceState(resourceType *C.char, assetPath *C.char) C.int {
	if resourceType == nil || assetPath == nil {
		setLastError(errors.New("resource type and asset path must not be null"))
		return -1
	}

	typeName := C.GoString(resourceType)
	if typeName == "" {
		setLastError(errors.New("resource type must not be empty"))
		return -1
	}
	name, err := resourceNameFromAssetPath(C.GoString(assetPath))
	if err != nil {
		setLastError(err)
		return -1
	}
	managed, registered, err := resource.Advance(typeName, name)
	if err != nil {
		setLastError(err)
		return -1
	}
	if managed && !registered {
		setLastError(nil)
		return 2
	}

	state, err := resource.State(typeName, name)
	if err != nil {
		setLastError(err)
		return -1
	}

	setLastError(nil)
	return C.int(state)
}

func resolveResourceAsset(assetPath string) (string, string, error) {
	virtualPath, err := canonicalAssetPath(assetPath)
	if err != nil {
		return "", "", err
	}
	name, err := assetpaths.ResourceName(virtualPath)
	if err != nil {
		return "", "", err
	}
	resolvedPath, err := resolveAssetFile(virtualPath)
	if err != nil {
		return "", "", err
	}

	return name, resolvedPath, nil
}

func resourceNameFromAssetPath(assetPath string) (string, error) {
	virtualPath, err := canonicalAssetPath(assetPath)
	if err != nil {
		return "", err
	}

	return assetpaths.ResourceName(virtualPath)
}

func loadResource(assetPath *C.char, resourceType string, prepare resourcePreparer) C.int {
	if assetPath == nil {
		setLastError(fmt.Errorf("%s asset path must not be null", resourceType))
		return 0
	}

	name, resolvedPath, err := resolveResourceAsset(C.GoString(assetPath))
	if err != nil {
		setLastError(fmt.Errorf("resolve %s asset path: %w", resourceType, err))
		return 0
	}

	carrierPath := getResourceCarrierPath()
	if carrierPath == "" {
		setLastError(errors.New("resource I/O carrier path is unavailable"))
		return 0
	}

	if err := prepare(name, resolvedPath, carrierPath); err != nil {
		setLastError(err)
		return 0
	}

	setLastError(nil)
	return 1
}

func replaceResource(targetResourcePath *C.char, sourceAssetPath *C.char, resourceType string) C.int {
	if targetResourcePath == nil || sourceAssetPath == nil {
		setLastError(fmt.Errorf("%s target resource path and source asset path must not be null", resourceType))
		return 0
	}

	targetName, err := resourceNameFromAssetPath(C.GoString(targetResourcePath))
	if err != nil {
		setLastError(fmt.Errorf("resolve %s target resource path: %w", resourceType, err))
		return 0
	}
	sourceName, err := resourceNameFromAssetPath(C.GoString(sourceAssetPath))
	if err != nil {
		setLastError(fmt.Errorf("resolve %s source asset path: %w", resourceType, err))
		return 0
	}
	if err := resource.Replace(resourceType, targetName, sourceName); err != nil {
		setLastError(err)
		return 0
	}

	setLastError(nil)
	return 1
}
