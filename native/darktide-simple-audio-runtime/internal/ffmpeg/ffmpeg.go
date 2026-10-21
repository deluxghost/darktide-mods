package ffmpeg

/*
#cgo windows CFLAGS: -DUNICODE -D_UNICODE
#include <stdlib.h>
#include "ffmpeg.h"
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

type FileInfo struct {
	SampleRate int
	Channels   int
	Duration   float64
	BitRate    int64
	Tags       map[string]string
}

type Decoder struct {
	ptr *C.SA_Decoder
}

type RawAudio struct {
	ptr *C.SA_RawAudio
}

type RawFilterDecoder struct {
	ptr *C.SA_RawFilterDecoder
}

type CancelToken struct {
	ptr *C.SA_CancelToken
}

func errorString(buffer *C.char) string {
	if buffer == nil {
		return "unknown error"
	}

	return C.GoString(buffer)
}

func Initialize() error {
	var errbuf [512]C.char

	if C.sa_ffmpeg_initialize(&errbuf[0], C.int(len(errbuf))) == 0 {
		return errors.New(errorString(&errbuf[0]))
	}

	return nil
}

func Open(path string, filters string, outputChannels int) (*Decoder, error) {
	return OpenWithCancelToken(path, filters, outputChannels, nil)
}

func OpenWithCancelToken(path string, filters string, outputChannels int, cancelToken *CancelToken) (*Decoder, error) {
	cPath := C.CString(path)
	defer C.free(unsafe.Pointer(cPath))

	var cFilters *C.char
	if filters != "" {
		cFilters = C.CString(filters)
		defer C.free(unsafe.Pointer(cFilters))
	}

	var errbuf [512]C.char
	var ptr *C.SA_Decoder
	var cCancelToken *C.SA_CancelToken
	if cancelToken != nil {
		cCancelToken = cancelToken.ptr
	}

	if C.sa_decoder_open(cPath, cFilters, C.int(outputChannels), cCancelToken, &ptr, &errbuf[0], C.int(len(errbuf))) == 0 {
		return nil, errors.New(errorString(&errbuf[0]))
	}

	return &Decoder{ptr: ptr}, nil
}

func ReadInfo(path string) (FileInfo, error) {
	decoder, err := Open(path, "", StereoChannels)
	if err != nil {
		return FileInfo{}, err
	}
	defer decoder.Close()

	return FileInfo{
		SampleRate: decoder.SampleRate(),
		Channels:   decoder.Channels(),
		Duration:   decoder.Duration(),
		BitRate:    decoder.BitRate(),
		Tags:       decoder.Tags(),
	}, nil
}

func (decoder *Decoder) Read(output unsafe.Pointer, maxFrames int) (int, bool, error) {
	if decoder == nil || decoder.ptr == nil {
		return 0, true, nil
	}

	var errbuf [512]C.char
	var framesWritten C.int
	var finished C.int

	ok := C.sa_decoder_read(
		decoder.ptr,
		(*C.int16_t)(output),
		C.int(maxFrames),
		&framesWritten,
		&finished,
		&errbuf[0],
		C.int(len(errbuf)),
	)

	if ok == 0 {
		return int(framesWritten), false, errors.New(errorString(&errbuf[0]))
	}

	return int(framesWritten), finished != 0, nil
}

func (decoder *Decoder) SampleRate() int {
	if decoder == nil || decoder.ptr == nil {
		return 0
	}

	return int(C.sa_decoder_sample_rate(decoder.ptr))
}

func (decoder *Decoder) SetCancelToken(token *CancelToken) {
	if decoder == nil || decoder.ptr == nil {
		return
	}
	var cToken *C.SA_CancelToken
	if token != nil {
		cToken = token.ptr
	}
	C.sa_decoder_set_cancel_token(decoder.ptr, cToken)
}

func (decoder *Decoder) Channels() int {
	if decoder == nil || decoder.ptr == nil {
		return 0
	}

	return int(C.sa_decoder_channels(decoder.ptr))
}

func (decoder *Decoder) BytesPerSample() int {
	if decoder == nil || decoder.ptr == nil {
		return 0
	}

	return int(C.sa_decoder_bytes_per_sample(decoder.ptr))
}

func (decoder *Decoder) BitRate() int64 {
	if decoder == nil || decoder.ptr == nil {
		return 0
	}

	return int64(C.sa_decoder_bit_rate(decoder.ptr))
}

func (decoder *Decoder) Duration() float64 {
	if decoder == nil || decoder.ptr == nil {
		return -1
	}

	return float64(C.sa_decoder_duration(decoder.ptr))
}

func (decoder *Decoder) Tags() map[string]string {
	tags := make(map[string]string)
	if decoder == nil || decoder.ptr == nil {
		return tags
	}

	for index := 0; ; index++ {
		var key *C.char
		var value *C.char

		if C.sa_decoder_tag(decoder.ptr, C.int(index), &key, &value) == 0 {
			return tags
		}

		tags[C.GoString(key)] = C.GoString(value)
	}
}

func (decoder *Decoder) Close() {
	if decoder == nil || decoder.ptr == nil {
		return
	}

	C.sa_decoder_close(decoder.ptr)
	decoder.ptr = nil
}

func NewCancelToken() (*CancelToken, error) {
	ptr := C.sa_cancel_token_create()
	if ptr == nil {
		return nil, errors.New("Failed to allocate FFmpeg cancellation token")
	}
	return &CancelToken{ptr: ptr}, nil
}

func (token *CancelToken) Cancel() {
	if token != nil && token.ptr != nil {
		C.sa_cancel_token_cancel(token.ptr)
	}
}

func (token *CancelToken) Close() {
	if token == nil || token.ptr == nil {
		return
	}
	C.sa_cancel_token_close(token.ptr)
	token.ptr = nil
}

func DecodeRaw(path string, maxBytes int, cancelToken *CancelToken) (*RawAudio, bool, error) {
	cPath := C.CString(path)
	defer C.free(unsafe.Pointer(cPath))

	var errbuf [512]C.char
	var ptr *C.SA_RawAudio
	var tooLarge C.int
	var cCancelToken *C.SA_CancelToken
	if cancelToken != nil {
		cCancelToken = cancelToken.ptr
	}
	if C.sa_raw_audio_decode(cPath, C.int(maxBytes), cCancelToken, &ptr, &tooLarge, &errbuf[0], C.int(len(errbuf))) == 0 {
		if tooLarge != 0 {
			return nil, true, nil
		}
		return nil, false, errors.New(errorString(&errbuf[0]))
	}

	return &RawAudio{ptr: ptr}, false, nil
}

func (audio *RawAudio) ByteCount() int {
	if audio == nil || audio.ptr == nil {
		return 0
	}
	return int(C.sa_raw_audio_byte_count(audio.ptr))
}

func (audio *RawAudio) OpenFilter(filters string, outputChannels int) (*RawFilterDecoder, error) {
	if audio == nil || audio.ptr == nil {
		return nil, errors.New("Raw audio cache is not initialized")
	}
	cFilters := C.CString(filters)
	defer C.free(unsafe.Pointer(cFilters))

	var errbuf [512]C.char
	var ptr *C.SA_RawFilterDecoder
	if C.sa_raw_filter_decoder_open(audio.ptr, cFilters, C.int(outputChannels), &ptr, &errbuf[0], C.int(len(errbuf))) == 0 {
		return nil, errors.New(errorString(&errbuf[0]))
	}
	return &RawFilterDecoder{ptr: ptr}, nil
}

func (audio *RawAudio) Close() {
	if audio == nil || audio.ptr == nil {
		return
	}
	C.sa_raw_audio_close(audio.ptr)
	audio.ptr = nil
}

func (decoder *RawFilterDecoder) Read(output unsafe.Pointer, maxFrames int) (int, bool, error) {
	if decoder == nil || decoder.ptr == nil {
		return 0, true, nil
	}

	var errbuf [512]C.char
	var framesWritten C.int
	var finished C.int
	ok := C.sa_raw_filter_decoder_read(
		decoder.ptr,
		(*C.int16_t)(output),
		C.int(maxFrames),
		&framesWritten,
		&finished,
		&errbuf[0],
		C.int(len(errbuf)),
	)
	if ok == 0 {
		return int(framesWritten), false, errors.New(errorString(&errbuf[0]))
	}
	return int(framesWritten), finished != 0, nil
}

func (decoder *RawFilterDecoder) SampleRate() int {
	if decoder == nil || decoder.ptr == nil {
		return 0
	}
	return int(C.sa_raw_filter_decoder_sample_rate(decoder.ptr))
}

func (decoder *RawFilterDecoder) SetCancelToken(token *CancelToken) {
	if decoder == nil || decoder.ptr == nil {
		return
	}
	var cToken *C.SA_CancelToken
	if token != nil {
		cToken = token.ptr
	}
	C.sa_raw_filter_decoder_set_cancel_token(decoder.ptr, cToken)
}

func (decoder *RawFilterDecoder) Close() {
	if decoder == nil || decoder.ptr == nil {
		return
	}
	C.sa_raw_filter_decoder_close(decoder.ptr)
	decoder.ptr = nil
}
