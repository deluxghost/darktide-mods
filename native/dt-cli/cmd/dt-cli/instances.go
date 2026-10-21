package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"text/tabwriter"
	"time"

	"dt-cli/internal/gameinstance"

	"github.com/urfave/cli/v3"
)

func newPsCommand() *cli.Command {
	return &cli.Command{
		Name:      "ps",
		Usage:     "List Darktide processes available to dt-cli.",
		UsageText: "dt-cli ps",
		Action: func(_ context.Context, command *cli.Command) error {
			if len(command.Args().Slice()) > 0 {
				return errors.New("ps does not accept arguments")
			}

			processes, err := gameinstance.OnlineProcesses()
			if err != nil {
				return err
			}

			return writeProcessTable(os.Stdout, processes)
		},
	}
}

func resolvePID(command *cli.Command) (uint32, error) {
	if command.IsSet("pid") {
		pid := command.Uint32("pid")
		if pid == 0 {
			return 0, errors.New("pid must be a positive integer")
		}

		return pid, nil
	}

	processes, err := gameinstance.OnlineProcesses()
	if err != nil {
		return 0, err
	}

	switch len(processes) {
	case 0:
		return 0, errors.New("no Darktide processes are available to dt-cli")
	case 1:
		return processes[0].PID, nil
	default:
		fmt.Fprintln(os.Stderr, "Multiple Darktide processes are available to dt-cli.")
		fmt.Fprintln(os.Stderr, "Select one with --pid <PID> or -p <PID> before the command.")
		if err := writeProcessTable(os.Stderr, processes); err != nil {
			return 0, err
		}
		return 0, silentExit(1)
	}
}

func writeProcessTable(writer io.Writer, processes []gameinstance.Process) error {
	table := tabwriter.NewWriter(writer, 0, 4, 2, ' ', 0)
	if _, err := fmt.Fprintln(table, "PID\tUPTIME\tPATH"); err != nil {
		return err
	}

	now := time.Now()
	for _, process := range processes {
		if _, err := fmt.Fprintf(
			table,
			"%d\t%s\t%s\n",
			process.PID,
			formatUptime(now.Sub(process.StartedAt)),
			process.Path,
		); err != nil {
			return err
		}
	}

	return table.Flush()
}

func formatUptime(uptime time.Duration) string {
	if uptime < 0 {
		uptime = 0
	}

	totalSeconds := int64(uptime / time.Second)
	hours := totalSeconds / 3600
	minutes := totalSeconds % 3600 / 60
	seconds := totalSeconds % 60

	return fmt.Sprintf("%02d:%02d:%02d", hours, minutes, seconds)
}
