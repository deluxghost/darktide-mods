package clientpipe

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"time"

	"dt-cli/internal/protocol"

	"github.com/Microsoft/go-winio"
	"golang.org/x/sys/windows"
)

const (
	pipeDialRetryWindow    = 500 * time.Millisecond
	pipeWriteRetryInterval = 10 * time.Millisecond
)

var ErrPipeUnavailable = errors.New("Darktide pipe is not available. The game is not running, or LuaExec is not loaded.")

type pipeConn interface {
	io.ReadWriteCloser
	SetDeadline(time.Time) error
}

func ExchangeJSON(ctx context.Context, pipeName string, request any, response any) ([]byte, error) {
	payload, err := json.Marshal(request)
	if err != nil {
		return nil, err
	}

	responsePayload, err := exchange(ctx, pipeName, payload)
	if err != nil {
		return nil, err
	}

	if err := json.Unmarshal(responsePayload, response); err != nil {
		return nil, fmt.Errorf("invalid response JSON: %w", err)
	}

	return responsePayload, nil
}

func ValidateResponseID(got string, want string) error {
	if got != "" && got != want {
		return fmt.Errorf("response id mismatch: got %q, want %q", got, want)
	}

	return nil
}

func exchange(ctx context.Context, pipeName string, payload []byte) ([]byte, error) {
	timeout, deadline, err := pipeDeadline(ctx)
	if err != nil {
		return nil, err
	}

	conn, err := DialPipe(ctx, pipeName, timeout)
	if err != nil {
		return nil, ErrPipeUnavailable
	}
	defer conn.Close()

	if !deadline.IsZero() {
		if err := conn.SetDeadline(deadline); err != nil {
			return nil, err
		}
	}

	if err := writeFrame(ctx, conn, payload); err != nil {
		return nil, fmt.Errorf("write request frame: %w", err)
	}

	response, err := protocol.ReadFrame(conn)
	if err != nil {
		return nil, fmt.Errorf("read response frame: %w", err)
	}

	return response, nil
}

func DialPipe(ctx context.Context, pipeName string, timeout *time.Duration) (pipeConn, error) {
	retryUntil := time.Now().Add(pipeDialRetryWindow)

	for {
		conn, err := winio.DialPipe(pipeName, timeout)
		if err == nil {
			return conn, nil
		}
		if !isRetryableDialError(err) || time.Now().After(retryUntil) {
			return nil, err
		}
		if err := sleepContext(ctx, pipeWriteRetryInterval); err != nil {
			return nil, err
		}
	}
}

func isRetryableDialError(err error) bool {
	var pathErr *os.PathError
	if !errors.As(err, &pathErr) {
		return false
	}

	return errors.Is(pathErr.Err, windows.ERROR_FILE_NOT_FOUND) || errors.Is(pathErr.Err, windows.ERROR_PATH_NOT_FOUND)
}

func pipeDeadline(ctx context.Context) (*time.Duration, time.Time, error) {
	deadline, ok := ctx.Deadline()
	if !ok {
		return nil, time.Time{}, nil
	}

	timeout := time.Until(deadline)
	if timeout <= 0 {
		return nil, time.Time{}, ctx.Err()
	}

	return &timeout, deadline, nil
}

func writeFrame(ctx context.Context, writer io.Writer, payload []byte) error {
	frame, err := protocol.MakeFrame(payload)
	if err != nil {
		return err
	}

	return writeAll(ctx, writer, frame)
}

func writeAll(ctx context.Context, writer io.Writer, payload []byte) error {
	for len(payload) > 0 {
		n, err := writer.Write(payload)
		if n > 0 {
			payload = payload[n:]
		}
		if err != nil {
			if n == 0 && errors.Is(err, windows.ERROR_PIPE_NOT_CONNECTED) {
				if err := sleepContext(ctx, pipeWriteRetryInterval); err != nil {
					return err
				}
				continue
			}
			return err
		}
		if n == 0 {
			return io.ErrShortWrite
		}
	}

	return nil
}

func sleepContext(ctx context.Context, delay time.Duration) error {
	timer := time.NewTimer(delay)
	defer timer.Stop()

	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-timer.C:
		return nil
	}
}
