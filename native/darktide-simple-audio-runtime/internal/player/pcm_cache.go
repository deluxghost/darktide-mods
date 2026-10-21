package player

import (
	"errors"
	"fmt"
	"math"
	"time"
	"unsafe"

	"darktide-simple-audio-runtime/internal/ffmpeg"
	"darktide-simple-audio-runtime/internal/xaudio"
)

var errPCMTooLarge = errors.New("decoded PCM exceeds the cache entry limit")

type pcmBuildBuffer struct {
	ptr              unsafe.Pointer
	capacity         int
	reservation      int
	totalBytes       int
	remainingFrames  int
	frameBytes       int
	decodeBlockBytes int
}

func (cache *audioCache) acquireOrObserve(key pcmCacheKey) *pcmLease {
	now := time.Now()

	cache.mu.Lock()
	cache.pruneUsageLocked(now)
	usage := cache.usage[key]
	if usage == nil {
		usage = &cacheUsage{}
		cache.usage[key] = usage
	}
	observeCacheUsage(usage, now)
	lease := cache.acquirePCMLocked(key, now)
	cache.mu.Unlock()
	return lease
}

func (cache *audioCache) acquirePCM(key pcmCacheKey) *pcmLease {
	now := time.Now()
	cache.mu.Lock()
	if usage := cache.usage[key]; usage != nil {
		usage.lastPlay = now
	}
	lease := cache.acquirePCMLocked(key, now)
	cache.mu.Unlock()
	return lease
}

func (cache *audioCache) acquirePCMLocked(key pcmCacheKey, now time.Time) *pcmLease {
	entry := cache.entries[key]
	if entry == nil {
		return nil
	}
	entry.refs++
	entry.lastUsed = now
	return &pcmLease{cache: cache, asset: entry}
}

func (cache *audioCache) schedulePCMBuild(key pcmCacheKey) {
	cache.schedulePCMBuildWithMinimumUsage(key, 0)
}

func (cache *audioCache) schedulePCMBuildForLoop(key pcmCacheKey) {
	cache.schedulePCMBuildWithMinimumUsage(key, 2)
}

func (cache *audioCache) schedulePCMBuildWithMinimumUsage(key pcmCacheKey, minimumPlays int) {
	now := time.Now()
	cache.mu.Lock()
	usage := cache.usage[key]
	if usage != nil && usage.plays < minimumPlays {
		usage.plays = minimumPlays
		usage.lastPlay = now
	}
	_, capturing := cache.capturing[key]
	_, building := cache.building[key]
	shouldBuild := cache.entries[key] == nil &&
		!capturing &&
		!building &&
		cache.maxBytes > 0 &&
		usage != nil &&
		usage.plays >= 2 &&
		!usage.tooLarge &&
		!now.Before(usage.retryAfter) &&
		!cache.closing
	if shouldBuild {
		cache.building[key] = struct{}{}
		if !cache.enqueueBuildLocked(cacheBuildJob{kind: cacheBuildPCM, pcmKey: key}) {
			delete(cache.building, key)
		}
	}
	cache.mu.Unlock()
}

func (cache *audioCache) buildPCM(key pcmCacheKey) {
	token, err := cache.newBuildCancelToken()
	var asset *pcmAsset
	var reservation int
	if err == nil {
		defer cache.releaseBuildCancelToken(token)
		asset, reservation, err = cache.decodePCMAsset(key, token)
	}

	cache.mu.Lock()
	delete(cache.building, key)
	usage := cache.usage[key]
	if errors.Is(err, errPCMTooLarge) {
		usage.tooLarge = true
	}
	entryExists := cache.entries[key] != nil
	admitted := err == nil && cache.commitPCMLocked(key, asset, reservation)
	if admitted {
		asset = nil
	} else if !cache.closing && !entryExists && !usage.tooLarge && !errors.Is(err, errCacheClosing) && !errors.Is(err, errCacheBudgetUnavailable) {
		usage.retryAfter = time.Now().Add(cacheRetention)
	}
	cache.mu.Unlock()

	if asset != nil {
		xaudio.Free(asset.ptr)
	}
	if err != nil && !errors.Is(err, errPCMTooLarge) && !errors.Is(err, errCacheClosing) && !errors.Is(err, errCacheBudgetUnavailable) && !cache.isClosing() {
		fmt.Printf("SimpleAudio PCM cache build failed for %s: %v\n", key.path, err)
	}
}

func (cache *audioCache) commitPCMLocked(key pcmCacheKey, asset *pcmAsset, reservation int) bool {
	cache.reservedBytes -= reservation
	if cache.closing || cache.entries[key] != nil {
		return false
	}

	now := time.Now()
	asset.cached = true
	asset.lastUsed = now
	cache.entries[key] = asset
	cache.residentBytes += asset.byteCount
	return true
}

func (cache *audioCache) decodePCMAsset(key pcmCacheKey, cancelToken *ffmpeg.CancelToken) (*pcmAsset, int, error) {
	if cache.isClosing() {
		return nil, 0, errCacheClosing
	}

	decoder, err := cache.openPCMBuildDecoder(key, cancelToken)
	if err != nil {
		return nil, 0, err
	}
	defer decoder.Close()
	decoder.SetCancelToken(cancelToken)

	sampleRate := decoder.SampleRate()
	if sampleRate <= 0 {
		return nil, 0, errors.New("Audio stream has no sample rate")
	}
	if err := cache.discardPCMFrames(decoder, key, sampleRate); err != nil {
		return nil, 0, err
	}

	remainingFrames, err := pcmRemainingFrames(key, sampleRate)
	if err != nil {
		return nil, 0, err
	}
	frameBytes := key.channels * 2
	decodeBlockBytes := bufferFrames * frameBytes
	capacity := cache.initialPCMCapacity(decoder, key, remainingFrames, sampleRate)
	if !cache.reserveWithEviction(capacity) {
		return nil, 0, errCacheBudgetUnavailable
	}

	buffer := pcmBuildBuffer{
		ptr:              xaudio.Alloc(capacity),
		capacity:         capacity,
		reservation:      capacity,
		remainingFrames:  remainingFrames,
		frameBytes:       frameBytes,
		decodeBlockBytes: decodeBlockBytes,
	}
	if buffer.ptr == nil {
		cache.releaseReservation(capacity)
		return nil, 0, errors.New("Failed to allocate PCM cache decode buffer")
	}
	keepPCM := false
	defer func() {
		if !keepPCM {
			xaudio.Free(buffer.ptr)
			cache.releaseReservation(buffer.reservation)
		}
	}()

	if err := cache.decodePCMBuffer(decoder, &buffer); err != nil {
		return nil, 0, err
	}
	keepPCM = true

	return &pcmAsset{
		ptr:        buffer.ptr,
		byteCount:  buffer.totalBytes,
		sampleRate: sampleRate,
		channels:   key.channels,
	}, buffer.reservation, nil
}

func (cache *audioCache) openPCMBuildDecoder(key pcmCacheKey, cancelToken *ffmpeg.CancelToken) (playbackDecoder, error) {
	decoder, err := ffmpeg.OpenWithCancelToken(key.path, "", key.channels, cancelToken)
	if err != nil {
		return nil, err
	}
	return decoder, nil
}

func (cache *audioCache) discardPCMFrames(decoder playbackDecoder, key pcmCacheKey, sampleRate int) error {
	framesToDiscard := int(math.Floor(key.pos * float64(sampleRate)))
	if framesToDiscard <= 0 {
		return nil
	}

	decodeBlockBytes := bufferFrames * key.channels * 2
	scratch := xaudio.Alloc(decodeBlockBytes)
	if scratch == nil {
		return errors.New("Failed to allocate PCM cache seek buffer")
	}
	defer xaudio.Free(scratch)

	for framesToDiscard > 0 {
		if cache.isClosing() {
			return errCacheClosing
		}
		framesToRead := framesToDiscard
		if framesToRead > bufferFrames {
			framesToRead = bufferFrames
		}
		frames, finished, err := decoder.Read(scratch, framesToRead)
		if err != nil {
			return err
		}
		if frames == 0 && !finished {
			return errors.New("Audio decoder made no progress")
		}
		framesToDiscard -= frames
		if finished {
			return errors.New("Playback range is empty")
		}
	}
	return nil
}

func pcmRemainingFrames(key pcmCacheKey, sampleRate int) (int, error) {
	if key.duration < 0 {
		return -1, nil
	}
	remainingFrames := int(math.Floor(key.duration * float64(sampleRate)))
	if remainingFrames <= 0 {
		return 0, errors.New("Playback range is empty")
	}
	return remainingFrames, nil
}

func (cache *audioCache) initialPCMCapacity(
	decoder playbackDecoder,
	key pcmCacheKey,
	remainingFrames int,
	sampleRate int,
) int {
	frameBytes := key.channels * 2
	decodeBlockBytes := bufferFrames * frameBytes
	estimatedBytes := int64(0)
	if remainingFrames >= 0 {
		estimatedBytes = int64(remainingFrames) * int64(frameBytes)
	} else if fileDecoder, ok := decoder.(*ffmpeg.Decoder); ok && fileDecoder.Duration() > key.pos {
		estimatedFrames := int64(math.Ceil((fileDecoder.Duration() - key.pos) * float64(sampleRate)))
		estimatedBytes = estimatedFrames * int64(frameBytes)
	}
	if estimatedBytes > int64(cache.maxBytes) {
		estimatedBytes = 0
	}

	capacity := decodeBlockBytes
	if estimatedBytes > int64(capacity) {
		capacity = int(estimatedBytes)
		if remainingFrames < 0 && capacity <= cache.maxBytes-decodeBlockBytes {
			capacity += decodeBlockBytes
		}
	}
	if capacity > cache.maxBytes {
		capacity = cache.maxBytes
	}
	return capacity
}

func (cache *audioCache) decodePCMBuffer(
	decoder playbackDecoder,
	buffer *pcmBuildBuffer,
) error {
	for {
		if cache.isClosing() {
			return errCacheClosing
		}
		if buffer.remainingFrames == 0 {
			break
		}
		if buffer.capacity == buffer.totalBytes && buffer.capacity == cache.maxBytes {
			if err := probePCMCacheLimit(decoder, buffer.decodeBlockBytes); err != nil {
				return err
			}
			break
		}

		if buffer.capacity-buffer.totalBytes < buffer.decodeBlockBytes && buffer.capacity < cache.maxBytes {
			if err := cache.growPCMBuffer(buffer); err != nil {
				return err
			}
		}

		framesToRead := (buffer.capacity - buffer.totalBytes) / buffer.frameBytes
		if framesToRead > bufferFrames {
			framesToRead = bufferFrames
		}
		if buffer.remainingFrames >= 0 && framesToRead > buffer.remainingFrames {
			framesToRead = buffer.remainingFrames
		}
		frames, done, err := decoder.Read(unsafe.Add(buffer.ptr, buffer.totalBytes), framesToRead)
		if err != nil {
			return err
		}
		if frames == 0 && !done {
			return errors.New("Audio decoder made no progress")
		}

		buffer.totalBytes += frames * buffer.frameBytes
		if buffer.remainingFrames >= 0 {
			buffer.remainingFrames -= frames
		}
		if done {
			break
		}
	}

	if buffer.totalBytes == 0 {
		return errors.New("Playback range is empty")
	}
	if buffer.totalBytes < buffer.capacity {
		resized := xaudio.Realloc(buffer.ptr, buffer.totalBytes)
		if resized == nil {
			return errors.New("Failed to finalize PCM cache buffer")
		}
		buffer.ptr = resized
	}
	return nil
}

func probePCMCacheLimit(decoder playbackDecoder, decodeBlockBytes int) error {
	scratch := xaudio.Alloc(decodeBlockBytes)
	if scratch == nil {
		return errors.New("Failed to allocate PCM cache limit probe")
	}
	frames, done, err := decoder.Read(scratch, bufferFrames)
	xaudio.Free(scratch)
	if err != nil {
		return err
	}
	if frames > 0 {
		return errPCMTooLarge
	}
	if !done {
		return errors.New("Audio decoder made no progress")
	}
	return nil
}

func (cache *audioCache) growPCMBuffer(buffer *pcmBuildBuffer) error {
	newCapacity := buffer.capacity * 2
	if newCapacity > cache.maxBytes {
		newCapacity = cache.maxBytes
	}
	additionalBytes := newCapacity - buffer.capacity
	if !cache.reserveWithEviction(additionalBytes) {
		return errCacheBudgetUnavailable
	}
	resized := xaudio.Realloc(buffer.ptr, newCapacity)
	if resized == nil {
		cache.releaseReservation(additionalBytes)
		return errors.New("Failed to grow PCM cache decode buffer")
	}
	buffer.ptr = resized
	buffer.capacity = newCapacity
	buffer.reservation += additionalBytes
	return nil
}
