local mod = get_mod("SimpleAudio")

local paths = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/paths")
local platform = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/platform")
local utilities = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/utilities")

local playback = {}

local FFPLAY_PATH = "../mods/SimpleAudio/bin/ffplay.exe"
local MAX_DISTANCE = 100
local DECAY = 0.01
local AUDIO_TYPE_VOLUME = {
	dialogue = function()
		return ((Application.user_setting("sound_settings", "options_vo_trim") or 0) / 10) + 1
	end,
	music = function()
		return (Application.user_setting("sound_settings", "options_music_slider") or 100) / 100
	end,
	sfx = function()
		return (Application.user_setting("sound_settings", "options_sfx_slider") or 100) / 100
	end,
}

local function listener_position_rotation()
	local player = Managers.player and Managers.player:local_player_safe(1)

	if not player then
		return Vector3.zero(), Quaternion.identity()
	end

	local listener_pose = Managers.state.camera:listener_pose(player.viewport_name)
	local listener_position = listener_pose and Matrix4x4.translation(listener_pose) or Vector3.zero()
	local listener_rotation = listener_pose and Matrix4x4.rotation(listener_pose) or Quaternion.identity()

	return listener_position, listener_rotation
end

local function volume_adjustment(audio_type)
	local master_volume = (Application.user_setting("sound_settings", "option_master_slider") or 100) / 100

	if audio_type == nil then
		return master_volume
	end

	local type_volume = AUDIO_TYPE_VOLUME[audio_type]

	if not type_volume then
		error(string.format("Unsupported audio type: %s", tostring(audio_type)))
	end

	return master_volume * type_volume()
end

local function spatial_mix(unit_or_position)
	if not Managers.ui or Managers.ui:get_current_sub_state_name() ~= "GameplayStateRun" then
		return 100, 1, 1
	end

	local input_type = utilities.userdata_type(unit_or_position)

	if input_type ~= "Unit" and input_type ~= "Vector3" then
		return 100, 1, 1
	end

	local position = input_type == "Unit" and Unit.local_position(unit_or_position, 1) or unit_or_position
	local listener_position, listener_rotation = listener_position_rotation()
	local distance = Vector3.distance(position, listener_position)
	local ratio = 1 - math.clamp(distance / MAX_DISTANCE, 0, 1)
	local volume = math.clamp(100 * (ratio - distance * DECAY), 0, 100)
	local direction = position - listener_position
	local local_direction = Quaternion.rotate(Quaternion.inverse(listener_rotation), direction)
	local normalized_direction = Vector3.normalize(local_direction)
	local angle = math.atan2(normalized_direction.x, normalized_direction.y)
	local pan

	if angle > 0 then
		if angle <= math.pi / 2 then
			pan = angle / (math.pi / 2)
		else
			pan = 1 - (angle - math.pi / 2) / (math.pi / 2)
		end
	elseif angle >= -math.pi / 2 then
		pan = angle / (math.pi / 2)
	else
		pan = -(1 + (angle + math.pi / 2) / (math.pi / 2))
	end

	local left_volume = pan > 0 and 1 - pan or 1
	local right_volume = pan < 0 and 1 + pan or 1

	return volume, left_volume, right_volume
end

playback.play_file = function(audio_path, playback_settings, unit_or_position)
	playback_settings = playback_settings or {}

	local volume, left_volume, right_volume = spatial_mix(unit_or_position)
	local resolved_path = paths.resolve_audio_path(audio_path)
	local final_volume = math.round((volume or 100) * volume_adjustment(playback_settings.audio_type))
	local filter = string.format(
		"volume=%s,pan=stereo|c0=%s*c0|c1=%s*c1",
		tostring(final_volume / 100),
		tostring(left_volume or 1),
		tostring(right_volume or 1)
	)
	local success, error_message = platform.start_process(FFPLAY_PATH, {
		"-i",
		resolved_path,
		"-af",
		filter,
		"-fast",
		"-nodisp",
		"-autoexit",
		"-loglevel",
		"quiet",
		"-hide_banner",
	}, resolved_path)

	if not success then
		mod:error(mod:localize("play_failed", resolved_path, error_message))

		return false
	end

	return true
end

return playback
