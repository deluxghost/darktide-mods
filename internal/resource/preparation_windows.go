package resource

import (
	"errors"
	"fmt"
	"os"
	"sync"
)

type preparationState uint8

const (
	preparationPending preparationState = iota
	preparationReady
	preparationRegistering
	preparationRegistered
	preparationFailed
)

type preparation struct {
	identity string
	prepare  func() ([]byte, error)
	register func([]byte) error
	data     []byte
	err      error
	state    preparationState
}

var preparationWorkerOnce sync.Once
var preparationMu sync.Mutex
var preparationCond = sync.NewCond(&preparationMu)
var preparations = make(map[string]*preparation)
var preparationQueue []*preparation

func Prepare(resourceType string, resourceName string, filePath string, carrierPath string) error {
	return startPreparation(
		preparationKey(resourceType, resourceName),
		filePath+"\x00"+carrierPath,
		func() ([]byte, error) {
			data, err := os.ReadFile(filePath)
			if err != nil {
				return nil, fmt.Errorf("read external %s resource: %w", resourceType, err)
			}
			if len(data) == 0 {
				return nil, errors.New("external resource file is empty")
			}

			return data, nil
		},
		func(data []byte) error {
			return registerResource(resourceType, resourceName, filePath, carrierPath, data)
		},
	)
}

func Advance(resourceType string, resourceName string) (bool, bool, error) {
	key := preparationKey(resourceType, resourceName)

	preparationMu.Lock()
	load := preparations[key]
	if load == nil {
		preparationMu.Unlock()
		return false, false, nil
	}

	switch load.state {
	case preparationPending, preparationRegistering:
		preparationMu.Unlock()
		return true, false, nil
	case preparationRegistered:
		preparationMu.Unlock()
		return true, true, nil
	case preparationFailed:
		err := load.err
		preparationMu.Unlock()
		return true, false, err
	case preparationReady:
		load.state = preparationRegistering
	}

	data := load.data
	register := load.register
	preparationMu.Unlock()

	err := register(data)

	preparationMu.Lock()
	defer preparationMu.Unlock()

	load.data = nil
	load.prepare = nil
	load.register = nil
	if err != nil {
		load.err = err
		load.state = preparationFailed
		return true, false, err
	}

	load.state = preparationRegistered
	return true, true, nil
}

func startPreparation(
	key string,
	identity string,
	prepare func() ([]byte, error),
	register func([]byte) error,
) error {
	preparationWorkerOnce.Do(func() {
		go runPreparationWorker()
	})

	preparationMu.Lock()
	defer preparationMu.Unlock()

	if existing := preparations[key]; existing != nil {
		if existing.identity != identity {
			return errors.New("resource name is already assigned to different resource data")
		}
		if existing.state == preparationFailed {
			return existing.err
		}

		return nil
	}

	load := &preparation{
		identity: identity,
		prepare:  prepare,
		register: register,
		state:    preparationPending,
	}
	preparations[key] = load
	preparationQueue = append(preparationQueue, load)
	preparationCond.Signal()

	return nil
}

func runPreparationWorker() {
	for {
		preparationMu.Lock()
		for len(preparationQueue) == 0 {
			preparationCond.Wait()
		}

		load := preparationQueue[0]
		preparationQueue[0] = nil
		preparationQueue = preparationQueue[1:]
		prepare := load.prepare
		preparationMu.Unlock()

		data, err := prepare()

		preparationMu.Lock()
		if err != nil {
			load.err = err
			load.prepare = nil
			load.register = nil
			load.state = preparationFailed
		} else {
			load.data = data
			load.state = preparationReady
		}
		preparationMu.Unlock()
	}
}

func preparationKey(resourceType string, resourceName string) string {
	return resourceType + "\x00" + resourceName
}
