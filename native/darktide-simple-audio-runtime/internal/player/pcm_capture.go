package player

import (
	"errors"
	"fmt"
	"time"
	"unsafe"

	"darktide-simple-audio-runtime/internal/xaudio"
)

type pcmCapture struct {
	cache      *audioCache
	key        pcmCacheKey
	ptr        unsafe.Pointer
	byteCount  int
	capacity   int
	sampleRate int
	channels   int
}

func (capture *pcmCapture) superseded() bool {
	if capture == nil || capture.cache == nil {
		return true
	}
	cache := capture.cache
	cache.mu.Lock()
	superseded := cache.closing || cache.entries[capture.key] != nil
	cache.mu.Unlock()
	if superseded {
		capture.abort(nil)
	}
	return superseded
}

func (cache *audioCache) beginPCMCapture(key pcmCacheKey, sampleRate int) *pcmCapture {
	now := time.Now()
	cache.mu.Lock()
	defer cache.mu.Unlock()
	usage := cache.usage[key]
	_, building := cache.building[key]
	_, capturing := cache.capturing[key]
	if cache.closing || cache.maxBytes <= 0 || usage == nil || usage.tooLarge || now.Before(usage.retryAfter) || cache.entries[key] != nil || building || capturing {
		return nil
	}
	cache.capturing[key] = struct{}{}
	return &pcmCapture{
		cache:      cache,
		key:        key,
		sampleRate: sampleRate,
		channels:   key.channels,
	}
}

func (capture *pcmCapture) append(source unsafe.Pointer, frames int) error {
	if capture == nil || capture.cache == nil || frames <= 0 {
		return nil
	}
	byteCount := frames * capture.channels * 2
	required := capture.byteCount + byteCount
	if required > capture.cache.maxBytes {
		return errPCMTooLarge
	}
	if required > capture.capacity {
		capacity := bufferFrames * capture.channels * 2
		if capture.capacity > 0 {
			capacity = capture.capacity
		}
		for capacity < required {
			capacity *= 2
			if capacity > capture.cache.maxBytes {
				capacity = capture.cache.maxBytes
			}
		}
		reservation := capacity - capture.capacity
		if !capture.cache.tryReserve(reservation) {
			return errCacheBudgetUnavailable
		}
		resized := xaudio.Realloc(capture.ptr, capacity)
		if resized == nil {
			capture.cache.releaseReservation(reservation)
			return errors.New("Failed to grow first-play PCM capture")
		}
		capture.ptr = resized
		capture.capacity = capacity
	}

	xaudio.Copy(unsafe.Add(capture.ptr, capture.byteCount), source, byteCount)
	capture.byteCount = required
	return nil
}

func (capture *pcmCapture) finish() {
	if capture == nil || capture.cache == nil {
		return
	}
	if capture.byteCount == 0 {
		capture.abort(errors.New("First-play PCM capture is empty"))
		return
	}
	if capture.byteCount < capture.capacity {
		resized := xaudio.Realloc(capture.ptr, capture.byteCount)
		if resized == nil {
			capture.abort(errors.New("Failed to finalize first-play PCM capture"))
			return
		}
		capture.ptr = resized
	}

	asset := &pcmAsset{
		ptr:        capture.ptr,
		byteCount:  capture.byteCount,
		sampleRate: capture.sampleRate,
		channels:   capture.channels,
	}
	cache := capture.cache
	cache.mu.Lock()
	delete(cache.capturing, capture.key)
	usage := cache.usage[capture.key]
	entryExists := cache.entries[capture.key] != nil
	admitted := cache.commitPCMLocked(capture.key, asset, capture.capacity)
	if !admitted && !cache.closing && !entryExists && usage != nil {
		usage.retryAfter = time.Now().Add(cacheRetention)
	}
	cache.mu.Unlock()

	if admitted {
		capture.ptr = nil
	} else {
		xaudio.Free(asset.ptr)
	}
	capture.cache = nil
}

func (capture *pcmCapture) abort(err error) {
	if capture == nil || capture.cache == nil {
		return
	}
	cache := capture.cache
	cache.mu.Lock()
	delete(cache.capturing, capture.key)
	_, building := cache.building[capture.key]
	cache.reservedBytes -= capture.capacity
	if usage := cache.usage[capture.key]; err != nil && usage != nil && cache.entries[capture.key] == nil {
		if errors.Is(err, errPCMTooLarge) {
			usage.tooLarge = true
		} else if !building && !errors.Is(err, errCacheBudgetUnavailable) {
			usage.retryAfter = time.Now().Add(cacheRetention)
		}
	}
	cache.mu.Unlock()
	if capture.ptr != nil {
		xaudio.Free(capture.ptr)
		capture.ptr = nil
	}
	if err != nil && !errors.Is(err, errPCMTooLarge) && !errors.Is(err, errCacheBudgetUnavailable) {
		fmt.Printf("SimpleAudio opportunistic PCM capture failed for %s: %v\n", capture.key.path, err)
	}
	capture.cache = nil
}
