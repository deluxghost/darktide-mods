package main

import (
	"context"
	"io"
	"os"

	"darktide-link/internal/link"

	"github.com/urfave/cli/v3"
	"golang.org/x/sys/windows"
)

const gameExecutable = "Darktide.exe"

func showInfo(text string) {
	link.Message(link.T("app.title"), text, windows.MB_OK|windows.MB_ICONINFORMATION)
}

func showError(text string) {
	link.Message(link.T("app.title"), text, windows.MB_OK|windows.MB_ICONERROR)
}

func confirmElevation(command, message string) bool {
	if link.IsElevated() {
		return true
	}

	link.Message(link.T("app.title"), message, windows.MB_OK|windows.MB_ICONWARNING)
	if err := link.RunElevated(command); err != nil {
		showError(link.T("error.request_privileges"))
		os.Exit(1)
	}

	return false
}

func runRegisterCommand() {
	needed, _ := link.RegisterNeeded()
	if !needed {
		return
	}

	if !confirmElevation("reg", link.T("registration.confirm", link.T("app.title"))) {
		return
	}

	if err := link.Register(); err != nil {
		showError(link.T("registration.failed", err.Error()))
		os.Exit(1)
	}

	showInfo(link.T("registration.success"))
}

func runUnregisterCommand() {
	needed, _ := link.UnregisterNeeded()
	if !needed {
		return
	}

	if !confirmElevation("unreg", link.T("unregistration.confirm", link.T("app.title"))) {
		return
	}

	if err := link.Unregister(); err != nil {
		showError(link.T("unregistration.failed", err.Error()))
		os.Exit(1)
	}

	showInfo(link.T("unregistration.success"))
}

func runOpenCommand(rawURL string) {
	payload, err := link.FromRawURL(rawURL)
	if err != nil {
		showError(link.MessageTextForError(err))
		os.Exit(2)
	}

	link.AllowForegroundActivation(gameExecutable)
	if err := link.WriteMessage(string(payload)); err != nil {
		showError(link.T("error.game_not_ready"))
		os.Exit(1)
	}
}

func main() {
	app := &cli.Command{
		Name:        "darktide-link-handler",
		HideHelp:    true,
		HideVersion: true,
		Writer:      io.Discard,
		ErrWriter:   io.Discard,
		Commands: []*cli.Command{
			{
				Name: "open",
				Arguments: []cli.Argument{
					&cli.StringArg{Name: "url"},
				},
				Action: func(_ context.Context, command *cli.Command) error {
					runOpenCommand(command.StringArg("url"))
					return nil
				},
			},
			{
				Name: "reg",
				Action: func(context.Context, *cli.Command) error {
					runRegisterCommand()
					return nil
				},
			},
			{
				Name: "unreg",
				Action: func(context.Context, *cli.Command) error {
					runUnregisterCommand()
					return nil
				},
			},
		},
	}

	if err := app.Run(context.Background(), os.Args); err != nil {
		showError(err.Error())
		os.Exit(2)
	}
}
