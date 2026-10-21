package main

/*
#include <stdint.h>
*/
import "C"

import (
	"os/exec"
	"sync"
	"sync/atomic"
	"unsafe"

	"darktide-link/internal/link"
)

const (
	maxQueueSize = 64
)

var (
	queueMu sync.Mutex
	queue   []string
	running atomic.Bool

	serverMu   sync.Mutex
	serverPipe *link.MessagePipe
)

func main() {}

func serve(pipe *link.MessagePipe) {
	defer func() {
		pipe.Close()

		serverMu.Lock()
		if serverPipe == pipe {
			serverPipe = nil
		}
		serverMu.Unlock()
	}()

	for running.Load() {
		if err := pipe.AcceptMessage(pushMessage); err != nil {
			if !running.Load() {
				return
			}

			running.Store(false)
			return
		}
	}
}

func pushMessage(message string) {
	queueMu.Lock()
	defer queueMu.Unlock()

	if len(queue) >= maxQueueSize {
		copy(queue, queue[1:])
		queue[len(queue)-1] = message
		return
	}

	queue = append(queue, message)
}

//export DarktideLink_StartServer
func DarktideLink_StartServer() C.int {
	if running.Load() {
		return 1
	}

	pipe, err := link.OpenMessagePipe()
	if err != nil {
		return 0
	}

	serverMu.Lock()
	serverPipe = pipe
	serverMu.Unlock()

	running.Store(true)
	go serve(pipe)

	return 1
}

//export DarktideLink_StopServer
func DarktideLink_StopServer() C.int {
	if !running.Swap(false) {
		return 0
	}

	serverMu.Lock()
	pipe := serverPipe
	serverMu.Unlock()

	if pipe != nil {
		pipe.Close()
	}

	return 1
}

//export DarktideLink_PollEvent
func DarktideLink_PollEvent(buffer *C.char, bufferSize C.int) C.int {
	if buffer == nil || bufferSize <= 0 {
		return -1
	}

	queueMu.Lock()
	if len(queue) == 0 {
		queueMu.Unlock()
		return 0
	}

	message := queue[0]
	copy(queue, queue[1:])
	queue[len(queue)-1] = ""
	queue = queue[:len(queue)-1]
	queueMu.Unlock()

	maxLen := int(bufferSize) - 1
	if len(message) > maxLen {
		queueMu.Lock()
		queue = append([]string{message}, queue...)
		queueMu.Unlock()

		return -2
	}

	target := unsafe.Slice((*byte)(unsafe.Pointer(buffer)), int(bufferSize))
	copy(target, message)
	target[len(message)] = 0

	return 1
}

//export DarktideLink_ActivateWindow
func DarktideLink_ActivateWindow() C.int {
	if link.ActivateCurrentProcessWindow() {
		return 1
	}
	return 0
}

//export DarktideLink_ShowMessage
func DarktideLink_ShowMessage(title *C.char, message *C.char, flags C.uint) {
	if message == nil {
		return
	}

	titleText := link.T("app.title")
	if title != nil {
		titleText = C.GoString(title)
	}
	messageText := C.GoString(message)
	messageFlags := uint32(flags)

	go link.Message(titleText, messageText, messageFlags)
}

//export DarktideLink_RegisterAsync
func DarktideLink_RegisterAsync(handlerPath *C.char) C.int {
	if handlerPath == nil {
		return 0
	}

	command := exec.Command(C.GoString(handlerPath), "reg")
	if err := command.Start(); err != nil {
		return 0
	}
	go command.Wait()

	return 1
}
