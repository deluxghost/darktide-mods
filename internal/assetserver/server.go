package assetserver

import (
	"context"
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/gabriel-vasile/mimetype"
)

const (
	routeAssets     = "/assets"
	defaultMimeType = "application/octet-stream"
)

type Server struct {
	mu      sync.Mutex
	server  *http.Server
	baseURL string
	listen  string
	roots   []string
}

func New() *Server {
	return &Server{}
}

func (server *Server) Start(rootPaths []string) error {
	server.mu.Lock()
	defer server.mu.Unlock()

	if server.server != nil {
		return nil
	}

	roots, err := cleanAbsRoots(rootPaths...)
	if err != nil {
		return err
	}

	listener, err := net.Listen("tcp4", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("failed to listen on loopback: %w", err)
	}

	tcpAddr, ok := listener.Addr().(*net.TCPAddr)
	if !ok {
		_ = listener.Close()
		return errors.New("loopback listener did not return a TCP address")
	}

	baseURL := fmt.Sprintf("http://127.0.0.1:%d", tcpAddr.Port)
	listen := fmt.Sprintf("127.0.0.1:%d", tcpAddr.Port)
	httpServer := &http.Server{
		Handler:           server.routes(roots),
		ReadHeaderTimeout: 5 * time.Second,
	}

	server.server = httpServer
	server.baseURL = baseURL
	server.listen = listen
	server.roots = roots

	go func() {
		err := httpServer.Serve(listener)
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			server.mu.Lock()
			if server.server == httpServer {
				server.server = nil
				server.baseURL = ""
				server.listen = ""
				server.roots = nil
			}
			server.mu.Unlock()
		}
	}()

	return nil
}

func (server *Server) ListenInfo() string {
	server.mu.Lock()
	defer server.mu.Unlock()

	return server.listen
}

func (server *Server) AssetURL(path string) (string, error) {
	server.mu.Lock()
	baseURL := server.baseURL
	running := server.server != nil
	server.mu.Unlock()

	if !running || baseURL == "" {
		return "", errors.New("SimpleAssets runtime is not running")
	}

	query := url.Values{}
	query.Set("path", path)

	return baseURL + routeAssets + "?" + query.Encode(), nil
}

func (server *Server) Shutdown() {
	server.mu.Lock()
	httpServer := server.server
	server.server = nil
	server.baseURL = ""
	server.listen = ""
	server.roots = nil
	server.mu.Unlock()

	if httpServer == nil {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	_ = httpServer.Shutdown(ctx)
}

func (server *Server) routes(roots []string) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc(routeAssets, func(response http.ResponseWriter, request *http.Request) {
		serveAsset(response, request, roots)
	})

	return mux
}

func serveAsset(response http.ResponseWriter, request *http.Request, roots []string) {
	if request.Method != http.MethodGet {
		http.Error(response, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	rawPath := request.URL.Query().Get("path")
	filePath, status, err := resolveAssetPath(rawPath, roots)
	if err != nil {
		http.Error(response, err.Error(), status)
		return
	}

	file, err := os.Open(filePath)
	if err != nil {
		if shouldReturnNotFound(err) {
			http.Error(response, "asset file was not found", http.StatusNotFound)
			return
		}

		http.Error(response, err.Error(), http.StatusInternalServerError)
		return
	}
	defer file.Close()

	info, err := file.Stat()
	if err != nil {
		http.Error(response, err.Error(), http.StatusInternalServerError)
		return
	}

	response.Header().Set("Content-Type", contentType(filePath))
	http.ServeContent(response, request, filepath.Base(filePath), info.ModTime(), file)
}

func resolveAssetPath(rawPath string, roots []string) (string, int, error) {
	if rawPath == "" {
		return "", http.StatusBadRequest, errors.New("asset path is required")
	}
	if !filepath.IsAbs(rawPath) {
		return "", http.StatusBadRequest, errors.New("asset path must be absolute")
	}

	filePath, err := cleanAbsPath(rawPath)
	if err != nil {
		return "", http.StatusInternalServerError, err
	}

	if !isUnderAnyRoot(filePath, roots) {
		return "", http.StatusNotFound, errors.New("asset file was not found")
	}

	info, err := os.Stat(filePath)
	if err != nil {
		if shouldReturnNotFound(err) {
			return "", http.StatusNotFound, errors.New("asset file was not found")
		}

		return "", http.StatusInternalServerError, err
	}
	if info.IsDir() {
		return "", http.StatusBadRequest, errors.New("asset path must be a file")
	}

	return filePath, http.StatusOK, nil
}

func cleanAbsRoots(paths ...string) ([]string, error) {
	roots := make([]string, 0, len(paths))

	for _, path := range paths {
		if strings.TrimSpace(path) == "" {
			return nil, errors.New("asset root path is empty")
		}

		root, err := cleanAbsPath(path)
		if err != nil {
			return nil, fmt.Errorf("failed to resolve asset root %q: %w", path, err)
		}

		info, err := os.Stat(root)
		if err != nil {
			return nil, fmt.Errorf("failed to stat asset root %q: %w", path, err)
		}
		if !info.IsDir() {
			return nil, fmt.Errorf("asset root is not a directory: %s", path)
		}

		if !containsRoot(roots, root) {
			roots = append(roots, root)
		}
	}

	return roots, nil
}

func shouldReturnNotFound(err error) bool {
	return errors.Is(err, os.ErrNotExist) || errors.Is(err, os.ErrPermission)
}

func cleanAbsPath(path string) (string, error) {
	return filepath.Abs(filepath.Clean(path))
}

func containsRoot(roots []string, root string) bool {
	cleanRoot, err := cleanAbsPath(root)
	if err != nil {
		return false
	}

	for _, existing := range roots {
		if samePath(existing, cleanRoot) {
			return true
		}
	}

	return false
}

func isUnderAnyRoot(path string, roots []string) bool {
	for _, root := range roots {
		if isUnderRoot(path, root) {
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

func contentType(path string) string {
	mimeType, err := mimetype.DetectFile(path)
	if err != nil || mimeType == nil {
		return defaultMimeType
	}

	return mimeType.String()
}
