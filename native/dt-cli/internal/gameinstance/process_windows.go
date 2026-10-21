package gameinstance

import (
	"errors"
	"fmt"
	"sort"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

const (
	darktideExecutableName = "darktide.exe"
	processPathBufferSize  = 32768
	pipeProbeTimeoutMS     = 1
)

var waitNamedPipeW = windows.NewLazySystemDLL("kernel32.dll").NewProc("WaitNamedPipeW")

type Process struct {
	PID       uint32
	StartedAt time.Time
	Path      string
}

func OnlineProcesses() ([]Process, error) {
	snapshot, err := windows.CreateToolhelp32Snapshot(windows.TH32CS_SNAPPROCESS, 0)
	if err != nil {
		return nil, fmt.Errorf("enumerate Darktide processes: %w", err)
	}
	defer windows.CloseHandle(snapshot)

	var entry windows.ProcessEntry32
	entry.Size = uint32(unsafe.Sizeof(entry))

	err = windows.Process32First(snapshot, &entry)
	if errors.Is(err, windows.ERROR_NO_MORE_FILES) {
		return nil, nil
	}
	if err != nil {
		return nil, fmt.Errorf("read Darktide process list: %w", err)
	}

	var processes []Process
	for {
		if strings.EqualFold(windows.UTF16ToString(entry.ExeFile[:]), darktideExecutableName) {
			online, err := processHasPipe(entry.ProcessID)
			if err != nil {
				return nil, err
			}
			if online {
				process, ok, err := readProcess(entry.ProcessID)
				if err != nil {
					return nil, err
				}
				if ok {
					processes = append(processes, process)
				}
			}
		}

		err = windows.Process32Next(snapshot, &entry)
		if errors.Is(err, windows.ERROR_NO_MORE_FILES) {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("read Darktide process list: %w", err)
		}
	}

	sort.Slice(processes, func(i, j int) bool {
		return processes[i].PID < processes[j].PID
	})

	return processes, nil
}

func processHasPipe(pid uint32) (bool, error) {
	for _, pipeName := range []string{ExecPipeName(pid), LogsPipeName(pid)} {
		exists, err := pipeExists(pipeName)
		if err != nil {
			return false, fmt.Errorf("probe pipe %q: %w", pipeName, err)
		}
		if exists {
			return true, nil
		}
	}

	return false, nil
}

func pipeExists(pipeName string) (bool, error) {
	name, err := windows.UTF16PtrFromString(pipeName)
	if err != nil {
		return false, err
	}

	result, _, callErr := waitNamedPipeW.Call(
		uintptr(unsafe.Pointer(name)),
		uintptr(pipeProbeTimeoutMS),
	)
	if result != 0 {
		return true, nil
	}

	if errors.Is(callErr, windows.ERROR_SEM_TIMEOUT) || errors.Is(callErr, windows.ERROR_PIPE_BUSY) {
		return true, nil
	}
	if errors.Is(callErr, windows.ERROR_FILE_NOT_FOUND) || errors.Is(callErr, windows.ERROR_PATH_NOT_FOUND) {
		return false, nil
	}

	return false, callErr
}

func readProcess(pid uint32) (Process, bool, error) {
	handle, err := windows.OpenProcess(windows.PROCESS_QUERY_LIMITED_INFORMATION, false, pid)
	if errors.Is(err, windows.ERROR_INVALID_PARAMETER) {
		return Process{}, false, nil
	}
	if err != nil {
		return Process{}, false, fmt.Errorf("open Darktide process %d: %w", pid, err)
	}
	defer windows.CloseHandle(handle)

	pathBuffer := make([]uint16, processPathBufferSize)
	pathLength := uint32(len(pathBuffer))
	if err := windows.QueryFullProcessImageName(handle, 0, &pathBuffer[0], &pathLength); err != nil {
		return Process{}, false, fmt.Errorf("read executable path for Darktide process %d: %w", pid, err)
	}

	var creationTime windows.Filetime
	var exitTime windows.Filetime
	var kernelTime windows.Filetime
	var userTime windows.Filetime
	if err := windows.GetProcessTimes(handle, &creationTime, &exitTime, &kernelTime, &userTime); err != nil {
		return Process{}, false, fmt.Errorf("read start time for Darktide process %d: %w", pid, err)
	}

	return Process{
		PID:       pid,
		StartedAt: time.Unix(0, creationTime.Nanoseconds()),
		Path:      syscall.UTF16ToString(pathBuffer[:pathLength]),
	}, true, nil
}
