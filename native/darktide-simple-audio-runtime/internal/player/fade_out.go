package player

import "time"

type fadeOutState struct {
	startedAt time.Time
	duration  time.Duration
	startGain float64
}

func (activeFile *filePlayback) startFadeOut(now time.Time, duration time.Duration) {
	startGain := activeFile.fadeGainAt(now)
	activeFile.fadeOut = &fadeOutState{
		startedAt: now,
		duration:  duration,
		startGain: startGain,
	}
}

func (activeFile *filePlayback) updateFadeOut(now time.Time) (bool, error) {
	if activeFile.fadeOut == nil {
		return false, nil
	}

	gain := activeFile.fadeGainAt(now)
	if err := activeFile.voice.SetVolume(activeFile.options.VolumeGain * gain); err != nil {
		return false, err
	}

	return gain == 0, nil
}

func (activeFile *filePlayback) fadeGainAt(now time.Time) float64 {
	fadeOut := activeFile.fadeOut
	if fadeOut == nil {
		return 1
	}

	elapsed := now.Sub(fadeOut.startedAt)
	if elapsed <= 0 {
		return fadeOut.startGain
	}
	if elapsed >= fadeOut.duration {
		return 0
	}

	return fadeOut.startGain * (1 - float64(elapsed)/float64(fadeOut.duration))
}

func (activeFile *filePlayback) outputGain() float64 {
	return activeFile.options.VolumeGain * activeFile.fadeGainAt(time.Now())
}

func (activeFile *filePlayback) stopping() bool {
	return activeFile.fadeOut != nil
}
