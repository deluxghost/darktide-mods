local mod = get_mod("SimpleAudio")

local native_backend = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/backend/native")
local paths = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/paths")
local playback_options = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/playback/options")
local spatial = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/playback/spatial")

local playback = {}

playback.play_file = function(
	audio_path,
	playback_settings,
	unit_or_position,
	decay,
	min_distance,
	max_distance,
	override_position,
	override_rotation
)
	playback_settings = playback_settings or {}

	local volume, left_volume, right_volume = spatial.mix(
		unit_or_position,
		decay,
		min_distance,
		max_distance,
		override_position,
		override_rotation
	)
	local resolved_path = paths.resolve_audio_path(audio_path)
	local options = playback_options.create(playback_settings, volume, left_volume, right_volume)
	local play_file_id, error_message = native_backend.play(resolved_path, options)

	if not play_file_id then
		mod:error(mod:localize("play_failed", resolved_path, error_message))

		return false
	end

	return play_file_id
end

return playback
