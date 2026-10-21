package main

import (
	"context"
	"errors"
	"fmt"
	"os"

	"github.com/urfave/cli/v3"
)

const commandName = "dt-cli"

func main() {
	app := &cli.Command{
		Name:        commandName,
		Usage:       "Command-line interface for Darktide.",
		HideVersion: true,
		Flags: []cli.Flag{
			&cli.Uint32Flag{
				Name:    "pid",
				Aliases: []string{"p"},
				Usage:   "Target Darktide process ID.",
			},
		},
		Commands: []*cli.Command{
			newPsCommand(),
			newExecCommand(),
			newLogsCommand(),
			newVersionCommand(),
		},
	}

	if err := app.Run(context.Background(), os.Args); err != nil {
		var exitErr *commandExitError
		if errors.As(err, &exitErr) {
			if !exitErr.silent && exitErr.err != nil {
				fmt.Fprintln(os.Stderr, exitErr.err)
			}
			os.Exit(exitErr.code)
		}

		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

type commandExitError struct {
	code   int
	err    error
	silent bool
}

func (err *commandExitError) Error() string {
	if err.err != nil {
		return err.err.Error()
	}

	return fmt.Sprintf("exit status %d", err.code)
}

func silentExit(code int) error {
	return &commandExitError{
		code:   code,
		silent: true,
	}
}
