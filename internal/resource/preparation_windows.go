package resource

import (
	"errors"
	"fmt"
	"os"
	"sync"

	"darktide-simple-assets-runtime/internal/resource/native"
)

type preparationState uint8

const (
	preparationPending preparationState = iota
	preparationReady
	preparationRegistering
	preparationRegistered
	preparationFailed
)

const preparationWorkerCount = 4

type preparation struct {
	prepare   func() (preparedRegistration, error)
	register  func() error
	resources []resourceReference
	source    string
	err       error
	state     preparationState
}

type resourceReference struct {
	typeName string
	name     string
}

type preparedRegistration struct {
	resources []resourceReference
	register  func() error
}

var preparationWorkersOnce sync.Once
var preparationMu sync.Mutex
var preparationCond = sync.NewCond(&preparationMu)
var preparations = make(map[string]*preparation)
var preparationQueue []*preparation

func Prepare(resourceType string, resourceName string, filePath string, carrierPath string) error {
	return startPreparation(
		preparationKey(resourceType, resourceName),
		filePath,
		func() (preparedRegistration, error) {
			data, err := readResourceFile(resourceType, filePath)
			if err != nil {
				return preparedRegistration{}, err
			}

			return preparedRegistration{
				resources: []resourceReference{{typeName: resourceType, name: resourceName}},
				register: func() error {
					return native.LoadResource(resourceType, resourceName, filePath, carrierPath, data)
				},
			}, nil
		},
	)
}

func readResourceFile(resourceType string, filePath string) ([]byte, error) {
	data, err := os.ReadFile(filePath)
	if err != nil {
		return nil, fmt.Errorf("read external %s resource: %w", resourceType, err)
	}
	if len(data) == 0 {
		return nil, errors.New("external resource file is empty")
	}

	return data, nil
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

	register := load.register
	preparationMu.Unlock()

	err := register()

	preparationMu.Lock()
	defer preparationMu.Unlock()

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
	source string,
	prepare func() (preparedRegistration, error),
) error {
	preparationWorkersOnce.Do(func() {
		for range preparationWorkerCount {
			go runPreparationWorker()
		}
	})

	preparationMu.Lock()
	defer preparationMu.Unlock()

	if existing := preparations[key]; existing != nil {
		if existing.source != source {
			return errors.New("resource identity is already prepared from different source data")
		}
		if existing.state == preparationFailed {
			return existing.err
		}

		return nil
	}

	load := &preparation{
		prepare: prepare,
		source:  source,
		state:   preparationPending,
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
		if len(preparationQueue) == 1 {
			preparationQueue = nil
		} else {
			preparationQueue[0] = nil
			preparationQueue = preparationQueue[1:]
		}
		prepare := load.prepare
		preparationMu.Unlock()

		prepared, err := prepare()

		preparationMu.Lock()
		if err != nil {
			load.err = err
			load.prepare = nil
			load.register = nil
			load.state = preparationFailed
		} else {
			load.resources = prepared.resources
			load.register = prepared.register
			load.state = preparationReady
		}
		preparationMu.Unlock()
	}
}

func preparationKey(resourceType string, resourceName string) string {
	return resourceType + "\x00" + resourceName
}

func preparationResources(resourceType string, resourceName string) []resourceReference {
	preparationMu.Lock()
	defer preparationMu.Unlock()

	load := preparations[preparationKey(resourceType, resourceName)]
	if load == nil || len(load.resources) == 0 {
		return nil
	}

	return append([]resourceReference(nil), load.resources...)
}
