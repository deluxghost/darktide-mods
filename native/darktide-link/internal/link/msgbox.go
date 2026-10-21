package link

import (
	"errors"

	"golang.org/x/sys/windows"
)

const (
	MessageBoxInfoFlags  = windows.MB_OK | windows.MB_ICONINFORMATION
	MessageBoxErrorFlags = windows.MB_OK | windows.MB_ICONERROR
)

var errorMessageKeys = map[error]string{
	ErrInvalidURL: "error.invalid_url",
}

func Message(title, message string, flags uint32) int32 {
	titleUTF16, _ := windows.UTF16PtrFromString(title)
	messageUTF16, _ := windows.UTF16PtrFromString(message)

	result, _ := windows.MessageBox(0, messageUTF16, titleUTF16, flags|windows.MB_SETFOREGROUND|windows.MB_SYSTEMMODAL)
	return result
}

func MessageTextForError(err error) string {
	for target, key := range errorMessageKeys {
		if errors.Is(err, target) {
			return T(key)
		}
	}

	return err.Error()
}
