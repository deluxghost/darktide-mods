package link

import (
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	user32                       = windows.NewLazySystemDLL("user32.dll")
	procAllowSetForegroundWindow = user32.NewProc("AllowSetForegroundWindow")
	procSetForegroundWindow      = user32.NewProc("SetForegroundWindow")
	procShowWindow               = user32.NewProc("ShowWindow")
	enumProcessWindow            = windows.NewCallback(findProcessWindow)
)

type processWindowSearch struct {
	processID uint32
	window    windows.HWND
}

func findProcessWindow(window windows.HWND, param unsafe.Pointer) uintptr {
	search := (*processWindowSearch)(param)
	var processID uint32

	windows.GetWindowThreadProcessId(window, &processID)
	if processID != search.processID || !windows.IsWindowVisible(window) {
		return 1
	}

	search.window = window

	return 0
}

func AllowForegroundActivation(executableName string) bool {
	snapshot, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return false
	}
	defer windows.CloseHandle(snapshot)

	var process windows.ProcessEntry32
	process.Size = uint32(unsafe.Sizeof(process))

	if err := windows.Process32First(snapshot, &process); err != nil {
		return false
	}

	for {
		if strings.EqualFold(windows.UTF16ToString(process.ExeFile[:]), executableName) {
			result, _, _ := procAllowSetForegroundWindow.Call(uintptr(process.ProcessID))

			return result != 0
		}

		if err := windows.Process32Next(snapshot, &process); err != nil {
			return false
		}
	}
}

func ActivateCurrentProcessWindow() bool {
	search := processWindowSearch{
		processID: windows.GetCurrentProcessId(),
	}
	windows.EnumWindows(enumProcessWindow, unsafe.Pointer(&search))

	if search.window == 0 {
		return false
	}

	procShowWindow.Call(uintptr(search.window), windows.SW_RESTORE)
	result, _, _ := procSetForegroundWindow.Call(uintptr(search.window))

	return result != 0
}
