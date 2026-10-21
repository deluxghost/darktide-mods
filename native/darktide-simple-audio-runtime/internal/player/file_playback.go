package player

import (
	"errors"
	"math"
	"unsafe"

	"darktide-simple-audio-runtime/internal/ffmpeg"
	"darktide-simple-audio-runtime/internal/xaudio"
)

const (
	bufferFrames         = 4096
	initialQueuedBuffers = 1
	targetQueuedBuffers  = 3
)

type submittedBuffer struct {
	ptr unsafe.Pointer
}

type playbackDecoder interface {
	Read(output unsafe.Pointer, maxFrames int) (int, bool, error)
	SampleRate() int
	SetCancelToken(*ffmpeg.CancelToken)
	Close()
}

type filePlayback struct {
	path            string
	options         Options
	cache           *audioCache
	pcmKey          pcmCacheKey
	decoder         playbackDecoder
	voice           *xaudio.Voice
	sampleRate      int
	channels        int
	remainingFrames int
	buffers         []submittedBuffer
	eof             bool
	cacheLease      *pcmLease
	pcmCapture      *pcmCapture
	rawLease        *rawLease
	remainingPlays  int64
	fadeOut         *fadeOutState
}

func newFilePlayback(engine *xaudio.Engine, cache *audioCache, path string, options Options) (*filePlayback, error) {
	if math.IsNaN(options.Pos) || math.IsInf(options.Pos, 0) || math.IsNaN(options.Duration) || math.IsInf(options.Duration, 0) {
		return nil, errors.New("Playback range must be finite")
	}
	if options.Pos < 0 {
		options.Pos = 0
	}
	if options.Duration < 0 {
		options.Duration = -1
	}
	if options.LoopCount < 0 {
		options.LoopCount = -1
	}

	channels := xaudio.StereoChannels
	if options.Spatial {
		channels = xaudio.MonoChannels
	}
	// A filter graph may be nondeterministic even when its description is unchanged.
	cacheFinalPCM := options.Filters == ""
	cacheKey := pcmCacheKey{
		path:     path,
		channels: channels,
		pos:      options.Pos,
		duration: options.Duration,
	}
	if cacheFinalPCM {
		if lease := cache.acquireOrObserve(cacheKey); lease != nil {
			activeFile, err := newCachedFilePlayback(engine, lease, options)
			return activeFile, err
		}
	}

	var decoder playbackDecoder
	var rawLease *rawLease
	if options.Filters != "" {
		rawLease = cache.acquireRawOrObserve(path)
		if rawLease != nil {
			cachedDecoder, err := rawLease.asset.audio.OpenFilter(options.Filters, channels)
			if err != nil {
				rawLease.release()
				return nil, err
			}
			decoder = cachedDecoder
		}
	}
	if decoder == nil {
		var err error
		decoder, err = ffmpeg.Open(path, options.Filters, channels)
		if err != nil {
			return nil, err
		}
	}

	sampleRate := decoder.SampleRate()
	if sampleRate <= 0 {
		decoder.Close()
		if rawLease != nil {
			rawLease.release()
		}
		return nil, errors.New("Audio stream has no sample rate")
	}

	voice, err := engine.CreateVoice(sampleRate, channels)
	if err != nil {
		decoder.Close()
		if rawLease != nil {
			rawLease.release()
		}
		return nil, err
	}

	activeFile := &filePlayback{
		path:       path,
		options:    options,
		cache:      cache,
		pcmKey:     cacheKey,
		decoder:    decoder,
		voice:      voice,
		sampleRate: sampleRate,
		channels:   channels,
		rawLease:   rawLease,
	}

	if err := activeFile.applyOutput(); err != nil {
		activeFile.close()
		return nil, err
	}

	if options.Duration >= 0 {
		activeFile.remainingFrames = int(math.Floor(options.Duration * float64(sampleRate)))
		if activeFile.remainingFrames <= 0 {
			activeFile.close()
			return nil, errors.New("Playback range is empty")
		}
	} else {
		activeFile.remainingFrames = -1
	}

	if err := activeFile.seekStart(); err != nil {
		activeFile.close()
		return nil, err
	}
	if cacheFinalPCM {
		activeFile.pcmCapture = cache.beginPCMCapture(cacheKey, sampleRate)
	}

	if err := activeFile.fillQueue(); err != nil {
		activeFile.close()
		return nil, err
	}

	if activeFile.eof && len(activeFile.buffers) == 0 {
		activeFile.close()
		return nil, errors.New("Playback range is empty")
	}
	if cacheFinalPCM {
		if options.LoopCount != 0 {
			cache.schedulePCMBuildForLoop(cacheKey)
		} else {
			cache.schedulePCMBuild(cacheKey)
		}
	} else {
		if options.LoopCount != 0 {
			cache.scheduleRawBuildForLoop(path)
		} else {
			cache.scheduleRawBuild(path)
		}
	}

	return activeFile, nil
}

func newCachedFilePlayback(engine *xaudio.Engine, lease *pcmLease, options Options) (*filePlayback, error) {
	asset := lease.asset
	voice, err := engine.CreateVoice(asset.sampleRate, asset.channels)
	if err != nil {
		lease.release()
		return nil, err
	}

	activeFile := &filePlayback{
		options:    options,
		voice:      voice,
		sampleRate: asset.sampleRate,
		channels:   asset.channels,
		cacheLease: lease,
	}
	if err := activeFile.applyOutput(); err != nil {
		activeFile.close()
		return nil, err
	}

	if options.LoopCount < 0 {
		if err := voice.SubmitLoop(asset.ptr, asset.byteCount, -1, false); err != nil {
			activeFile.close()
			return nil, err
		}
	} else {
		activeFile.remainingPlays = int64(options.LoopCount) + 1
	}
	if err := activeFile.fillQueue(); err != nil {
		activeFile.close()
		return nil, err
	}

	return activeFile, nil
}

func (activeFile *filePlayback) seekStart() error {
	if activeFile.options.Pos <= 0 {
		return nil
	}

	framesToDiscard := int(math.Floor(activeFile.options.Pos * float64(activeFile.sampleRate)))

	for framesToDiscard > 0 {
		frames := framesToDiscard
		if frames > bufferFrames {
			frames = bufferFrames
		}

		buffer := xaudio.Alloc(activeFile.byteCount(frames))
		if buffer == nil {
			return errors.New("Failed to allocate seek buffer")
		}

		framesRead, finished, err := activeFile.decoder.Read(buffer, frames)
		xaudio.Free(buffer)

		if err != nil {
			return err
		}

		framesToDiscard -= framesRead
		if finished && framesToDiscard > 0 {
			return errors.New("Playback range is empty")
		}
	}

	return nil
}

func (activeFile *filePlayback) close() {
	if activeFile.pcmCapture != nil {
		activeFile.pcmCapture.abort(nil)
		activeFile.pcmCapture = nil
	}
	if activeFile.voice != nil {
		activeFile.voice.Destroy()
		activeFile.voice = nil
	}

	activeFile.freeSubmittedBuffers()

	if activeFile.decoder != nil {
		activeFile.decoder.Close()
		activeFile.decoder = nil
	}
	if activeFile.cacheLease != nil {
		activeFile.cacheLease.release()
		activeFile.cacheLease = nil
	}
	if activeFile.rawLease != nil {
		activeFile.rawLease.release()
		activeFile.rawLease = nil
	}
}

func (activeFile *filePlayback) freeSubmittedBuffers() {
	for i := range activeFile.buffers {
		xaudio.Free(activeFile.buffers[i].ptr)
	}

	activeFile.buffers = nil
}

func (activeFile *filePlayback) reclaimSubmittedBuffers() {
	if activeFile.cacheLease != nil {
		activeFile.eof = activeFile.voice.Queued() == 0 && activeFile.remainingPlays == 0
		return
	}
	queued := activeFile.voice.Queued()
	consumed := len(activeFile.buffers) - queued

	for i := 0; i < consumed; i++ {
		xaudio.Free(activeFile.buffers[i].ptr)
		activeFile.buffers[i].ptr = nil
	}

	if consumed > 0 {
		copy(activeFile.buffers, activeFile.buffers[consumed:])
		activeFile.buffers = activeFile.buffers[:len(activeFile.buffers)-consumed]
	}
}

func (activeFile *filePlayback) restart() error {
	if activeFile.options.LoopCount == 0 {
		return errors.New("file playback has no remaining loops")
	}

	if activeFile.options.LoopCount > 0 {
		activeFile.options.LoopCount--
	}

	if activeFile.decoder != nil {
		activeFile.decoder.Close()
		activeFile.decoder = nil
	}

	if activeFile.options.Filters == "" {
		if lease := activeFile.cache.acquirePCM(activeFile.pcmKey); lease != nil {
			activeFile.decoder = newPCMMemoryDecoder(lease)
			activeFile.eof = false
			activeFile.resetRemainingFrames()
			return nil
		}
		activeFile.cache.schedulePCMBuildForLoop(activeFile.pcmKey)
	} else {
		if activeFile.rawLease == nil {
			activeFile.rawLease = activeFile.cache.acquireRaw(activeFile.path)
		}
		if activeFile.rawLease != nil {
			decoder, err := activeFile.rawLease.asset.audio.OpenFilter(activeFile.options.Filters, activeFile.channels)
			if err != nil {
				return err
			}
			activeFile.decoder = decoder
		} else {
			activeFile.cache.scheduleRawBuildForLoop(activeFile.path)
		}
	}
	if activeFile.decoder == nil {
		decoder, err := ffmpeg.Open(activeFile.path, activeFile.options.Filters, activeFile.channels)
		if err != nil {
			return err
		}
		activeFile.decoder = decoder
	}
	activeFile.eof = false
	activeFile.resetRemainingFrames()

	return activeFile.seekStart()
}

func (activeFile *filePlayback) resetRemainingFrames() {
	if activeFile.options.Duration >= 0 {
		activeFile.remainingFrames = int(math.Floor(activeFile.options.Duration * float64(activeFile.sampleRate)))
	} else {
		activeFile.remainingFrames = -1
	}
}

func (activeFile *filePlayback) fillQueue() error {
	return activeFile.fillTo(initialQueuedBuffers)
}

func (activeFile *filePlayback) fillTo(target int) error {
	if activeFile.cacheLease != nil {
		asset := activeFile.cacheLease.asset
		for activeFile.voice.Queued() < target && activeFile.remainingPlays > 0 {
			plays := activeFile.remainingPlays
			if plays > 255 {
				plays = 255
			}
			final := activeFile.remainingPlays == plays
			if err := activeFile.voice.SubmitLoop(asset.ptr, asset.byteCount, int(plays)-1, final); err != nil {
				return err
			}
			activeFile.remainingPlays -= plays
		}
		return nil
	}
	if activeFile.pcmCapture != nil && activeFile.pcmCapture.superseded() {
		activeFile.pcmCapture = nil
	}
	for !activeFile.eof && len(activeFile.buffers) < target {
		framesToRead := bufferFrames
		if activeFile.remainingFrames >= 0 && activeFile.remainingFrames < framesToRead {
			framesToRead = activeFile.remainingFrames
		}

		if framesToRead <= 0 {
			if err := activeFile.restartOrMarkEOF(); err != nil {
				return err
			}

			continue
		}

		buffer := xaudio.Alloc(activeFile.byteCount(bufferFrames))
		if buffer == nil {
			return errors.New("Failed to allocate audio buffer")
		}

		framesRead, finished, err := activeFile.decoder.Read(buffer, framesToRead)
		if err != nil {
			xaudio.Free(buffer)
			return err
		}

		if framesRead == 0 && !finished {
			xaudio.Free(buffer)
			return errors.New("Audio decoder made no progress")
		}

		if framesRead > 0 {
			if activeFile.pcmCapture != nil {
				if captureErr := activeFile.pcmCapture.append(buffer, framesRead); captureErr != nil {
					activeFile.pcmCapture.abort(captureErr)
					activeFile.pcmCapture = nil
				}
			}
			segmentFinished := finished || (activeFile.remainingFrames >= 0 && activeFile.remainingFrames == framesRead)
			endOfStream := segmentFinished && activeFile.options.LoopCount == 0
			if err := activeFile.voice.Submit(buffer, activeFile.byteCount(framesRead), endOfStream); err != nil {
				xaudio.Free(buffer)
				return err
			}

			activeFile.buffers = append(activeFile.buffers, submittedBuffer{ptr: buffer})
		} else {
			xaudio.Free(buffer)
			if finished && activeFile.options.LoopCount == 0 && len(activeFile.buffers) > 0 {
				if err := activeFile.voice.Discontinuity(); err != nil {
					return err
				}
			}
		}

		if activeFile.remainingFrames >= 0 {
			activeFile.remainingFrames -= framesRead
		}
		if (finished || activeFile.remainingFrames == 0) && activeFile.pcmCapture != nil {
			activeFile.pcmCapture.finish()
			activeFile.pcmCapture = nil
		}
		if finished || activeFile.remainingFrames == 0 {
			if err := activeFile.restartOrMarkEOF(); err != nil {
				return err
			}
		}
	}

	return nil
}

func (activeFile *filePlayback) restartOrMarkEOF() error {
	if activeFile.options.LoopCount != 0 {
		return activeFile.restart()
	}

	activeFile.eof = true
	return nil
}

func (activeFile *filePlayback) applyOutput() error {
	volumeGain := activeFile.outputGain()

	if activeFile.options.Spatial {
		return activeFile.voice.SetSpatial(volumeGain, xaudio.SpatialSettings{
			SourcePosition:   activeFile.options.SourcePosition,
			ListenerPosition: activeFile.options.ListenerPosition,
			ListenerFront:    activeFile.options.ListenerFront,
			ListenerTop:      activeFile.options.ListenerTop,
		})
	}

	return activeFile.voice.SetVolume(volumeGain)
}

func (activeFile *filePlayback) setPosition(volumeGain float64, spatialData SpatialData) error {
	activeFile.options.VolumeGain = volumeGain
	activeFile.options.Spatial = true
	activeFile.options.SpatialData = spatialData

	return activeFile.applyOutput()
}

func (activeFile *filePlayback) byteCount(frames int) int {
	return frames * activeFile.channels * 2
}
