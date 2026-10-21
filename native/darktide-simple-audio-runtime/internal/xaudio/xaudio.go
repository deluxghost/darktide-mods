package xaudio

/*
#cgo windows LDFLAGS: -lxaudio2_9 -lx3daudio -lole32

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct SA_XAudioEngine SA_XAudioEngine;
typedef struct SA_XAudioVoice SA_XAudioVoice;
typedef struct {
	float x;
	float y;
	float z;
} SA_XAudioVector;

int sa_xaudio_engine_create(SA_XAudioEngine** out, char* error, int error_size);
void sa_xaudio_engine_destroy(SA_XAudioEngine* engine);
int sa_xaudio_thread_initialize(char* error, int error_size);
void sa_xaudio_thread_uninitialize(void);
int sa_xaudio_engine_critical_error(SA_XAudioEngine* engine, char* error, int error_size);
const char* sa_xaudio_current_stage(void);
int sa_xaudio_voice_create(SA_XAudioEngine* engine, int sample_rate, int channels, SA_XAudioVoice** out, char* error, int error_size);
int sa_xaudio_voice_submit_loop(SA_XAudioVoice* voice, void* data, int byte_count, int loop_count, int end_of_stream, char* error, int error_size);
int sa_xaudio_voice_discontinuity(SA_XAudioVoice* voice, char* error, int error_size);
int sa_xaudio_voice_set_volume(SA_XAudioVoice* voice, float volume, char* error, int error_size);
int sa_xaudio_voice_set_spatial(SA_XAudioVoice* voice, float volume, SA_XAudioVector source_position, SA_XAudioVector listener_position, SA_XAudioVector listener_front, SA_XAudioVector listener_top, char* error, int error_size);
int sa_xaudio_voice_queued(SA_XAudioVoice* voice);
void sa_xaudio_voice_destroy(SA_XAudioVoice* voice);
*/
import "C"

import (
	"errors"
	"unsafe"
)

const (
	MonoChannels   = 1
	StereoChannels = 2
)

type Vector struct {
	X float64
	Y float64
	Z float64
}

type SpatialSettings struct {
	SourcePosition   Vector
	ListenerPosition Vector
	ListenerFront    Vector
	ListenerTop      Vector
}

type Engine struct {
	ptr *C.SA_XAudioEngine
}

type Voice struct {
	ptr *C.SA_XAudioVoice
}

func errorString(buffer *C.char) string {
	if buffer == nil {
		return "unknown error"
	}

	return C.GoString(buffer)
}

func CreateEngine() (*Engine, error) {
	var errbuf [512]C.char
	var ptr *C.SA_XAudioEngine

	if C.sa_xaudio_engine_create(&ptr, &errbuf[0], C.int(len(errbuf))) == 0 {
		return nil, errors.New(errorString(&errbuf[0]))
	}

	return &Engine{ptr: ptr}, nil
}

func InitializeThread() error {
	var errbuf [512]C.char

	if C.sa_xaudio_thread_initialize(&errbuf[0], C.int(len(errbuf))) == 0 {
		return errors.New(errorString(&errbuf[0]))
	}

	return nil
}

func UninitializeThread() {
	C.sa_xaudio_thread_uninitialize()
}

func CurrentStage() string {
	stage := C.sa_xaudio_current_stage()
	if stage == nil {
		return ""
	}

	return C.GoString(stage)
}

func (engine *Engine) Destroy() {
	if engine == nil || engine.ptr == nil {
		return
	}

	C.sa_xaudio_engine_destroy(engine.ptr)
	engine.ptr = nil
}

func (engine *Engine) CreateVoice(sampleRate int, channels int) (*Voice, error) {
	if engine == nil || engine.ptr == nil {
		return nil, errors.New("XAudio2 engine is not initialized")
	}
	if channels != MonoChannels && channels != StereoChannels {
		return nil, errors.New("XAudio2 source channel count must be 1 or 2")
	}

	var errbuf [512]C.char
	var ptr *C.SA_XAudioVoice

	if C.sa_xaudio_voice_create(engine.ptr, C.int(sampleRate), C.int(channels), &ptr, &errbuf[0], C.int(len(errbuf))) == 0 {
		return nil, errors.New(errorString(&errbuf[0]))
	}

	return &Voice{ptr: ptr}, nil
}

func (engine *Engine) CriticalError() error {
	if engine == nil || engine.ptr == nil {
		return nil
	}

	var errbuf [512]C.char

	if C.sa_xaudio_engine_critical_error(engine.ptr, &errbuf[0], C.int(len(errbuf))) == 0 {
		return nil
	}

	return errors.New(errorString(&errbuf[0]))
}

func (voice *Voice) Submit(buffer unsafe.Pointer, byteCount int, endOfStream bool) error {
	return voice.SubmitLoop(buffer, byteCount, 0, endOfStream)
}

func (voice *Voice) SubmitLoop(buffer unsafe.Pointer, byteCount int, loopCount int, endOfStream bool) error {
	if voice == nil || voice.ptr == nil {
		return errors.New("XAudio2 voice is not initialized")
	}

	var errbuf [512]C.char
	cEndOfStream := C.int(0)
	if endOfStream {
		cEndOfStream = 1
	}
	if C.sa_xaudio_voice_submit_loop(voice.ptr, buffer, C.int(byteCount), C.int(loopCount), cEndOfStream, &errbuf[0], C.int(len(errbuf))) == 0 {
		return errors.New(errorString(&errbuf[0]))
	}

	return nil
}

func (voice *Voice) Discontinuity() error {
	if voice == nil || voice.ptr == nil {
		return errors.New("XAudio2 voice is not initialized")
	}

	var errbuf [512]C.char
	if C.sa_xaudio_voice_discontinuity(voice.ptr, &errbuf[0], C.int(len(errbuf))) == 0 {
		return errors.New(errorString(&errbuf[0]))
	}

	return nil
}

func (voice *Voice) SetVolume(volume float64) error {
	if voice == nil || voice.ptr == nil {
		return errors.New("XAudio2 voice is not initialized")
	}

	var errbuf [512]C.char

	if C.sa_xaudio_voice_set_volume(voice.ptr, C.float(volume), &errbuf[0], C.int(len(errbuf))) == 0 {
		return errors.New(errorString(&errbuf[0]))
	}

	return nil
}

func (voice *Voice) SetSpatial(volume float64, spatial SpatialSettings) error {
	if voice == nil || voice.ptr == nil {
		return errors.New("XAudio2 voice is not initialized")
	}

	var errbuf [512]C.char

	if C.sa_xaudio_voice_set_spatial(
		voice.ptr,
		C.float(volume),
		cVector(spatial.SourcePosition),
		cVector(spatial.ListenerPosition),
		cVector(spatial.ListenerFront),
		cVector(spatial.ListenerTop),
		&errbuf[0],
		C.int(len(errbuf)),
	) == 0 {
		return errors.New(errorString(&errbuf[0]))
	}

	return nil
}

func cVector(value Vector) C.SA_XAudioVector {
	return C.SA_XAudioVector{
		x: C.float(value.X),
		y: C.float(value.Y),
		z: C.float(value.Z),
	}
}

func (voice *Voice) Queued() int {
	if voice == nil || voice.ptr == nil {
		return 0
	}

	return int(C.sa_xaudio_voice_queued(voice.ptr))
}

func (voice *Voice) Destroy() {
	if voice == nil || voice.ptr == nil {
		return
	}

	C.sa_xaudio_voice_destroy(voice.ptr)
	voice.ptr = nil
}

func Alloc(byteCount int) unsafe.Pointer {
	return C.malloc(C.size_t(byteCount))
}

func Realloc(buffer unsafe.Pointer, byteCount int) unsafe.Pointer {
	return C.realloc(buffer, C.size_t(byteCount))
}

func Copy(destination unsafe.Pointer, source unsafe.Pointer, byteCount int) {
	C.memcpy(destination, source, C.size_t(byteCount))
}

func Free(buffer unsafe.Pointer) {
	C.free(buffer)
}
