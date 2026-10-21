package main

/*
#cgo windows CFLAGS: -I${SRCDIR}/../../darktide-internal-utils/include
#cgo windows LDFLAGS: -L${SRCDIR}/../../darktide-internal-utils/bin/ucrt64/Release -ldtintutils-core
#include <stdint.h>
#include "log_capture.h"
*/
import "C"

import (
	"fmt"
	"io"
	"net"
	"sync"
	"time"
	"unsafe"

	"dt-cli/internal/logprotocol"

	"github.com/Microsoft/go-winio"
)

const (
	logHistoryBytes = 4 * 1024 * 1024
	logHistoryLines = 8192
	logLineBytes    = 64 * 1024
	logDrainBytes   = 64 * 1024
	logDrainPeriod  = 5 * time.Millisecond
)

type logEntry struct {
	sequence uint64
	line     []byte
}

type logHub struct {
	mu           sync.Mutex
	entries      []logEntry
	bodyBytes    int
	nextSequence uint64
	droppedBytes uint64
	changed      chan struct{}
}

func newLogHub() *logHub {
	return &logHub{
		nextSequence: 1,
		changed:      make(chan struct{}),
	}
}

func (h *logHub) append(line []byte) {
	stored := append([]byte(nil), line...)

	h.mu.Lock()
	h.entries = append(h.entries, logEntry{
		sequence: h.nextSequence,
		line:     stored,
	})
	h.nextSequence++
	h.bodyBytes += len(stored)

	for len(h.entries) > logHistoryLines || h.bodyBytes > logHistoryBytes {
		h.bodyBytes -= len(h.entries[0].line)
		h.entries[0] = logEntry{}
		h.entries = h.entries[1:]
	}
	h.signalLocked()
	h.mu.Unlock()
}

func (h *logHub) addDropped(bytes uint64) {
	if bytes == 0 {
		return
	}

	h.mu.Lock()
	h.droppedBytes += bytes
	h.signalLocked()
	h.mu.Unlock()
}

func (h *logHub) signalLocked() {
	close(h.changed)
	h.changed = make(chan struct{})
}

func (h *logHub) snapshot(lines int) ([]logEntry, uint64, uint64) {
	h.mu.Lock()
	defer h.mu.Unlock()

	start := len(h.entries) - lines
	if start < 0 {
		start = 0
	}

	entries := append([]logEntry(nil), h.entries[start:]...)
	return entries, h.nextSequence, h.droppedBytes
}

func (h *logHub) after(sequence uint64) ([]logEntry, uint64, uint64, uint64, <-chan struct{}) {
	h.mu.Lock()
	defer h.mu.Unlock()

	oldest := h.nextSequence
	if len(h.entries) > 0 {
		oldest = h.entries[0].sequence
	}

	start := 0
	if sequence >= oldest {
		start = int(sequence - oldest)
		if start > len(h.entries) {
			start = len(h.entries)
		}
	}

	entries := append([]logEntry(nil), h.entries[start:]...)
	return entries, oldest, h.nextSequence, h.droppedBytes, h.changed
}

type nativeLogRuntime struct {
	once         sync.Once
	mu           sync.Mutex
	hub          *logHub
	listener     net.Listener
	captureReady chan struct{}
	captureError string
}

func (r *nativeLogRuntime) Start(pipeName string) {
	r.once.Do(func() {
		r.hub = newLogHub()
		r.captureReady = make(chan struct{})

		listener, err := winio.ListenPipe(pipeName, &winio.PipeConfig{
			InputBufferSize:  runtimepipeBufferSize,
			OutputBufferSize: runtimepipeBufferSize,
		})
		if err != nil {
			r.mu.Lock()
			r.captureError = fmt.Sprintf("failed to start logs pipe: %v", err)
			close(r.captureReady)
			r.mu.Unlock()
			return
		}

		r.listener = listener
		go r.acceptLoop()
		go r.initializeCapture()
	})
}

func (r *nativeLogRuntime) initializeCapture() {
	captureError := startLogCapture()

	r.mu.Lock()
	r.captureError = captureError
	close(r.captureReady)
	r.mu.Unlock()

	if captureError == "" {
		r.drainLoop()
	}
}

func (r *nativeLogRuntime) waitForCapture() string {
	<-r.captureReady

	r.mu.Lock()
	defer r.mu.Unlock()

	return r.captureError
}

func startLogCapture() string {
	var errorBuffer [512]C.char
	if C.LuaExecLogCapture_Start(&errorBuffer[0], C.int(len(errorBuffer))) == 0 {
		return C.GoString(&errorBuffer[0])
	}

	return ""
}

func (r *nativeLogRuntime) drainLoop() {
	ticker := time.NewTicker(logDrainPeriod)
	defer ticker.Stop()

	buffer := make([]byte, logDrainBytes)
	pending := make([]byte, 0, logLineBytes)
	discarding := false

	for range ticker.C {
		for {
			var length C.uint32_t
			var dropped C.uint64_t
			result := C.LuaExecLogCapture_Pop(
				(*C.char)(unsafe.Pointer(&buffer[0])),
				C.uint32_t(len(buffer)),
				&length,
				&dropped,
			)
			r.hub.addDropped(uint64(dropped))
			if result <= 0 {
				break
			}

			pending, discarding = r.consume(buffer[:int(length)], pending, discarding)
		}
	}
}

func (r *nativeLogRuntime) consume(chunk []byte, pending []byte, discarding bool) ([]byte, bool) {
	for _, value := range chunk {
		if value == '\n' {
			if discarding {
				r.hub.append(append(pending, []byte("... [truncated]")...))
			} else {
				if len(pending) > 0 && pending[len(pending)-1] == '\r' {
					pending = pending[:len(pending)-1]
				}
				r.hub.append(pending)
			}
			pending = pending[:0]
			discarding = false
			continue
		}

		if discarding {
			continue
		}
		if len(pending) == logLineBytes {
			discarding = true
			continue
		}
		pending = append(pending, value)
	}

	return pending, discarding
}

func (r *nativeLogRuntime) acceptLoop() {
	for {
		conn, err := r.listener.Accept()
		if err != nil {
			return
		}
		go r.handleConn(conn)
	}
}

func (r *nativeLogRuntime) handleConn(conn net.Conn) {
	defer conn.Close()

	request, err := logprotocol.ReadRequest(conn)
	if err != nil {
		_ = logprotocol.WriteMessage(conn, logprotocol.FrameError, []byte(err.Error()))
		return
	}
	if captureError := r.waitForCapture(); captureError != "" {
		_ = logprotocol.WriteMessage(conn, logprotocol.FrameError, []byte(captureError))
		return
	}

	entries, cursor, dropped := r.hub.snapshot(request.Lines)
	if dropped > 0 {
		if err := writeDroppedDiagnostic(conn, dropped); err != nil {
			return
		}
	}
	if err := writeLogEntries(conn, entries); err != nil || !request.Follow {
		return
	}

	clientGone := make(chan struct{})
	go func() {
		var buffer [1]byte
		_, _ = conn.Read(buffer[:])
		close(clientGone)
	}()

	for {
		entries, oldest, next, currentDropped, changed := r.hub.after(cursor)
		if cursor < oldest {
			if err := logprotocol.WriteMessage(
				conn,
				logprotocol.FrameDiagnostic,
				[]byte(fmt.Sprintf("history advanced by %d lines before this client could read it", oldest-cursor)),
			); err != nil {
				return
			}
		}
		if currentDropped > dropped {
			if err := writeDroppedDiagnostic(conn, currentDropped-dropped); err != nil {
				return
			}
			dropped = currentDropped
		}
		if len(entries) > 0 {
			if err := writeLogEntries(conn, entries); err != nil {
				return
			}
			cursor = next
			continue
		}

		select {
		case <-changed:
		case <-clientGone:
			return
		}
	}
}

func writeLogEntries(writer io.Writer, entries []logEntry) error {
	for _, entry := range entries {
		if err := logprotocol.WriteMessage(writer, logprotocol.FrameLine, entry.line); err != nil {
			return err
		}
	}

	return nil
}

func writeDroppedDiagnostic(writer io.Writer, bytes uint64) error {
	return logprotocol.WriteMessage(
		writer,
		logprotocol.FrameDiagnostic,
		[]byte(fmt.Sprintf("capture queue dropped %d bytes", bytes)),
	)
}

const runtimepipeBufferSize = 65536
