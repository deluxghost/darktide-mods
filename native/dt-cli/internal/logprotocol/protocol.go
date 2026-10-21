package logprotocol

import (
	"encoding/json"
	"fmt"
	"io"

	"dt-cli/internal/protocol"
)

const (
	FrameLine       byte = 1
	FrameDiagnostic byte = 2
	FrameError      byte = 3
)

type Request struct {
	Lines  int  `json:"lines"`
	Follow bool `json:"follow"`
}

func WriteRequest(writer io.Writer, request Request) error {
	payload, err := json.Marshal(request)
	if err != nil {
		return err
	}

	return protocol.WriteFrame(writer, payload)
}

func ReadRequest(reader io.Reader) (Request, error) {
	payload, err := protocol.ReadFrame(reader)
	if err != nil {
		return Request{}, err
	}

	var request Request
	if err := json.Unmarshal(payload, &request); err != nil {
		return Request{}, fmt.Errorf("invalid logs request: %w", err)
	}
	if request.Lines < 0 {
		return Request{}, fmt.Errorf("lines must not be negative")
	}

	return request, nil
}

func WriteMessage(writer io.Writer, kind byte, payload []byte) error {
	message := make([]byte, len(payload)+1)
	message[0] = kind
	copy(message[1:], payload)

	return protocol.WriteFrame(writer, message)
}

func ReadMessage(reader io.Reader) (byte, []byte, error) {
	message, err := protocol.ReadFrame(reader)
	if err != nil {
		return 0, nil, err
	}
	if len(message) == 0 {
		return 0, nil, fmt.Errorf("empty logs frame")
	}

	return message[0], message[1:], nil
}
