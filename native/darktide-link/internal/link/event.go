package link

import (
	"encoding/json"
	"errors"
	"net/url"
	"strings"
)

const (
	scheme          = "darktide"
	MaxPayloadBytes = 8192
)

var (
	ErrInvalidURL      = errors.New("invalid URL")
	ErrPayloadTooLarge = errors.New("URL event payload is too large")
)

type URL struct {
	RawURL    string         `json:"raw_url"`
	Namespace string         `json:"namespace"`
	Path      string         `json:"path"`
	Query     map[string]any `json:"query"`
}

func FromRawURL(rawURL string) ([]byte, error) {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return nil, ErrInvalidURL
	}

	if !strings.EqualFold(parsed.Scheme, scheme) {
		return nil, ErrInvalidURL
	}

	if parsed.Host == "" {
		return nil, ErrInvalidURL
	}

	path := parsed.Path
	if path == "" {
		path = "/"
	}

	event := URL{
		RawURL:    rawURL,
		Namespace: parsed.Host,
		Path:      path,
		Query:     normalizeQuery(parsed.Query()),
	}

	payload, err := json.Marshal(event)
	if err != nil {
		return nil, err
	}

	if len(payload) > MaxPayloadBytes {
		return nil, ErrInvalidURL
	}

	return payload, nil
}

func normalizeQuery(values url.Values) map[string]any {
	query := make(map[string]any)

	for key, value := range values {
		if len(value) == 1 {
			query[key] = value[0]
		} else {
			copied := make([]string, len(value))
			copy(copied, value)
			query[key] = copied
		}
	}

	return query
}
