package main

/*
#include <stdint.h>
#include <stdlib.h>
*/
import "C"

import (
	"encoding/json"
	"errors"
	"math"
	"sync"
	"time"
	"unsafe"

	"darktide-simple-audio-runtime/internal/ffmpeg"
	"darktide-simple-audio-runtime/internal/player"
	"darktide-simple-audio-runtime/internal/xaudio"
)

var runtimePlayer = player.New()

const (
	runtimeStatusUninitialized = 0
	runtimeStatusInitializing  = 1
	runtimeStatusReady         = 2
	runtimeStatusFailed        = 3
	runtimeStatusShuttingDown  = 4
)

type runtimeInitializationState struct {
	mu     sync.Mutex
	status int
	stage  string
	err    string
}

var runtimeInitialization = runtimeInitializationState{
	status: runtimeStatusUninitialized,
	stage:  "uninitialized",
}

func main() {}

func copyMessage(buffer *C.char, bufferSize C.int, message string) C.int {
	if buffer == nil || bufferSize <= 0 {
		return -1
	}

	target := unsafe.Slice((*byte)(unsafe.Pointer(buffer)), int(bufferSize))
	if len(target) == 0 {
		return -1
	}

	maxLen := len(target) - 1
	if len(message) > maxLen {
		copy(target, message[:maxLen])
		target[maxLen] = 0
		return -2
	}

	copy(target, message)
	target[len(message)] = 0

	return 1
}

func fail(buffer *C.char, bufferSize C.int, err error) C.int {
	if err == nil {
		return 0
	}

	copyMessage(buffer, bufferSize, err.Error())
	return 0
}

func setInitializationStage(stage string) {
	runtimeInitialization.mu.Lock()
	if runtimeInitialization.status == runtimeStatusInitializing {
		runtimeInitialization.stage = stage
	}
	runtimeInitialization.mu.Unlock()
}

func failInitialization(err error) {
	runtimeInitialization.mu.Lock()
	if runtimeInitialization.status == runtimeStatusShuttingDown {
		runtimeInitialization.status = runtimeStatusUninitialized
		runtimeInitialization.stage = "uninitialized"
		runtimeInitialization.err = ""
		runtimeInitialization.mu.Unlock()
		return
	}

	runtimeInitialization.status = runtimeStatusFailed
	runtimeInitialization.stage = "failed"
	if err != nil {
		runtimeInitialization.err = err.Error()
	} else {
		runtimeInitialization.err = "unknown error"
	}
	runtimeInitialization.mu.Unlock()
}

func finishInitialization() {
	runtimeInitialization.mu.Lock()
	if runtimeInitialization.status == runtimeStatusShuttingDown {
		runtimeInitialization.mu.Unlock()
		runtimePlayer.Shutdown()

		runtimeInitialization.mu.Lock()
		runtimeInitialization.status = runtimeStatusUninitialized
		runtimeInitialization.stage = "uninitialized"
		runtimeInitialization.err = ""
		runtimeInitialization.mu.Unlock()
		return
	}

	runtimeInitialization.status = runtimeStatusReady
	runtimeInitialization.stage = "ready"
	runtimeInitialization.err = ""
	runtimeInitialization.mu.Unlock()
}

func initializeRuntime() {
	setInitializationStage("loading_ffmpeg")
	if err := ffmpeg.Initialize(); err != nil {
		failInitialization(err)
		return
	}

	setInitializationStage("creating_xaudio_engine")
	if err := runtimePlayer.Start(); err != nil {
		failInitialization(err)
		return
	}

	finishInitialization()
}

func startInitialize() bool {
	runtimeInitialization.mu.Lock()
	defer runtimeInitialization.mu.Unlock()

	switch runtimeInitialization.status {
	case runtimeStatusInitializing, runtimeStatusReady:
		return true
	case runtimeStatusShuttingDown:
		return false
	}

	runtimeInitialization.status = runtimeStatusInitializing
	runtimeInitialization.stage = "starting"
	runtimeInitialization.err = ""

	go initializeRuntime()

	return true
}

func initializationStatus() int {
	runtimeInitialization.mu.Lock()
	status := runtimeInitialization.status
	runtimeInitialization.mu.Unlock()

	return status
}

func initializationStage() string {
	runtimeInitialization.mu.Lock()
	status := runtimeInitialization.status
	stage := runtimeInitialization.stage
	runtimeInitialization.mu.Unlock()

	if status == runtimeStatusInitializing && stage == "creating_xaudio_engine" {
		xaudioStage := xaudio.CurrentStage()
		if xaudioStage != "" && xaudioStage != "idle" {
			return xaudioStage
		}
	}

	return stage
}

func initializationError() string {
	runtimeInitialization.mu.Lock()
	err := runtimeInitialization.err
	runtimeInitialization.mu.Unlock()

	return err
}

//export SimpleAudioRuntime_StartInitialize
func SimpleAudioRuntime_StartInitialize(errorBuffer *C.char, errorBufferSize C.int) C.int {
	if !startInitialize() {
		copyMessage(errorBuffer, errorBufferSize, "SimpleAudio runtime is shutting down")
		return 0
	}

	return 1
}

//export SimpleAudioRuntime_InitializationStatus
func SimpleAudioRuntime_InitializationStatus() C.int {
	return C.int(initializationStatus())
}

//export SimpleAudioRuntime_InitializationStage
func SimpleAudioRuntime_InitializationStage(buffer *C.char, bufferSize C.int) C.int {
	return copyMessage(buffer, bufferSize, initializationStage())
}

//export SimpleAudioRuntime_InitializationError
func SimpleAudioRuntime_InitializationError(buffer *C.char, bufferSize C.int) C.int {
	return copyMessage(buffer, bufferSize, initializationError())
}

//export SimpleAudioRuntime_Play
func SimpleAudioRuntime_Play(
	path *C.char,
	filters *C.char,
	volumeGain C.double,
	pos C.double,
	duration C.double,
	loopCount C.int,
	spatial C.int,
	sourceX C.double,
	sourceY C.double,
	sourceZ C.double,
	listenerX C.double,
	listenerY C.double,
	listenerZ C.double,
	listenerFrontX C.double,
	listenerFrontY C.double,
	listenerFrontZ C.double,
	listenerTopX C.double,
	listenerTopY C.double,
	listenerTopZ C.double,
	errorBuffer *C.char,
	errorBufferSize C.int,
) C.int {
	if path == nil {
		copyMessage(errorBuffer, errorBufferSize, "Audio path is null")
		return 0
	}

	filterString := ""
	if filters != nil {
		filterString = C.GoString(filters)
	}

	playID, err := runtimePlayer.Play(C.GoString(path), player.Options{
		VolumeGain: float64(volumeGain),
		Spatial:    spatial != 0,
		SpatialData: player.SpatialData{
			SourcePosition:   runtimeVector(sourceX, sourceY, sourceZ),
			ListenerPosition: runtimeVector(listenerX, listenerY, listenerZ),
			ListenerFront:    runtimeVector(listenerFrontX, listenerFrontY, listenerFrontZ),
			ListenerTop:      runtimeVector(listenerTopX, listenerTopY, listenerTopZ),
		},
		Filters:   filterString,
		Pos:       float64(pos),
		Duration:  float64(duration),
		LoopCount: int(loopCount),
	})
	if err != nil {
		return fail(errorBuffer, errorBufferSize, err)
	}

	return C.int(playID)
}

//export SimpleAudioRuntime_FileInfo
func SimpleAudioRuntime_FileInfo(
	path *C.char,
	sampleRate *C.int,
	channels *C.int,
	duration *C.double,
	bitRate *C.longlong,
	tagsJSON **C.char,
	errorBuffer *C.char,
	errorBufferSize C.int,
) C.int {
	if path == nil {
		copyMessage(errorBuffer, errorBufferSize, "Audio path is null")
		return 0
	}
	if sampleRate == nil || channels == nil || duration == nil || bitRate == nil || tagsJSON == nil {
		copyMessage(errorBuffer, errorBufferSize, "Audio info output pointer is null")
		return 0
	}
	*tagsJSON = nil

	info, err := ffmpeg.ReadInfo(C.GoString(path))
	if err != nil {
		return fail(errorBuffer, errorBufferSize, err)
	}
	tags, err := json.Marshal(info.Tags)
	if err != nil {
		return fail(errorBuffer, errorBufferSize, err)
	}

	*sampleRate = C.int(info.SampleRate)
	*channels = C.int(info.Channels)
	*duration = C.double(info.Duration)
	*bitRate = C.longlong(info.BitRate)
	*tagsJSON = C.CString(string(tags))

	return 1
}

//export SimpleAudioRuntime_FreeString
func SimpleAudioRuntime_FreeString(value *C.char) {
	if value != nil {
		C.free(unsafe.Pointer(value))
	}
}

//export SimpleAudioRuntime_SetPosition
func SimpleAudioRuntime_SetPosition(
	playID C.int,
	volumeGain C.double,
	sourceX C.double,
	sourceY C.double,
	sourceZ C.double,
	listenerX C.double,
	listenerY C.double,
	listenerZ C.double,
	listenerFrontX C.double,
	listenerFrontY C.double,
	listenerFrontZ C.double,
	listenerTopX C.double,
	listenerTopY C.double,
	listenerTopZ C.double,
	errorBuffer *C.char,
	errorBufferSize C.int,
) C.int {
	ok, err := runtimePlayer.SetPosition(int(playID), float64(volumeGain), player.SpatialData{
		SourcePosition:   runtimeVector(sourceX, sourceY, sourceZ),
		ListenerPosition: runtimeVector(listenerX, listenerY, listenerZ),
		ListenerFront:    runtimeVector(listenerFrontX, listenerFrontY, listenerFrontZ),
		ListenerTop:      runtimeVector(listenerTopX, listenerTopY, listenerTopZ),
	})
	if err != nil {
		return fail(errorBuffer, errorBufferSize, err)
	}
	if !ok {
		copyMessage(errorBuffer, errorBufferSize, "Playback is not active")
		return 0
	}

	return 1
}

func runtimeVector(x C.double, y C.double, z C.double) player.Vector {
	return player.Vector{
		X: float64(x),
		Y: float64(y),
		Z: float64(z),
	}
}

func runtimeFadeOutDuration(value C.double) (time.Duration, error) {
	seconds := float64(value)
	if math.IsNaN(seconds) || math.IsInf(seconds, 0) || seconds < 0 {
		return 0, errors.New("Fade-out duration must be finite and non-negative")
	}

	nanoseconds := seconds * float64(time.Second)
	if nanoseconds >= float64(1<<63) {
		return 0, errors.New("Fade-out duration is too large")
	}

	duration := time.Duration(nanoseconds)
	if seconds > 0 && duration == 0 {
		duration = time.Nanosecond
	}

	return duration, nil
}

//export SimpleAudioRuntime_Stop
func SimpleAudioRuntime_Stop(playID C.int, fadeOut C.double, errorBuffer *C.char, errorBufferSize C.int) C.int {
	duration, err := runtimeFadeOutDuration(fadeOut)
	if err != nil {
		return fail(errorBuffer, errorBufferSize, err)
	}

	if runtimePlayer.Stop(int(playID), duration) {
		return 1
	}

	return 0
}

//export SimpleAudioRuntime_StopAll
func SimpleAudioRuntime_StopAll(fadeOut C.double, errorBuffer *C.char, errorBufferSize C.int) C.int {
	duration, err := runtimeFadeOutDuration(fadeOut)
	if err != nil {
		return fail(errorBuffer, errorBufferSize, err)
	}

	runtimePlayer.StopAll(duration)
	return 1
}

//export SimpleAudioRuntime_IsPlaying
func SimpleAudioRuntime_IsPlaying(playID C.int) C.int {
	if runtimePlayer.IsPlaying(int(playID)) {
		return 1
	}

	return 0
}

//export SimpleAudioRuntime_PollEvent
func SimpleAudioRuntime_PollEvent(eventType *C.int, playID *C.int, messageBuffer *C.char, messageBufferSize C.int) C.int {
	if eventType == nil || playID == nil {
		return -1
	}

	event, ok := runtimePlayer.PollEvent()
	if !ok {
		return 0
	}

	*eventType = C.int(event.Type)
	*playID = C.int(event.PlayID)

	if event.Message != "" {
		return copyMessage(messageBuffer, messageBufferSize, event.Message)
	}

	if messageBuffer != nil && messageBufferSize > 0 {
		unsafe.Slice((*byte)(unsafe.Pointer(messageBuffer)), int(messageBufferSize))[0] = 0
	}

	return 1
}

//export SimpleAudioRuntime_Shutdown
func SimpleAudioRuntime_Shutdown() {
	runtimeInitialization.mu.Lock()
	status := runtimeInitialization.status
	if status == runtimeStatusInitializing {
		runtimeInitialization.status = runtimeStatusShuttingDown
		runtimeInitialization.stage = "shutting_down"
		runtimeInitialization.mu.Unlock()
		return
	}
	if status == runtimeStatusShuttingDown {
		runtimeInitialization.mu.Unlock()
		return
	}
	runtimeInitialization.status = runtimeStatusShuttingDown
	runtimeInitialization.stage = "shutting_down"
	runtimeInitialization.mu.Unlock()

	runtimePlayer.Shutdown()

	runtimeInitialization.mu.Lock()
	runtimeInitialization.status = runtimeStatusUninitialized
	runtimeInitialization.stage = "uninitialized"
	runtimeInitialization.err = ""
	runtimeInitialization.mu.Unlock()
}
