package player

import (
	"unsafe"

	"darktide-simple-audio-runtime/internal/ffmpeg"
	"darktide-simple-audio-runtime/internal/xaudio"
)

type pcmMemoryDecoder struct {
	lease       *pcmLease
	offsetBytes int
	frameBytes  int
}

func newPCMMemoryDecoder(lease *pcmLease) *pcmMemoryDecoder {
	return &pcmMemoryDecoder{
		lease:      lease,
		frameBytes: lease.asset.channels * 2,
	}
}

func (decoder *pcmMemoryDecoder) Read(output unsafe.Pointer, maxFrames int) (int, bool, error) {
	if decoder == nil || decoder.lease == nil || maxFrames <= 0 {
		return 0, true, nil
	}

	asset := decoder.lease.asset
	remainingBytes := asset.byteCount - decoder.offsetBytes
	byteCount := maxFrames * decoder.frameBytes
	if byteCount > remainingBytes {
		byteCount = remainingBytes
	}
	if byteCount > 0 {
		xaudio.Copy(output, unsafe.Add(asset.ptr, decoder.offsetBytes), byteCount)
		decoder.offsetBytes += byteCount
	}
	return byteCount / decoder.frameBytes, decoder.offsetBytes == asset.byteCount, nil
}

func (decoder *pcmMemoryDecoder) SampleRate() int {
	if decoder == nil || decoder.lease == nil {
		return 0
	}
	return decoder.lease.asset.sampleRate
}

func (decoder *pcmMemoryDecoder) SetCancelToken(*ffmpeg.CancelToken) {}

func (decoder *pcmMemoryDecoder) Close() {
	if decoder == nil || decoder.lease == nil {
		return
	}
	decoder.lease.release()
	decoder.lease = nil
}
