package player

import (
	"fmt"
	goruntime "runtime"
	"time"

	"darktide-simple-audio-runtime/internal/xaudio"
)

const updateInterval = 5 * time.Millisecond

type commandKind int

const (
	commandPlay commandKind = iota + 1
	commandSetPosition
	commandStop
	commandStopAll
	commandShutdown
)

type command struct {
	kind        commandKind
	playID      int
	path        string
	options     Options
	volumeGain  float64
	spatialData SpatialData
	fadeOut     time.Duration
	result      chan commandResult
}

type commandResult struct {
	ok    bool
	error error
}

func (player *Player) loop(commands <-chan command, events chan Event, done chan<- struct{}, started chan<- error) {
	defer close(done)

	goruntime.LockOSThread()
	defer goruntime.UnlockOSThread()

	if err := xaudio.InitializeThread(); err != nil {
		started <- err
		return
	}
	defer xaudio.UninitializeThread()

	engine, err := xaudio.CreateEngine()
	if err != nil {
		started <- err
		return
	}
	started <- nil

	defer func() {
		if engine != nil {
			engine.Destroy()
		}
	}()

	cache := newAudioCache()
	defer cache.close()

	activeFiles := map[int]*filePlayback{}
	ticker := time.NewTicker(updateInterval)
	defer ticker.Stop()

	for {
		if len(activeFiles) == 0 {
			cmd := <-commands
			var shutdown bool
			engine, shutdown = player.processCommand(cmd, activeFiles, engine, cache, events)
			if shutdown {
				return
			}
			continue
		}

		maintenanceDue := false
		select {
		case <-ticker.C:
			maintenanceDue = true
		default:
		}
		if !maintenanceDue {
			select {
			case cmd := <-commands:
				var shutdown bool
				engine, shutdown = player.processCommand(cmd, activeFiles, engine, cache, events)
				if shutdown {
					return
				}
				continue
			case <-ticker.C:
			}
		}

		engine, err = player.recoverCriticalError(engine, activeFiles, events)
		if err != nil || len(activeFiles) == 0 {
			continue
		}

		player.updateFadeOuts(activeFiles, events, time.Now())
		if len(activeFiles) == 0 {
			continue
		}

		player.reclaimFilePlaybacks(activeFiles, events)
		if len(activeFiles) == 0 {
			continue
		}

		for target := 1; target <= targetQueuedBuffers; target++ {
			var shutdown bool
			engine, shutdown = player.refillFilePlaybacks(commands, activeFiles, target, engine, cache, events)
			if shutdown {
				return
			}
			if len(activeFiles) == 0 {
				break
			}
		}
	}
}

func (player *Player) processCommand(cmd command, activeFiles map[int]*filePlayback, engine *xaudio.Engine, cache *audioCache, events chan Event) (*xaudio.Engine, bool) {
	if cmd.kind != commandShutdown && (cmd.kind == commandPlay || len(activeFiles) > 0) {
		var err error
		engine, err = player.recoverCriticalError(engine, activeFiles, events)
		if err != nil {
			if cmd.result != nil {
				cmd.result <- commandResult{error: err}
			}
			return engine, false
		}
	}

	return engine, player.handleCommand(cmd, activeFiles, engine, cache)
}

func (player *Player) handleCommand(cmd command, activeFiles map[int]*filePlayback, engine *xaudio.Engine, cache *audioCache) bool {
	switch cmd.kind {
	case commandPlay:
		activeFile, err := newFilePlayback(engine, cache, cmd.path, cmd.options)
		if err != nil {
			cmd.result <- commandResult{error: err}
			return false
		}

		activeFiles[cmd.playID] = activeFile
		cmd.result <- commandResult{ok: true}

	case commandSetPosition:
		activeFile := activeFiles[cmd.playID]
		if activeFile == nil {
			cmd.result <- commandResult{}
			return false
		}

		if err := activeFile.setPosition(cmd.volumeGain, cmd.spatialData); err != nil {
			cmd.result <- commandResult{error: err}
			return false
		}

		cmd.result <- commandResult{ok: true}

	case commandStop:
		activeFile := activeFiles[cmd.playID]
		if activeFile == nil {
			cmd.result <- commandResult{}
			return false
		}

		if cmd.fadeOut > 0 {
			activeFile.startFadeOut(time.Now(), cmd.fadeOut)
			cmd.result <- commandResult{ok: true}
			return false
		}

		activeFile.close()
		delete(activeFiles, cmd.playID)
		player.unmarkActive(cmd.playID)
		cmd.result <- commandResult{ok: true}

	case commandStopAll:
		if cmd.fadeOut > 0 {
			now := time.Now()
			for _, activeFile := range activeFiles {
				activeFile.startFadeOut(now, cmd.fadeOut)
			}
			cmd.result <- commandResult{ok: true}
			return false
		}

		player.closeFilePlaybacks(activeFiles)
		player.clearActive()
		cmd.result <- commandResult{ok: true}

	case commandShutdown:
		player.closeFilePlaybacks(activeFiles)
		player.clearActive()
		cmd.result <- commandResult{ok: true}
		return true
	}

	return false
}

func (player *Player) updateFadeOuts(activeFiles map[int]*filePlayback, events chan Event, now time.Time) {
	for playID, activeFile := range activeFiles {
		finished, err := activeFile.updateFadeOut(now)
		if err != nil {
			activeFile.close()
			delete(activeFiles, playID)
			player.unmarkActive(playID)
			player.pushEvent(events, Event{Type: EventError, PlayID: playID, Message: err.Error()})
			continue
		}
		if finished {
			activeFile.close()
			delete(activeFiles, playID)
			player.unmarkActive(playID)
			player.pushEvent(events, Event{Type: EventStopped, PlayID: playID})
		}
	}
}

func (player *Player) reclaimFilePlaybacks(activeFiles map[int]*filePlayback, events chan Event) {
	for playID, activeFile := range activeFiles {
		activeFile.reclaimSubmittedBuffers()
		if activeFile.eof && len(activeFile.buffers) == 0 {
			eventType := EventFinished
			if activeFile.stopping() {
				eventType = EventStopped
			}
			activeFile.close()
			delete(activeFiles, playID)
			player.unmarkActive(playID)
			player.pushEvent(events, Event{Type: eventType, PlayID: playID})
		}
	}
}

func (player *Player) refillFilePlaybacks(commands <-chan command, activeFiles map[int]*filePlayback, target int, engine *xaudio.Engine, cache *audioCache, events chan Event) (*xaudio.Engine, bool) {
	for playID, activeFile := range activeFiles {
		if err := activeFile.fillTo(target); err != nil {
			player.pushEvent(events, Event{Type: EventError, PlayID: playID, Message: err.Error()})
			activeFile.close()
			delete(activeFiles, playID)
			player.unmarkActive(playID)
		}

		select {
		case cmd := <-commands:
			var shutdown bool
			engine, shutdown = player.processCommand(cmd, activeFiles, engine, cache, events)
			if shutdown {
				return engine, true
			}
		default:
		}
	}
	return engine, false
}

func (player *Player) recoverCriticalError(engine *xaudio.Engine, activeFiles map[int]*filePlayback, events chan Event) (*xaudio.Engine, error) {
	if engine == nil {
		newEngine, err := xaudio.CreateEngine()
		if err != nil {
			return nil, fmt.Errorf("failed to recreate XAudio2 engine: %w", err)
		}

		return newEngine, nil
	}

	criticalError := engine.CriticalError()
	if criticalError == nil {
		return engine, nil
	}

	for playID, activeFile := range activeFiles {
		activeFile.close()
		delete(activeFiles, playID)
		player.unmarkActive(playID)
		player.pushEvent(events, Event{Type: EventError, PlayID: playID, Message: criticalError.Error()})
	}

	engine.Destroy()

	newEngine, err := xaudio.CreateEngine()
	if err != nil {
		recoveryError := fmt.Errorf("%s; failed to recreate XAudio2 engine: %w", criticalError.Error(), err)
		return nil, recoveryError
	}

	return newEngine, nil
}

func (player *Player) closeFilePlaybacks(activeFiles map[int]*filePlayback) {
	for playID, activeFile := range activeFiles {
		activeFile.close()
		delete(activeFiles, playID)
	}
}

func (player *Player) pushEvent(events chan Event, event Event) {
	select {
	case events <- event:
	default:
		select {
		case <-events:
		default:
		}

		select {
		case events <- event:
		default:
			fmt.Println("SimpleAudio runtime event queue is full")
		}
	}
}
