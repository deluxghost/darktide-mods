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
	"sync"
	"time"

	"darktide-simple-assets-runtime/internal/assetpaths"
)

const (
	routeAssets = "/assets"
)

type Server struct {
	mu      sync.Mutex
	server  *http.Server
	baseURL string
	listen  string
	paths   *assetpaths.Resolver
}

func New() *Server {
	return &Server{}
}

func (server *Server) Start(paths *assetpaths.Resolver) error {
	server.mu.Lock()
	defer server.mu.Unlock()

	if server.server != nil {
		return nil
	}
	if paths == nil {
		return errors.New("asset path resolver is not initialized")
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
		Handler:           server.routes(paths),
		ReadHeaderTimeout: 5 * time.Second,
	}

	server.server = httpServer
	server.baseURL = baseURL
	server.listen = listen
	server.paths = paths

	go func() {
		err := httpServer.Serve(listener)
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			server.mu.Lock()
			if server.server == httpServer {
				server.server = nil
				server.baseURL = ""
				server.listen = ""
				server.paths = nil
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
	server.paths = nil
	server.mu.Unlock()

	if httpServer == nil {
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	_ = httpServer.Shutdown(ctx)
}

func (server *Server) routes(paths *assetpaths.Resolver) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc(routeAssets, func(response http.ResponseWriter, request *http.Request) {
		serveAsset(response, request, paths)
	})

	return mux
}

func serveAsset(response http.ResponseWriter, request *http.Request, paths *assetpaths.Resolver) {
	if request.Method != http.MethodGet {
		http.Error(response, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	rawPath := request.URL.Query().Get("path")
	filePath, status, err := resolveAssetPath(rawPath, paths)
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

	http.ServeContent(response, request, filepath.Base(filePath), info.ModTime(), file)
}

func resolveAssetPath(rawPath string, paths *assetpaths.Resolver) (string, int, error) {
	filePath, err := paths.ResolveFile(rawPath)
	if err == nil {
		return filePath, http.StatusOK, nil
	}
	if errors.Is(err, assetpaths.ErrPathRequired) ||
		errors.Is(err, assetpaths.ErrPathAbsolute) ||
		errors.Is(err, assetpaths.ErrPathFile) {
		return "", http.StatusBadRequest, err
	}
	if errors.Is(err, assetpaths.ErrNotFound) {
		return "", http.StatusNotFound, err
	}

	return "", http.StatusInternalServerError, err
}

func shouldReturnNotFound(err error) bool {
	return errors.Is(err, os.ErrNotExist) || errors.Is(err, os.ErrPermission)
}
