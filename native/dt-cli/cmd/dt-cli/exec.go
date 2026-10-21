package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"dt-cli/internal/clientpipe"
	"dt-cli/internal/gameinstance"

	"github.com/urfave/cli/v3"
)

const defaultTimeout = 5 * time.Second

type execOptions struct {
	pid      uint32
	timeout  time.Duration
	stdin    bool
	codeArgs []string
}

type execRequest struct {
	ID      string `json:"id"`
	Command string `json:"command"`
	Code    string `json:"code"`
}

type execResponse struct {
	ID     string          `json:"id"`
	OK     bool            `json:"ok"`
	Output string          `json:"output,omitempty"`
	Result json.RawMessage `json:"result,omitempty"`
	Error  string          `json:"error,omitempty"`
}

type execErrorResponse struct {
	ID    string `json:"id,omitempty"`
	OK    bool   `json:"ok"`
	Error string `json:"error"`
}

func newExecCommand() *cli.Command {
	return &cli.Command{
		Name:      "exec",
		Usage:     "Execute Lua code in a running Darktide process.",
		UsageText: "dt-cli [--pid PID] exec [options] <lua code>\n   dt-cli [--pid PID] exec --stdin [options]",
		Flags: []cli.Flag{
			&cli.DurationFlag{
				Name:  "timeout",
				Usage: "Connection/read timeout.",
				Value: defaultTimeout,
			},
			&cli.BoolFlag{
				Name:  "stdin",
				Usage: "Read Lua code from stdin.",
			},
		},
		Action: func(ctx context.Context, command *cli.Command) error {
			pid, err := resolvePID(command)
			if err != nil {
				return err
			}

			options := execOptions{
				pid:      pid,
				timeout:  command.Duration("timeout"),
				stdin:    command.Bool("stdin"),
				codeArgs: command.Args().Slice(),
			}

			return runExec(ctx, options)
		},
	}
}

func runExec(parentCtx context.Context, options execOptions) error {
	code, err := readCode(options)
	if err != nil {
		return writeExecError("", err)
	}

	request := execRequest{
		ID:      newRequestID(),
		Command: "exec",
		Code:    code,
	}

	ctx, cancel := context.WithTimeout(parentCtx, options.timeout)
	defer cancel()

	var response execResponse
	responsePayload, err := clientpipe.ExchangeJSON(ctx, gameinstance.ExecPipeName(options.pid), request, &response)
	if err != nil {
		return writeExecError(request.ID, err)
	}
	if err := clientpipe.ValidateResponseID(response.ID, request.ID); err != nil {
		return writeExecError(request.ID, err)
	}

	fmt.Println(string(responsePayload))

	if !response.OK {
		if response.Error == "" {
			response.Error = "Lua execution failed"
		}
		return silentExit(1)
	}

	return nil
}

func writeExecError(id string, err error) error {
	response := execErrorResponse{
		ID:    id,
		OK:    false,
		Error: err.Error(),
	}

	payload, marshalErr := json.Marshal(response)
	if marshalErr != nil {
		return marshalErr
	}

	fmt.Println(string(payload))

	return silentExit(1)
}

func readCode(options execOptions) (string, error) {
	if options.stdin && len(options.codeArgs) > 0 {
		return "", errors.New("cannot combine --stdin with Lua code arguments")
	}

	if options.stdin {
		data, err := io.ReadAll(os.Stdin)
		if err != nil {
			return "", err
		}
		if len(data) == 0 {
			return "", errors.New("stdin is empty")
		}
		return string(data), nil
	}

	if len(options.codeArgs) == 0 {
		return "", errors.New("missing Lua code")
	}

	return strings.Join(options.codeArgs, " "), nil
}

func newRequestID() string {
	return fmt.Sprintf("%d-%d", os.Getpid(), time.Now().UnixNano())
}
