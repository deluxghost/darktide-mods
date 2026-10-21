package player

import (
	"errors"
	"time"

	"darktide-simple-audio-runtime/internal/xaudio"
)

var (
	errCacheBudgetUnavailable = errors.New("audio cache memory budget is unavailable")
	errCacheClosing           = errors.New("audio cache is closing")
)

func (cache *audioCache) detachOneLocked(now time.Time) cacheVictim {
	pcmKey, pcmVictim, rawKey, rawVictim := cache.findLRUCandidateLocked(now)
	if pcmVictim == nil && rawVictim == nil {
		return cacheVictim{}
	}
	if rawVictim == nil || (pcmVictim != nil && pcmVictim.lastUsed.Before(rawVictim.lastUsed)) {
		delete(cache.entries, pcmKey)
		cache.residentBytes -= pcmVictim.byteCount
		pcmVictim.cached = false
		return cacheVictim{pcm: pcmVictim}
	}

	delete(cache.rawEntries, rawKey)
	cache.residentBytes -= rawVictim.byteCount
	rawVictim.cached = false
	return cacheVictim{raw: rawVictim}
}

func (cache *audioCache) findLRUCandidateLocked(now time.Time) (pcmCacheKey, *pcmAsset, string, *rawAsset) {
	var pcmKey pcmCacheKey
	var pcmVictim *pcmAsset
	for key, candidate := range cache.entries {
		usage := cache.usage[key]
		if candidate.refs != 0 || (usage != nil && usage.plays >= 2 && now.Sub(usage.lastPlay) < cacheRetention) {
			continue
		}
		if pcmVictim == nil || candidate.lastUsed.Before(pcmVictim.lastUsed) {
			pcmKey = key
			pcmVictim = candidate
		}
	}
	var rawKey string
	var rawVictim *rawAsset
	for key, candidate := range cache.rawEntries {
		usage := cache.rawUsage[key]
		if candidate.refs != 0 || (usage != nil && usage.plays >= 2 && now.Sub(usage.lastPlay) < cacheRetention) {
			continue
		}
		if rawVictim == nil || candidate.lastUsed.Before(rawVictim.lastUsed) {
			rawKey = key
			rawVictim = candidate
		}
	}
	return pcmKey, pcmVictim, rawKey, rawVictim
}

func (lease *pcmLease) release() {
	if lease == nil || lease.cache == nil || lease.asset == nil {
		return
	}

	cache := lease.cache
	asset := lease.asset
	cache.mu.Lock()
	asset.refs--
	free := asset.refs == 0 && !asset.cached && asset.ptr != nil
	ptr := asset.ptr
	if free {
		asset.ptr = nil
	}
	cache.mu.Unlock()
	if free {
		xaudio.Free(ptr)
	}
	lease.cache = nil
	lease.asset = nil
}

func (lease *rawLease) release() {
	if lease == nil || lease.cache == nil || lease.asset == nil {
		return
	}
	cache := lease.cache
	asset := lease.asset
	cache.mu.Lock()
	asset.refs--
	free := asset.refs == 0 && !asset.cached && asset.audio != nil
	audio := asset.audio
	if free {
		asset.audio = nil
	}
	cache.mu.Unlock()
	if free {
		audio.Close()
	}
	lease.cache = nil
	lease.asset = nil
}

func (cache *audioCache) tryReserve(byteCount int) bool {
	if byteCount <= 0 {
		return true
	}
	cache.mu.Lock()
	ok := !cache.closing && cache.usedBytesLocked()+byteCount <= cache.maxBytes
	if ok {
		cache.reservedBytes += byteCount
	}
	cache.mu.Unlock()
	return ok
}

func (cache *audioCache) reserveWithEviction(byteCount int) bool {
	if byteCount <= 0 {
		return true
	}

	cache.evictionMu.Lock()
	defer cache.evictionMu.Unlock()

	for {
		cache.mu.Lock()
		if cache.closing {
			cache.mu.Unlock()
			return false
		}
		if cache.usedBytesLocked()+byteCount <= cache.maxBytes {
			cache.reservedBytes += byteCount
			cache.mu.Unlock()
			return true
		}

		victim := cache.detachOneLocked(time.Now())
		if victim.pcm == nil && victim.raw == nil {
			cache.mu.Unlock()
			return false
		}
		victimBytes := cacheVictimBytes(victim)
		cache.reclaimingBytes += victimBytes
		cache.mu.Unlock()

		freeCacheVictim(victim)

		cache.mu.Lock()
		cache.reclaimingBytes -= victimBytes
		cache.mu.Unlock()
	}
}

func (cache *audioCache) usedBytesLocked() int {
	return cache.residentBytes + cache.reservedBytes + cache.reclaimingBytes
}

func cacheVictimBytes(victim cacheVictim) int {
	if victim.pcm != nil {
		return victim.pcm.byteCount
	}
	if victim.raw != nil {
		return victim.raw.byteCount
	}
	return 0
}

func freeCacheVictim(victim cacheVictim) {
	if victim.pcm != nil && victim.pcm.ptr != nil {
		xaudio.Free(victim.pcm.ptr)
		victim.pcm.ptr = nil
	}
	if victim.raw != nil && victim.raw.audio != nil {
		victim.raw.audio.Close()
		victim.raw.audio = nil
	}
}

func freeCacheVictims(victims []cacheVictim) {
	for _, victim := range victims {
		freeCacheVictim(victim)
	}
}

func (cache *audioCache) releaseReservation(byteCount int) {
	if byteCount <= 0 {
		return
	}
	cache.mu.Lock()
	cache.reservedBytes -= byteCount
	cache.mu.Unlock()
}
