package assetpaths

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

var (
	ErrNotFound      = errors.New("asset file was not found")
	ErrPathRequired  = errors.New("asset path is required")
	ErrPathAbsolute  = errors.New("asset path must be absolute")
	ErrPathFile      = errors.New("asset path must be a file")
	ErrPathDirectory = errors.New("asset path must be a directory")
)

type Resolver struct {
	roots []string
}

func New(rootPaths []string) (*Resolver, error) {
	roots := make([]string, 0, len(rootPaths))

	for _, rootPath := range rootPaths {
		if strings.TrimSpace(rootPath) == "" {
			return nil, errors.New("asset root path is empty")
		}

		root, err := cleanAbsPath(rootPath)
		if err != nil {
			return nil, fmt.Errorf("failed to resolve asset root %q: %w", rootPath, err)
		}

		info, err := os.Stat(root)
		if err != nil {
			return nil, fmt.Errorf("failed to stat asset root %q: %w", rootPath, err)
		}
		if !info.IsDir() {
			return nil, fmt.Errorf("asset root is not a directory: %s", rootPath)
		}
		if !containsPath(roots, root) {
			roots = append(roots, root)
		}
	}

	if len(roots) == 0 {
		return nil, errors.New("no asset roots were resolved")
	}

	return &Resolver{roots: roots}, nil
}

func (resolver *Resolver) ResolveFile(path string) (string, error) {
	return resolver.resolve(path, false)
}

func (resolver *Resolver) ResolveDirectory(path string) (string, error) {
	return resolver.resolve(path, true)
}

func (resolver *Resolver) resolve(path string, directory bool) (string, error) {
	if path == "" {
		return "", ErrPathRequired
	}
	if !filepath.IsAbs(path) {
		return "", ErrPathAbsolute
	}

	resolvedPath, err := cleanAbsPath(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) || errors.Is(err, os.ErrPermission) {
			return "", ErrNotFound
		}

		return "", err
	}
	if !resolver.isAllowed(resolvedPath) {
		return "", ErrNotFound
	}

	info, err := os.Stat(resolvedPath)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) || errors.Is(err, os.ErrPermission) {
			return "", ErrNotFound
		}

		return "", err
	}
	if directory && !info.IsDir() {
		return "", ErrPathDirectory
	}
	if !directory && info.IsDir() {
		return "", ErrPathFile
	}

	return resolvedPath, nil
}

func (resolver *Resolver) isAllowed(path string) bool {
	for _, root := range resolver.roots {
		if isUnderRoot(path, root) {
			return true
		}
	}

	return false
}

func cleanAbsPath(path string) (string, error) {
	return filepath.Abs(filepath.Clean(path))
}

func containsPath(paths []string, path string) bool {
	for _, existing := range paths {
		if samePath(existing, path) {
			return true
		}
	}

	return false
}

func isUnderRoot(path string, root string) bool {
	if samePath(path, root) {
		return true
	}

	relativePath, err := filepath.Rel(root, path)
	if err != nil {
		return false
	}

	return relativePath != ".." &&
		!strings.HasPrefix(relativePath, ".."+string(os.PathSeparator)) &&
		!filepath.IsAbs(relativePath)
}

func samePath(left string, right string) bool {
	return strings.EqualFold(filepath.Clean(left), filepath.Clean(right))
}
