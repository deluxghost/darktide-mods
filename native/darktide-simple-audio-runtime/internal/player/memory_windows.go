package player

import (
	"fmt"
	"syscall"
	"unsafe"
)

const (
	minimumAudioCacheBytes = 128 * 1024 * 1024
	maximumAudioCacheBytes = 1024 * 1024 * 1024
)

type memoryStatusEx struct {
	length               uint32
	memoryLoad           uint32
	totalPhysical        uint64
	availablePhysical    uint64
	totalPageFile        uint64
	availablePageFile    uint64
	totalVirtual         uint64
	availableVirtual     uint64
	availableExtendedVir uint64
}

var globalMemoryStatusEx = syscall.NewLazyDLL("kernel32.dll").NewProc("GlobalMemoryStatusEx")

func audioCacheBudget() int {
	status := memoryStatusEx{length: uint32(unsafe.Sizeof(memoryStatusEx{}))}
	result, _, callErr := globalMemoryStatusEx.Call(uintptr(unsafe.Pointer(&status)))
	if result == 0 {
		fmt.Printf("SimpleAudio failed to query physical memory for cache sizing: %v\n", callErr)
		return minimumAudioCacheBytes
	}

	budget := status.totalPhysical / 64
	availableBudget := status.availablePhysical / 8
	if budget > availableBudget {
		budget = availableBudget
	}
	if budget < minimumAudioCacheBytes && availableBudget >= minimumAudioCacheBytes {
		budget = minimumAudioCacheBytes
	}
	if budget > maximumAudioCacheBytes {
		budget = maximumAudioCacheBytes
	}
	return int(budget)
}
