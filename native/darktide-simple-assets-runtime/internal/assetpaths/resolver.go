package assetpaths

import (
	"errors"
	"fmt"
	"os"
	"path"
	"path/filepath"
	"strings"
)

var (
	ErrNotFound      = errors.New("asset file was not found")
	ErrPathRequired  = errors.New("asset path is required")
	ErrPathInvalid   = errors.New("asset path is not a valid virtual asset path")
	ErrPathOutside   = errors.New("asset path is outside the allowed roots")
	ErrPathFile      = errors.New("asset path must be a file")
	ErrPathExtension = errors.New("resource asset path must have a file extension")
)

type Resolver struct {
	gameRoot     string
	userModsRoot string
}

func New(gameRoot string, userRoot string) (*Resolver, error) {
	absoluteGameRoot, err := requiredDirectory(gameRoot, "game")
	if err != nil {
		return nil, err
	}
	absoluteUserRoot, err := requiredDirectory(userRoot, "user")
	if err != nil {
		return nil, err
	}
	userModsRoot := filepath.Join(absoluteUserRoot, "mods")

	return &Resolver{
		gameRoot:     absoluteGameRoot,
		userModsRoot: userModsRoot,
	}, nil
}

func (resolver *Resolver) VirtualPath(path string) (string, error) {
	if strings.TrimSpace(path) == "" {
		return "", ErrPathRequired
	}
	if filepath.IsAbs(path) {
		return resolver.virtualPathFromAbsolute(path)
	}

	return cleanVirtualPath(path)
}

func (resolver *Resolver) ResolveFile(path string) (string, error) {
	virtualPath, err := resolver.VirtualPath(path)
	if err != nil {
		return "", err
	}

	for _, candidate := range resolver.candidates(virtualPath) {
		info, err := os.Stat(candidate)
		if errors.Is(err, os.ErrNotExist) {
			continue
		}
		if err != nil {
			return "", fmt.Errorf("inspect asset path %q: %w", candidate, err)
		}
		if info.IsDir() {
			return "", ErrPathFile
		}

		absoluteCandidate, err := cleanAbsPath(candidate)
		if err != nil {
			return "", fmt.Errorf("resolve asset path %q: %w", candidate, err)
		}
		if _, underGameRoot := relativeUnderRoot(absoluteCandidate, resolver.gameRoot); !underGameRoot {
			if _, underUserModsRoot := relativeUnderRoot(absoluteCandidate, resolver.userModsRoot); !underUserModsRoot {
				return "", ErrPathOutside
			}
		}

		return absoluteCandidate, nil
	}

	return "", ErrNotFound
}

func ResourceName(virtualPath string) (string, error) {
	extension := path.Ext(virtualPath)
	if extension == "" || extension == "." {
		return "", ErrPathExtension
	}

	name := strings.TrimSuffix(virtualPath, extension)
	return name, nil
}

func (resolver *Resolver) virtualPathFromAbsolute(path string) (string, error) {
	absolutePath, err := cleanAbsPath(path)
	if err != nil {
		return "", err
	}

	if relativePath, ok := relativeUnderRoot(absolutePath, resolver.userModsRoot); ok {
		if relativePath == "." {
			return "mods", nil
		}

		return cleanVirtualPath(filepath.Join("mods", relativePath))
	}
	if relativePath, ok := relativeUnderRoot(absolutePath, resolver.gameRoot); ok {
		if relativePath == "." {
			return "", ErrPathInvalid
		}

		return cleanVirtualPath(relativePath)
	}

	return "", ErrPathOutside
}

func (resolver *Resolver) candidates(virtualPath string) []string {
	if virtualPath == "mods" {
		return []string{resolver.userModsRoot, filepath.Join(resolver.gameRoot, "mods")}
	}
	if strings.HasPrefix(virtualPath, "mods/") {
		relativePath := filepath.FromSlash(strings.TrimPrefix(virtualPath, "mods/"))

		return []string{
			filepath.Join(resolver.userModsRoot, relativePath),
			filepath.Join(resolver.gameRoot, "mods", relativePath),
		}
	}

	return []string{filepath.Join(resolver.gameRoot, filepath.FromSlash(virtualPath))}
}

func requiredDirectory(path string, description string) (string, error) {
	if strings.TrimSpace(path) == "" {
		return "", fmt.Errorf("%s asset root path is empty", description)
	}

	root, err := cleanAbsPath(path)
	if err != nil {
		return "", fmt.Errorf("resolve %s asset root %q: %w", description, path, err)
	}
	info, err := os.Stat(root)
	if err != nil {
		return "", fmt.Errorf("inspect %s asset root %q: %w", description, path, err)
	}
	if !info.IsDir() {
		return "", fmt.Errorf("%s asset root is not a directory: %s", description, path)
	}

	return root, nil
}

func cleanVirtualPath(path string) (string, error) {
	normalizedPath := strings.ReplaceAll(path, "\\", "/")
	if normalizedPath == "" || strings.HasPrefix(normalizedPath, "/") {
		return "", ErrPathInvalid
	}

	cleanedPath := filepath.ToSlash(filepath.Clean(filepath.FromSlash(normalizedPath)))
	if cleanedPath == "." || cleanedPath == ".." || strings.HasPrefix(cleanedPath, "../") ||
		filepath.IsAbs(cleanedPath) || filepath.VolumeName(cleanedPath) != "" {
		return "", ErrPathInvalid
	}
	if strings.EqualFold(cleanedPath, "mods") {
		return "mods", nil
	}
	if len(cleanedPath) > len("mods/") && strings.EqualFold(cleanedPath[:len("mods/")], "mods/") {
		return "mods/" + cleanedPath[len("mods/"):], nil
	}

	return cleanedPath, nil
}

func cleanAbsPath(path string) (string, error) {
	return filepath.Abs(filepath.Clean(path))
}

func relativeUnderRoot(path string, root string) (string, bool) {
	relativePath, err := filepath.Rel(root, path)
	if err != nil || filepath.IsAbs(relativePath) {
		return "", false
	}
	if relativePath == ".." || strings.HasPrefix(relativePath, ".."+string(os.PathSeparator)) {
		return "", false
	}

	return relativePath, true
}
