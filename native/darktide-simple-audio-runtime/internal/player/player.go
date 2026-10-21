package player

import (
	"errors"
	"sync"
	"time"

	"darktide-simple-audio-runtime/internal/xaudio"
)

const (
	EventFinished = 1
	EventError    = 2
	EventStopped  = 3
)

type Vector = xaudio.Vector

type Options struct {
	VolumeGain float64
	Spatial    bool
	SpatialData
	Filters   string
	Pos       float64
	Duration  float64
	LoopCount int
}

type SpatialData struct {
	SourcePosition   xaudio.Vector
	ListenerPosition xaudio.Vector
	ListenerFront    xaudio.Vector
	ListenerTop      xaudio.Vector
}

type Event struct {
	Type    int
	PlayID  int
	Message string
}

type Player struct {
	mu       sync.Mutex
	nextID   int
	running  bool
	active   map[int]struct{}
	commands chan command
	events   chan Event
	done     chan struct{}
}

func New() *Player {
	return &Player{
		nextID: 1,
	}
}

func (player *Player) Start() error {
	player.mu.Lock()
	defer player.mu.Unlock()

	if player.running {
		return nil
	}

	commands := make(chan command, 64)
	events := make(chan Event, 1024)
	done := make(chan struct{})
	started := make(chan error, 1)

	go player.loop(commands, events, done, started)

	if err := <-started; err != nil {
		<-done
		return err
	}

	player.commands = commands
	player.events = events
	player.done = done
	player.active = map[int]struct{}{}
	player.running = true

	return nil
}

func (player *Player) Play(path string, options Options) (int, error) {
	playID, commands, err := player.reservePlayID()
	if err != nil {
		return 0, err
	}

	result := make(chan commandResult, 1)
	commands <- command{
		kind:    commandPlay,
		playID:  playID,
		path:    path,
		options: options,
		result:  result,
	}

	response := <-result
	if response.error != nil || !response.ok {
		player.unmarkActive(playID)
		return 0, response.error
	}

	return playID, nil
}

func (player *Player) Stop(playID int, fadeOut time.Duration) bool {
	if playID <= 0 {
		return false
	}

	commands, ok := player.commandChannelIfActive(playID)
	if !ok {
		return false
	}

	result := make(chan commandResult, 1)
	commands <- command{
		kind:    commandStop,
		playID:  playID,
		fadeOut: fadeOut,
		result:  result,
	}

	response := <-result
	return response.ok
}

func (player *Player) SetPosition(playID int, volumeGain float64, spatialData SpatialData) (bool, error) {
	if playID <= 0 {
		return false, nil
	}

	commands, ok := player.commandChannelIfActive(playID)
	if !ok {
		return false, nil
	}

	result := make(chan commandResult, 1)
	commands <- command{
		kind:        commandSetPosition,
		playID:      playID,
		volumeGain:  volumeGain,
		spatialData: spatialData,
		result:      result,
	}

	response := <-result
	return response.ok, response.error
}

func (player *Player) StopAll(fadeOut time.Duration) {
	commands, ok := player.commandChannel()
	if !ok {
		return
	}

	result := make(chan commandResult, 1)
	commands <- command{
		kind:    commandStopAll,
		fadeOut: fadeOut,
		result:  result,
	}
	<-result
}

func (player *Player) IsPlaying(playID int) bool {
	player.mu.Lock()
	defer player.mu.Unlock()

	if !player.running || playID <= 0 {
		return false
	}

	_, ok := player.active[playID]
	return ok
}

func (player *Player) PollEvent() (Event, bool) {
	player.mu.Lock()
	events := player.events
	player.mu.Unlock()

	if events == nil {
		return Event{}, false
	}

	select {
	case event := <-events:
		return event, true
	default:
		return Event{}, false
	}
}

func (player *Player) Shutdown() {
	player.mu.Lock()
	if !player.running {
		player.events = nil
		player.mu.Unlock()
		return
	}

	commands := player.commands
	done := player.done
	player.mu.Unlock()

	result := make(chan commandResult, 1)
	commands <- command{
		kind:   commandShutdown,
		result: result,
	}
	<-result
	<-done

	player.mu.Lock()
	player.running = false
	player.commands = nil
	player.events = nil
	player.done = nil
	player.active = nil
	player.mu.Unlock()
}

func (player *Player) reservePlayID() (int, chan command, error) {
	player.mu.Lock()
	defer player.mu.Unlock()

	if !player.running || player.commands == nil {
		return 0, nil, errors.New("SimpleAudio runtime is not running")
	}

	playID := player.nextID
	player.nextID++
	player.active[playID] = struct{}{}

	return playID, player.commands, nil
}

func (player *Player) commandChannel() (chan command, bool) {
	player.mu.Lock()
	defer player.mu.Unlock()

	if !player.running || player.commands == nil {
		return nil, false
	}

	return player.commands, true
}

func (player *Player) commandChannelIfActive(playID int) (chan command, bool) {
	player.mu.Lock()
	defer player.mu.Unlock()

	if !player.running || player.commands == nil {
		return nil, false
	}

	if _, ok := player.active[playID]; !ok {
		return nil, false
	}

	return player.commands, true
}

func (player *Player) unmarkActive(playID int) {
	player.mu.Lock()
	defer player.mu.Unlock()

	if player.active != nil {
		delete(player.active, playID)
	}
}

func (player *Player) clearActive() {
	player.mu.Lock()
	defer player.mu.Unlock()

	for playID := range player.active {
		delete(player.active, playID)
	}
}
