package link

import (
	"io"
	"net"
	"strings"
	"time"

	"github.com/Microsoft/go-winio"
)

const PipeName = `\\.\pipe\darktide_url_protocol_v1`

const (
	pipeDialTimeout = 3 * time.Second
)

type MessagePipe struct {
	listener net.Listener
}

func WriteMessage(message string) error {
	timeout := pipeDialTimeout
	conn, err := winio.DialPipe(PipeName, &timeout)
	if err != nil {
		return err
	}

	if _, err := io.Copy(conn, strings.NewReader(message)); err != nil {
		conn.Close()
		return err
	}

	return conn.Close()
}

func OpenMessagePipe() (*MessagePipe, error) {
	listener, err := winio.ListenPipe(PipeName, nil)
	if err != nil {
		return nil, err
	}

	return &MessagePipe{listener: listener}, nil
}

func (pipe *MessagePipe) Close() {
	pipe.listener.Close()
}

func (pipe *MessagePipe) AcceptMessage(push func(string)) error {
	conn, err := pipe.listener.Accept()
	if err != nil {
		return err
	}
	defer conn.Close()

	message, err := io.ReadAll(conn)
	if err != nil {
		return err
	}

	if len(message) > 0 {
		push(string(message))
	}

	return nil
}
