package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os"

	"dt-cli/internal/clientpipe"
	"dt-cli/internal/gameinstance"
	"dt-cli/internal/logprotocol"

	"github.com/urfave/cli/v3"
)

const defaultLogLines = 10

type logsOptions struct {
	pid    uint32
	lines  int
	follow bool
}

func newLogsCommand() *cli.Command {
	return &cli.Command{
		Name:      "logs",
		Usage:     "Print logs from a running Darktide process.",
		UsageText: "dt-cli [--pid PID] logs [-n lines] [-f]",
		Flags: []cli.Flag{
			&cli.IntFlag{
				Name:    "lines",
				Aliases: []string{"n"},
				Usage:   "Number of retained log lines to print.",
				Value:   defaultLogLines,
			},
			&cli.BoolFlag{
				Name:    "follow",
				Aliases: []string{"f"},
				Usage:   "Continue printing new log lines.",
			},
		},
		Action: func(ctx context.Context, command *cli.Command) error {
			if len(command.Args().Slice()) > 0 {
				return errors.New("logs does not accept arguments")
			}

			options := logsOptions{
				lines:  command.Int("lines"),
				follow: command.Bool("follow"),
			}
			if options.lines < 0 {
				return errors.New("lines must not be negative")
			}
			pid, err := resolvePID(command)
			if err != nil {
				return err
			}
			options.pid = pid

			return runLogs(ctx, options)
		},
	}
}

func runLogs(ctx context.Context, options logsOptions) error {
	connectTimeout := defaultTimeout
	conn, err := clientpipe.DialPipe(ctx, gameinstance.LogsPipeName(options.pid), &connectTimeout)
	if err != nil {
		return errors.New("LuaExec log service is unavailable. Verify that Darktide is running and LuaExec is loaded.")
	}
	defer conn.Close()

	if err := logprotocol.WriteRequest(conn, logprotocol.Request{
		Lines:  options.lines,
		Follow: options.follow,
	}); err != nil {
		return fmt.Errorf("write logs request: %w", err)
	}

	writer := bufio.NewWriter(os.Stdout)
	defer writer.Flush()

	for {
		kind, payload, err := logprotocol.ReadMessage(conn)
		if errors.Is(err, io.EOF) {
			if options.follow {
				return errors.New("Darktide logs pipe closed while following")
			}
			return writer.Flush()
		}
		if err != nil {
			return fmt.Errorf("read logs: %w", err)
		}

		switch kind {
		case logprotocol.FrameLine:
			if _, err := writer.Write(payload); err != nil {
				return err
			}
			if err := writer.WriteByte('\n'); err != nil {
				return err
			}
			if err := writer.Flush(); err != nil {
				return err
			}
		case logprotocol.FrameDiagnostic:
			fmt.Fprintf(os.Stderr, "dt-cli logs: %s\n", payload)
		case logprotocol.FrameError:
			return errors.New(string(payload))
		default:
			return fmt.Errorf("invalid response from LuaExec log service: unsupported frame type %d", kind)
		}
	}
}
