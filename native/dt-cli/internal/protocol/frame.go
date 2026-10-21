package protocol

import (
	"encoding/binary"
	"fmt"
	"io"
)

const (
	MaxFrameBytes = 4 * 1024 * 1024
)

func MakeFrame(payload []byte) ([]byte, error) {
	if len(payload) > MaxFrameBytes {
		return nil, fmt.Errorf("payload is too large: %d bytes", len(payload))
	}

	frame := make([]byte, len(payload)+4)
	binary.LittleEndian.PutUint32(frame[:4], uint32(len(payload)))
	copy(frame[4:], payload)

	return frame, nil
}

func WriteFrame(writer io.Writer, payload []byte) error {
	frame, err := MakeFrame(payload)
	if err != nil {
		return err
	}

	for len(frame) > 0 {
		n, err := writer.Write(frame)
		if n > 0 {
			frame = frame[n:]
		}
		if err != nil {
			return err
		}
		if n == 0 {
			return io.ErrShortWrite
		}
	}

	return nil
}

func ReadFrame(reader io.Reader) ([]byte, error) {
	var header [4]byte
	if _, err := io.ReadFull(reader, header[:]); err != nil {
		return nil, err
	}

	length := binary.LittleEndian.Uint32(header[:])
	if length > MaxFrameBytes {
		return nil, fmt.Errorf("frame is too large: %d bytes", length)
	}

	payload := make([]byte, int(length))
	_, err := io.ReadFull(reader, payload)

	return payload, err
}
