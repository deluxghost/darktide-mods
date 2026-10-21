package player

import (
	"runtime"
	"sync"
	"time"
	"unsafe"

	"darktide-simple-audio-runtime/internal/ffmpeg"
)

const (
	cacheRetention          = 5 * time.Minute
	cacheBuildWorkerLimit   = 4
	cacheBuildQueueCapacity = 64
)

type pcmCacheKey struct {
	path     string
	channels int
	pos      float64
	duration float64
}

type cacheUsage struct {
	plays      int
	lastPlay   time.Time
	retryAfter time.Time
	tooLarge   bool
}

type pcmAsset struct {
	ptr        unsafe.Pointer
	byteCount  int
	sampleRate int
	channels   int
	lastUsed   time.Time
	refs       int
	cached     bool
}

type pcmLease struct {
	cache *audioCache
	asset *pcmAsset
}

type rawAsset struct {
	audio     *ffmpeg.RawAudio
	byteCount int
	lastUsed  time.Time
	refs      int
	cached    bool
}

type rawLease struct {
	cache *audioCache
	asset *rawAsset
}

type cacheVictim struct {
	pcm *pcmAsset
	raw *rawAsset
}

type cacheBuildKind int

const (
	cacheBuildPCM cacheBuildKind = iota + 1
	cacheBuildRaw
)

type cacheBuildJob struct {
	kind    cacheBuildKind
	pcmKey  pcmCacheKey
	rawPath string
}

type audioCache struct {
	mu              sync.Mutex
	evictionMu      sync.Mutex
	entries         map[pcmCacheKey]*pcmAsset
	usage           map[pcmCacheKey]*cacheUsage
	building        map[pcmCacheKey]struct{}
	capturing       map[pcmCacheKey]struct{}
	rawEntries      map[string]*rawAsset
	rawUsage        map[string]*cacheUsage
	rawBuilding     map[string]struct{}
	buildCancels    map[*ffmpeg.CancelToken]struct{}
	residentBytes   int
	reservedBytes   int
	reclaimingBytes int
	closing         bool
	buildJobs       chan cacheBuildJob
	buildWorkers    sync.WaitGroup
	maxBytes        int
	lastPrune       time.Time
}

func newAudioCache() *audioCache {
	workerCount := runtime.GOMAXPROCS(0) / 2
	if workerCount < 1 {
		workerCount = 1
	}
	if workerCount > cacheBuildWorkerLimit {
		workerCount = cacheBuildWorkerLimit
	}

	cache := &audioCache{
		entries:      make(map[pcmCacheKey]*pcmAsset),
		usage:        make(map[pcmCacheKey]*cacheUsage),
		building:     make(map[pcmCacheKey]struct{}),
		capturing:    make(map[pcmCacheKey]struct{}),
		rawEntries:   make(map[string]*rawAsset),
		rawUsage:     make(map[string]*cacheUsage),
		rawBuilding:  make(map[string]struct{}),
		buildCancels: make(map[*ffmpeg.CancelToken]struct{}),
		buildJobs:    make(chan cacheBuildJob, cacheBuildQueueCapacity),
		maxBytes:     audioCacheBudget(),
		lastPrune:    time.Now(),
	}
	cache.buildWorkers.Add(workerCount)
	for range workerCount {
		go cache.runBuildWorker()
	}
	return cache
}

func (cache *audioCache) runBuildWorker() {
	defer cache.buildWorkers.Done()
	for job := range cache.buildJobs {
		switch job.kind {
		case cacheBuildPCM:
			cache.buildPCM(job.pcmKey)
		case cacheBuildRaw:
			cache.buildRaw(job.rawPath)
		}
	}
}

// enqueueBuildLocked queues work without delaying playback. Callers retry on a
// later play when the bounded queue is full.
func (cache *audioCache) enqueueBuildLocked(job cacheBuildJob) bool {
	if cache.closing {
		return false
	}
	select {
	case cache.buildJobs <- job:
		return true
	default:
		return false
	}
}

func (cache *audioCache) pruneUsageLocked(now time.Time) {
	if now.Sub(cache.lastPrune) < cacheRetention {
		return
	}
	cutoff := now.Add(-cacheRetention)
	for key, usage := range cache.usage {
		_, building := cache.building[key]
		_, capturing := cache.capturing[key]
		if usage.lastPlay.Before(cutoff) && cache.entries[key] == nil && !building && !capturing {
			delete(cache.usage, key)
		}
	}
	for path, usage := range cache.rawUsage {
		_, building := cache.rawBuilding[path]
		if usage.lastPlay.Before(cutoff) && cache.rawEntries[path] == nil && !building {
			delete(cache.rawUsage, path)
		}
	}
	cache.lastPrune = now
}

func observeCacheUsage(usage *cacheUsage, now time.Time) {
	if !usage.lastPlay.IsZero() && now.Sub(usage.lastPlay) > cacheRetention {
		usage.plays = 0
	}
	usage.plays++
	usage.lastPlay = now
}

func (cache *audioCache) close() {
	cache.mu.Lock()
	cache.closing = true
	for token := range cache.buildCancels {
		token.Cancel()
	}
	close(cache.buildJobs)
	cache.mu.Unlock()
	cache.buildWorkers.Wait()

	cache.mu.Lock()
	var victims []cacheVictim
	for key, entry := range cache.entries {
		delete(cache.entries, key)
		entry.cached = false
		if entry.refs == 0 && entry.ptr != nil {
			victims = append(victims, cacheVictim{pcm: entry})
		}
	}
	for key, entry := range cache.rawEntries {
		delete(cache.rawEntries, key)
		entry.cached = false
		if entry.refs == 0 && entry.audio != nil {
			victims = append(victims, cacheVictim{raw: entry})
		}
	}
	cache.residentBytes = 0
	cache.mu.Unlock()
	freeCacheVictims(victims)
}

func (cache *audioCache) isClosing() bool {
	cache.mu.Lock()
	closing := cache.closing
	cache.mu.Unlock()
	return closing
}

func (cache *audioCache) newBuildCancelToken() (*ffmpeg.CancelToken, error) {
	token, err := ffmpeg.NewCancelToken()
	if err != nil {
		return nil, err
	}

	cache.mu.Lock()
	if cache.closing {
		cache.mu.Unlock()
		token.Close()
		return nil, errCacheClosing
	}
	cache.buildCancels[token] = struct{}{}
	cache.mu.Unlock()
	return token, nil
}

func (cache *audioCache) releaseBuildCancelToken(token *ffmpeg.CancelToken) {
	cache.mu.Lock()
	delete(cache.buildCancels, token)
	cache.mu.Unlock()
	token.Close()
}
