# SimpleAudio

`SimpleAudio` is a local audio playback library for other Darktide mods. The current public API covers local audio file playback, game Wwise event playback, dialogue playback, one-time spatial volume and stereo pan calculation, random file selection, playback stopping, active playback checks, Wwise event hooks, dialogue hooks, and sound silencing.

Its API is similar to Audio Plugin, but not identical.

## Quick Start

The examples below place audio files in the calling mod's `audio` directory:

```text
mods/MySoundMod/audio/shot_01.mp3
mods/MySoundMod/audio/shot_02.mp3
```

In the calling mod, wait until all mods are loaded before getting `SimpleAudio`:

```lua
local SimpleAudio

mod.on_all_mods_loaded = function()
	SimpleAudio = get_mod("SimpleAudio")

	if not SimpleAudio then
		mod:error("SimpleAudio is required.")
		return
	end

	SimpleAudio.play_file("shot_01.mp3", {
		audio_type = "sfx",
	})
end
```

## Path Rules

Forward slashes and backslashes are accepted. Paths are normalized to forward slashes internally, and the examples below use forward slashes.

`SimpleAudio.play_file("file.mp3")` reads from the calling mod's `audio` directory by default:

```lua
SimpleAudio.play_file("shot.mp3")
-- mods/MySoundMod/audio/shot.mp3

SimpleAudio.play_file("weapons/shot.mp3")
-- mods/MySoundMod/audio/weapons/shot.mp3
```

If the path starts with the calling mod name, it is resolved from that mod's root directory:

```lua
SimpleAudio.play_file("MySoundMod/sounds/shot.mp3")
-- mods/MySoundMod/sounds/shot.mp3
```

If the path starts with `mods/`, it is resolved from Darktide's `mods` directory. This can be used to read files from another mod:

```lua
SimpleAudio.play_file("mods/OtherSoundPack/audio/shot.mp3")
-- mods/OtherSoundPack/audio/shot.mp3
```

Windows absolute paths are used as-is:

```lua
SimpleAudio.play_file("D:/Audio/shot.mp3")
```

## Playing Game Wwise Sounds

`play` triggers game Wwise resources directly. It does not play local audio files.

```lua
local source_id = SimpleAudio.play(sound_name, unit_or_position_or_id, node_or_rotation_or_boolean)
```

Supported `sound_name` values:

- `wwise/events/...`: Triggers the matching game Wwise event.
- `loc_...`: Triggers the matching external dialogue line.
- `wwise/externals/loc_...`: Triggers the matching external dialogue line.

`unit_or_position_or_id` is optional:

- `Unit`: Creates an auto source attached to the unit.
- `Vector3`: Creates a manual source at the position.
- `number`: Uses the number as an existing Wwise source id for dialogue playback.
- `nil`: Uses the local player unit for dialogue playback.

Examples:

```lua
SimpleAudio.play("wwise/events/ui/play_ui_eor_character_lvl_up")
SimpleAudio.play("loc_ogryn_a__combat_pause_one_liner_07")
SimpleAudio.play("wwise/events/cinematics/play_fatshark_splash", Vector3(10, 20, 30))
```

## Playing Files

```lua
local play_id = SimpleAudio.play_file(
	audio_path,
	playback_settings,
	unit_or_position,
	decay,
	min_distance,
	max_distance,
	override_position,
	override_rotation
)
```

Return value:

- Returns `play_id` on success.
- Returns `false` on failure and logs the error through `SimpleAudio`.

`playback_settings` is optional. Supported fields:

- `audio_type`: Supported values are `sfx`, `music`, and `dialogue`. This connects playback volume to the matching in-game audio setting. If omitted, only master volume is applied.
- `volume`: Percentage multiplier. `100` means original volume, and `200` means double volume.
- `pos`: Start position in seconds.
- `duration`: Playback duration in seconds.
- `loop`: `true` loops forever, a number sets the number of extra repeats, and `nil` or `false` disables looping.
- `on_finished`: `function()` callback called with no arguments when playback ends naturally. It is not called when playback is stopped with `stop_file`.

`SimpleAudio` reads playback options from the `playback_settings` table passed to the current call.

Position arguments:

- `unit_or_position` can be a `Unit` or `Vector3`. If omitted, the sound is played as 2D audio.
- `decay` controls distance falloff strength. The default is `0.01`.
- `min_distance` keeps full volume within this distance. The default is `0`.
- `max_distance` mutes the sound beyond this distance. The default is `100`.
- `override_position` and `override_rotation` override the listener position and rotation.

Example:

```lua
SimpleAudio.play_file("reload.mp3", {
	audio_type = "sfx",
	volume = 80,
})
```

Play once from a unit's current position:

```lua
SimpleAudio.play_file("shot.mp3", {
	audio_type = "sfx",
	volume = 100,
}, unit)
```

Loop a file and keep the `play_id`:

```lua
local loop_id = SimpleAudio.play_file("engine_loop.ogg", {
	audio_type = "sfx",
	loop = true,
}, unit)
```

## Stopping And Status

Stop a specific playback instance:

```lua
local stopped = SimpleAudio.stop_file(play_id)
```

Omitting `play_id` stops all currently playing files:

```lua
local stopped = SimpleAudio.stop_file()
```

Return value:

- Returns `true` when called without `play_id`.
- Returns `true` when `play_id` is active.
- Returns `false` when `play_id` is not active.

Check playback status:

```lua
local playing = SimpleAudio.is_file_playing(play_id)
```

Return value:

- Returns `true` while `play_id` is still tracked as active playback.
- Returns `false` otherwise.

## Random Files

`glob` finds a group of files and can play a random match. Matches are preloaded when the glob is created.

```lua
local shots = SimpleAudio.glob("shot_*.mp3")
```

The same path rules as `play_file` apply. `*` and `?` can be used in any path segment:

```lua
local shots = SimpleAudio.glob("weapons/shot_*.mp3")
local shots_by_pack = SimpleAudio.glob("mods/MySoundPack/variant*/shot_*.mp3")
```

Wildcards match within one path segment.

The object returned by `glob` supports:

- `result:count()`: Returns the number of matched files.
- `result:list()`: Returns a copied list of matched paths. The returned paths can be passed directly to `play_file`.
- `result:random()`: Returns one random matched path.
- `result:play(playback_settings, unit_or_position, decay, min_distance, max_distance, override_position, override_rotation)`: Plays one random matched file and returns the `play_file` return value.

`glob` errors if `pattern` is not a string or no files match.

Example:

```lua
local shots

mod.on_all_mods_loaded = function()
	SimpleAudio = get_mod("SimpleAudio")
	shots = SimpleAudio.glob("shot_*.mp3")
end

local function play_random_shot(unit)
	return shots:play({
		audio_type = "sfx",
		volume = 100,
	}, unit)
end
```

Use `list` to inspect the matched paths:

```lua
for _, file in ipairs(shots:list()) do
	mod:echo(file)
end
```

The object returned by `glob` stores the matched file list. Reusing the same object avoids repeated file scans and preload calls.

## Hooking Wwise And Dialogue Events

`hook_sound` listens for final Wwise event names and external dialogue names triggered by the game. The first argument is a Lua pattern, not a plain string match.

```lua
SimpleAudio.hook_sound(pattern, callback)
```

Callback signature:

```lua
function(sound_type, event_name, delta, position_or_unit_or_id, optional_a, optional_b)
end
```

Arguments:

- `sound_type`: Type inferred from `position_or_unit_or_id` for Wwise resource events: `nil` -> `2d_sound`, `boolean` -> `start_stop_event`, `number` -> `source_sound`, `Vector3` -> `3d_sound`, and `Unit` -> `unit_sound`. External dialogue events use `external_sound`.
- `event_name`: The actual `wwise/events/...` name for Wwise resource events. For external dialogue events, this is the `loc_...` name without the `wwise/externals/` prefix.
- `delta`: Seconds since the same pattern last matched. The first match is `nil`.
- `position_or_unit_or_id`, `optional_a`, `optional_b`: The original extra arguments passed to `WwiseWorld.trigger_resource_event`. For external dialogue events, these are `wwise_source_id`, `sound_event`, and `sound_source`.

Note: if `position_or_unit_or_id` is a Wwise source id instead of a `Unit` or `Vector3`, `SimpleAudio` cannot resolve a world position from it. Passing that value to `play_file` results in 2D playback. Positional playback requires the caller to pass a `Unit` or `Vector3`.

Return value:

- Return `false` to stop the original Wwise event from playing.
- Return `nil` or any other value to let the original Wwise event continue.

Example: replace one weapon firing event and suppress the original event:

```lua
local shots

mod.on_all_mods_loaded = function()
	SimpleAudio = get_mod("SimpleAudio")
	shots = SimpleAudio.glob("shot_*.mp3")

	SimpleAudio.hook_sound("^wwise/events/weapon/play_weapon_galvanic_rifle$", function(sound_type, event_name, delta, position_or_unit_or_id)
		local playback_target

		if sound_type == "3d_sound" or sound_type == "unit_sound" then
			playback_target = position_or_unit_or_id
		end

		shots:play({
			audio_type = "sfx",
			volume = 100,
		}, playback_target)

		return false
	end)
end
```

Example: listen for an event while keeping the original sound:

```lua
SimpleAudio.hook_sound("play_grenade_surface_impact", function(sound_type, event_name, delta, unit_or_position)
	if delta == nil or delta > 0.1 then
		SimpleAudio.play_file("impact.mp3", {
			audio_type = "sfx",
		}, unit_or_position)
	end
end)
```

Example: replace one dialogue line with another game dialogue line:

```lua
SimpleAudio.hook_sound("com_wheel_vo_need_health", function(sound_type, event_name, delta, wwise_source_id)
	SimpleAudio.play("loc_zealot_female_c__com_wheel_vo_thank_you_01", wwise_source_id)

	return false
end)
```

## Silencing Game Sounds

`silence_sounds` prevents matched game Wwise resource events or external dialogue events from playing. It accepts a Lua pattern string or a list of Lua pattern strings.

```lua
SimpleAudio.silence_sounds("wwise/events/ui/play")
SimpleAudio.silence_sounds({
	"play_weapon_lasgun",
	"loc_tech_priest_a",
})
```

Reverse silencing with the same pattern or list:

```lua
SimpleAudio.unsilence_sounds("wwise/events/ui/play")
```

Check whether a name is currently silenced:

```lua
local silenced = SimpleAudio.is_sound_silenced("wwise/events/ui/play_ui_eor_character_lvl_up")
```

For external dialogue, silencing checks both the stripped `loc_...` name and the full `wwise/externals/loc_...` path.

## Limitations

- Audio is decoded to a 48 kHz, stereo, 16-bit PCM temporary cache and cleaned up when `SimpleAudio` unloads.
- Supported input formats depend on the bundled FFmpeg DLLs.
- Spatial audio is calculated once when playback starts. It does not keep tracking moving targets during playback.
- `glob` preloads all matched files. Matching many long files can increase load time and temporary cache usage.
- `hook_sound` calls only one callback for the first matching pattern. If multiple patterns or multiple mods match the same event, the selected callback is not guaranteed.
