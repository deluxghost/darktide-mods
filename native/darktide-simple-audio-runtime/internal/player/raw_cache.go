package player

import (
	"errors"
	"fmt"
	"math"
	"time"

	"darktide-simple-audio-runtime/internal/ffmpeg"
)

const rawCacheBytesPerSampleMax = 8

func (cache *audioCache) acquireRawOrObserve(path string) *rawLease {
	now := time.Now()
	cache.mu.Lock()
	cache.pruneUsageLocked(now)
	usage := cache.rawUsage[path]
	if usage == nil {
		usage = &cacheUsage{}
		cache.rawUsage[path] = usage
	}
	observeCacheUsage(usage, now)
	lease := cache.acquireRawLocked(path, now)
	cache.mu.Unlock()
	return lease
}

func (cache *audioCache) acquireRaw(path string) *rawLease {
	now := time.Now()
	cache.mu.Lock()
	if usage := cache.rawUsage[path]; usage != nil {
		usage.lastPlay = now
	}
	lease := cache.acquireRawLocked(path, now)
	cache.mu.Unlock()
	return lease
}

func (cache *audioCache) acquireRawLocked(path string, now time.Time) *rawLease {
	entry := cache.rawEntries[path]
	if entry == nil {
		return nil
	}
	entry.refs++
	entry.lastUsed = now
	return &rawLease{cache: cache, asset: entry}
}

func (cache *audioCache) scheduleRawBuild(path string) {
	cache.scheduleRawBuildWithMinimumUsage(path, 0)
}

func (cache *audioCache) scheduleRawBuildForLoop(path string) {
	cache.scheduleRawBuildWithMinimumUsage(path, 2)
}

func (cache *audioCache) scheduleRawBuildWithMinimumUsage(path string, minimumPlays int) {
	now := time.Now()
	cache.mu.Lock()
	usage := cache.rawUsage[path]
	if usage != nil && usage.plays < minimumPlays {
		usage.plays = minimumPlays
		usage.lastPlay = now
	}
	_, building := cache.rawBuilding[path]
	shouldBuild := usage != nil &&
		usage.plays >= 2 &&
		cache.maxBytes > 0 &&
		cache.rawEntries[path] == nil &&
		!building &&
		!usage.tooLarge &&
		!now.Before(usage.retryAfter) &&
		!cache.closing
	if shouldBuild {
		cache.rawBuilding[path] = struct{}{}
		if !cache.enqueueBuildLocked(cacheBuildJob{kind: cacheBuildRaw, rawPath: path}) {
			delete(cache.rawBuilding, path)
		}
	}
	cache.mu.Unlock()
}

func (cache *audioCache) buildRaw(path string) {
	token, err := cache.newBuildCancelToken()
	if err != nil {
		cache.finishRawBuild(path, nil, 0, false, err)
		return
	}
	defer cache.releaseBuildCancelToken(token)

	reservationTarget, err := cache.estimateRawReservation(path, token)
	if err != nil {
		cache.finishRawBuild(path, nil, 0, false, err)
		return
	}

	for {
		if !cache.reserveWithEviction(reservationTarget) {
			cache.finishRawBuild(path, nil, 0, false, errCacheBudgetUnavailable)
			return
		}

		audio, tooLarge, decodeErr := ffmpeg.DecodeRaw(path, reservationTarget, token)
		if decodeErr != nil || !tooLarge {
			var asset *rawAsset
			if decodeErr == nil {
				asset = &rawAsset{audio: audio, byteCount: audio.ByteCount()}
			}
			cache.finishRawBuild(path, asset, reservationTarget, tooLarge, decodeErr)
			return
		}
		if reservationTarget == cache.maxBytes {
			cache.finishRawBuild(path, nil, reservationTarget, true, nil)
			return
		}

		cache.releaseReservation(reservationTarget)
		if reservationTarget > cache.maxBytes/2 {
			reservationTarget = cache.maxBytes
		} else {
			reservationTarget *= 2
		}
	}
}

func (cache *audioCache) estimateRawReservation(path string, cancelToken *ffmpeg.CancelToken) (int, error) {
	decoder, err := ffmpeg.OpenWithCancelToken(path, "", ffmpeg.StereoChannels, cancelToken)
	if err != nil {
		return 0, err
	}
	defer decoder.Close()

	frames := float64(decoder.SampleRate())
	if duration := decoder.Duration(); duration > 0 {
		frames = math.Ceil(duration * frames)
	}
	bytesPerSample := decoder.BytesPerSample()
	if bytesPerSample <= 0 {
		bytesPerSample = rawCacheBytesPerSampleMax
	}
	estimate := frames * float64(decoder.Channels()*bytesPerSample)
	estimate += estimate / 8
	if estimate >= float64(cache.maxBytes) {
		return cache.maxBytes, nil
	}
	if estimate < 1 {
		return 1, nil
	}
	return int(math.Ceil(estimate)), nil
}

func (cache *audioCache) finishRawBuild(path string, asset *rawAsset, reservation int, tooLarge bool, err error) {
	cache.mu.Lock()
	delete(cache.rawBuilding, path)
	usage := cache.rawUsage[path]
	if tooLarge && reservation == cache.maxBytes {
		usage.tooLarge = true
	}
	entryExists := cache.rawEntries[path] != nil
	admitted := asset != nil && cache.commitRawLocked(path, asset, reservation)
	if asset == nil {
		cache.reservedBytes -= reservation
	}
	if admitted {
		asset = nil
	} else if !cache.closing && !entryExists && !usage.tooLarge && !errors.Is(err, errCacheClosing) && !errors.Is(err, errCacheBudgetUnavailable) {
		usage.retryAfter = time.Now().Add(cacheRetention)
	}
	cache.mu.Unlock()

	if asset != nil {
		asset.audio.Close()
	}
	if err != nil && !errors.Is(err, errCacheBudgetUnavailable) && !cache.isClosing() {
		fmt.Printf("SimpleAudio raw frame cache build failed for %s: %v\n", path, err)
	}
}

func (cache *audioCache) commitRawLocked(path string, asset *rawAsset, reservation int) bool {
	cache.reservedBytes -= reservation
	if cache.closing || cache.rawEntries[path] != nil {
		return false
	}
	now := time.Now()
	asset.cached = true
	asset.lastUsed = now
	cache.rawEntries[path] = asset
	cache.residentBytes += asset.byteCount
	return true
}
