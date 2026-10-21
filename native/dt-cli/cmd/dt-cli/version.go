package main

import (
	"context"
	"errors"
	"fmt"

	"github.com/urfave/cli/v3"
)

const commandVersion = "2.1.0"

func newVersionCommand() *cli.Command {
	return &cli.Command{
		Name:      "version",
		Usage:     "Print dt-cli version.",
		UsageText: "dt-cli version",
		Action: func(_ context.Context, command *cli.Command) error {
			if len(command.Args().Slice()) > 0 {
				return errors.New("version does not accept arguments")
			}

			fmt.Println(commandVersion)

			return nil
		},
	}
}
