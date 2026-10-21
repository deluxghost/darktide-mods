package runtimepipe

import (
	"encoding/json"
	"errors"
	"net"
	"sync"
	"sync/atomic"

	"dt-cli/internal/protocol"

	"github.com/Microsoft/go-winio"
)

const (
	PipeBufferSize   = 65536
	RequestQueueSize = 256
)

var (
	ErrQueueFull      = errors.New("request queue is full")
	ErrUnknownRequest = errors.New("request is not pending")
)

type Request struct {
	ID      int
	Payload []byte
}

type Server struct {
	mu       sync.Mutex
	listener net.Listener
	done     chan struct{}
	requests chan Request
	pending  map[int]chan []byte
	conns    map[net.Conn]struct{}
	nextID   atomic.Int64
	wg       sync.WaitGroup
}

func New() *Server {
	return &Server{
		requests: make(chan Request, RequestQueueSize),
		pending:  make(map[int]chan []byte),
		conns:    make(map[net.Conn]struct{}),
	}
}

func (s *Server) Start(pipeName string) error {
	s.mu.Lock()
	if s.listener != nil {
		s.mu.Unlock()
		return nil
	}
	s.mu.Unlock()

	listener, err := winio.ListenPipe(pipeName, &winio.PipeConfig{
		InputBufferSize:  PipeBufferSize,
		OutputBufferSize: PipeBufferSize,
	})
	if err != nil {
		return err
	}

	done := make(chan struct{})
	requests := make(chan Request, RequestQueueSize)

	s.mu.Lock()
	if s.listener != nil {
		s.mu.Unlock()
		_ = listener.Close()
		return nil
	}
	s.listener = listener
	s.done = done
	s.requests = requests
	s.pending = make(map[int]chan []byte)
	s.conns = make(map[net.Conn]struct{})
	s.mu.Unlock()

	s.wg.Add(1)
	go s.acceptLoop(listener, done, requests)

	return nil
}

func (s *Server) Stop() {
	s.mu.Lock()
	listener := s.listener
	done := s.done
	pending := s.pending
	conns := s.conns

	if listener == nil {
		s.mu.Unlock()
		return
	}

	s.listener = nil
	s.done = nil
	s.pending = make(map[int]chan []byte)
	s.conns = make(map[net.Conn]struct{})

	for id, response := range pending {
		close(response)
		delete(pending, id)
	}
	for conn := range conns {
		_ = conn.Close()
	}

	close(done)
	s.mu.Unlock()

	_ = listener.Close()
	s.wg.Wait()
}

func (s *Server) PollRequest() (Request, bool) {
	s.mu.Lock()
	requests := s.requests
	running := s.listener != nil
	s.mu.Unlock()

	if !running {
		return Request{}, false
	}

	select {
	case request := <-requests:
		return request, true
	default:
		return Request{}, false
	}
}

func (s *Server) Respond(requestID int, payload []byte) error {
	s.mu.Lock()
	response, ok := s.pending[requestID]
	if ok {
		delete(s.pending, requestID)
	}
	s.mu.Unlock()

	if !ok {
		return ErrUnknownRequest
	}

	if len(payload) > protocol.MaxFrameBytes {
		payload = errorPayload("LuaExec response is too large")
	}

	response <- payload
	close(response)

	return nil
}

func (s *Server) acceptLoop(listener net.Listener, done <-chan struct{}, requests chan<- Request) {
	defer s.wg.Done()

	for {
		conn, err := listener.Accept()
		if err != nil {
			select {
			case <-done:
				return
			default:
				return
			}
		}

		if !s.addConn(conn) {
			_ = conn.Close()
			continue
		}

		s.wg.Add(1)
		go s.handleConn(conn, done, requests)
	}
}

func (s *Server) handleConn(conn net.Conn, done <-chan struct{}, requests chan<- Request) {
	defer s.wg.Done()
	defer func() {
		s.removeConn(conn)
		_ = conn.Close()
	}()

	payload, err := protocol.ReadFrame(conn)
	if err != nil {
		return
	}

	requestID := int(s.nextID.Add(1))
	response := make(chan []byte, 1)

	if !s.registerRequest(requestID, response) {
		writeErrorFrame(conn, "LuaExec runtime is not running")
		return
	}

	select {
	case requests <- Request{ID: requestID, Payload: payload}:
	case <-done:
		s.removeRequest(requestID)
		return
	default:
		s.removeRequest(requestID)
		writeErrorFrame(conn, ErrQueueFull.Error())
		return
	}

	select {
	case payload, ok := <-response:
		if ok {
			_ = protocol.WriteFrame(conn, payload)
		}
	case <-done:
		s.removeRequest(requestID)
	}
}

func (s *Server) registerRequest(requestID int, response chan []byte) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.listener == nil {
		return false
	}

	s.pending[requestID] = response

	return true
}

func (s *Server) removeRequest(requestID int) {
	s.mu.Lock()
	delete(s.pending, requestID)
	s.mu.Unlock()
}

func (s *Server) addConn(conn net.Conn) bool {
	s.mu.Lock()
	defer s.mu.Unlock()

	if s.listener == nil {
		return false
	}

	s.conns[conn] = struct{}{}

	return true
}

func (s *Server) removeConn(conn net.Conn) {
	s.mu.Lock()
	delete(s.conns, conn)
	s.mu.Unlock()
}

func writeErrorFrame(conn net.Conn, message string) {
	_ = protocol.WriteFrame(conn, errorPayload(message))
}

func errorPayload(message string) []byte {
	payload, err := json.Marshal(struct {
		OK    bool   `json:"ok"`
		Error string `json:"error"`
	}{
		OK:    false,
		Error: message,
	})
	if err != nil {
		return []byte(`{"ok":false,"error":"LuaExec runtime failed to encode error response"}`)
	}

	return payload
}
