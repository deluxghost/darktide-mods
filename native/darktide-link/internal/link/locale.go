package link

import (
	"embed"
	"encoding/json"
	"fmt"
	"path"
	"strings"

	"golang.org/x/sys/windows"
)

type Locale string

const (
	defaultLocale Locale = "en"
)

//go:embed locales/*.json
var localeFiles embed.FS

var localeByWindowsTag = map[string]Locale{
	"zh-cn":   "zh-cn",
	"zh-sg":   "zh-cn",
	"zh-hans": "zh-cn",
}

var textByLocale = mustLoadAllText()

var currentLocale = detectLocale()

func mustLoadText(path string) map[string]string {
	data, err := localeFiles.ReadFile(path)
	if err != nil {
		panic(fmt.Sprintf("failed to read message file %s: %v", path, err))
	}

	var text map[string]string
	if err := json.Unmarshal(data, &text); err != nil {
		panic(fmt.Sprintf("failed to parse message file %s: %v", path, err))
	}

	return text
}

func mustLoadAllText() map[Locale]map[string]string {
	paths, err := localeFiles.ReadDir("locales")
	if err != nil {
		panic(fmt.Sprintf("failed to read message directory: %v", err))
	}

	result := make(map[Locale]map[string]string, len(paths))

	for _, entry := range paths {
		if entry.IsDir() || path.Ext(entry.Name()) != ".json" {
			continue
		}

		locale := Locale(strings.TrimSuffix(entry.Name(), ".json"))
		result[locale] = mustLoadText("locales/" + entry.Name())
	}

	if _, ok := result[defaultLocale]; !ok {
		panic(fmt.Sprintf("missing default locale %q", defaultLocale))
	}

	return result
}

func matchWindowsLocaleTag(tag string) (Locale, bool) {
	tag = strings.ToLower(tag)

	for {
		if locale, ok := localeByWindowsTag[tag]; ok {
			return locale, true
		}

		index := strings.LastIndex(tag, "-")
		if index < 0 {
			return "", false
		}

		tag = tag[:index]
	}
}

func detectLocale() Locale {
	tags, err := windows.GetUserPreferredUILanguages(windows.MUI_LANGUAGE_NAME)
	if err != nil {
		return defaultLocale
	}

	for _, tag := range tags {
		if locale, ok := matchWindowsLocaleTag(tag); ok {
			return locale
		}
	}

	return defaultLocale
}

func lookupText(key string) string {
	if text, ok := textByLocale[currentLocale]; ok {
		if value, ok := text[key]; ok {
			return value
		}
	}

	if value, ok := textByLocale[defaultLocale][key]; ok {
		return value
	}

	return key
}

func T(key string, args ...any) string {
	value := lookupText(key)

	if len(args) > 0 {
		return fmt.Sprintf(value, args...)
	}

	return value
}
