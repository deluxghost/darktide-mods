local mod = get_mod("SimpleAudio")

local native_runtime = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/runtime/native")
local paths = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/paths")
local playback_options = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/playback/options")
local spatial = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/playback/spatial")

local file_playback = {}

file_playback.play_file = function(
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

	local volume, spatial_data = spatial.mix(
		unit_or_position,
		decay,
		min_distance,
		max_distance,
		override_position,
		override_rotation
	)
	local resolved_path = paths.resolve_audio_path(audio_path)
	local options = playback_options.create(playback_settings, volume, spatial_data)
	local play_file_id, error_message = native_runtime.play(resolved_path, options)

	if not play_file_id then
		mod:error(mod:localize("play_failed", resolved_path, error_message))

		return false
	end

	return play_file_id
end

file_playback.set_position = function(
	play_id,
	unit_or_position,
	decay,
	min_distance,
	max_distance,
	override_position,
	override_rotation
)
	local volume, spatial_data = spatial.mix(
		unit_or_position,
		decay,
		min_distance,
		max_distance,
		override_position,
		override_rotation
	)

	if not spatial_data then
		return false
	end

	return native_runtime.set_position(play_id, volume, spatial_data)
end

return file_playback
