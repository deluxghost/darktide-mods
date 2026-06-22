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

local function append_filter(filters, playback_settings, key)
	local value = playback_settings[key]

	if value ~= nil and value ~= false then
		filters[#filters + 1] = key .. "=" .. tostring(value)
	end
end

local function filter_argument(volume_gain, left_volume, right_volume, playback_settings)
	local filters = {
		string.format("volume=%s", tostring(volume_gain)),
		string.format(
			"pan=stereo|c0=%s*c0|c1=%s*c1",
			tostring(left_volume or 1),
			tostring(right_volume or 1)
		),
	}

	append_filter(filters, playback_settings, "adelay")
	append_filter(filters, playback_settings, "aecho")
	append_filter(filters, playback_settings, "afade")
	append_filter(filters, playback_settings, "atempo")
	append_filter(filters, playback_settings, "chorus")
	append_filter(filters, playback_settings, "silenceremove")
	append_filter(filters, playback_settings, "speechnorm")
	append_filter(filters, playback_settings, "stereotools")

	return table.concat(filters, ",")
end

local function append_option(arguments, option, value)
	if value ~= nil and value ~= false then
		arguments[#arguments + 1] = option
		arguments[#arguments + 1] = tostring(value)
	end
end

local function spatial_mix(unit_or_position, decay, min_distance, max_distance, override_position, override_rotation)
	if not Managers.ui or Managers.ui:get_current_sub_state_name() ~= "GameplayStateRun" then
		return 100, 1, 1
	end

	local input_type = utilities.userdata_type(unit_or_position)

	if input_type ~= "Unit" and input_type ~= "Vector3" then
		return 100, 1, 1
	end

	local position = input_type == "Unit" and Unit.local_position(unit_or_position, 1) or unit_or_position
	local current_listener_position, current_listener_rotation

	if not override_position or not override_rotation then
		current_listener_position, current_listener_rotation = listener_position_rotation()
	end

	local listener_position = override_position or current_listener_position
	local listener_rotation = override_rotation or current_listener_rotation
	decay = decay or DECAY
	min_distance = min_distance or 0
	max_distance = max_distance or MAX_DISTANCE

	local distance = Vector3.distance(position, listener_position)
	local volume

	if distance < min_distance then
		volume = 100
	elseif distance > max_distance then
		volume = 0
	else
		local ratio = 1 - math.clamp((distance - min_distance) / (max_distance - min_distance), 0, 1)

		volume = math.clamp(100 * (ratio - (distance - min_distance) * decay), 0, 100)
	end

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

	local volume, left_volume, right_volume = spatial_mix(
		unit_or_position,
		decay,
		min_distance,
		max_distance,
		override_position,
		override_rotation
	)
	local resolved_path = paths.resolve_audio_path(audio_path)
	local volume_multiplier = playback_settings.volume and playback_settings.volume / 100 or 1
	local volume_gain = (volume or 100) / 100 * volume_adjustment(playback_settings.audio_type) * volume_multiplier
	local filter = filter_argument(volume_gain, left_volume, right_volume, playback_settings)
	local arguments = {
		"-i",
		resolved_path,
		"-af",
		filter,
	}

	append_option(arguments, "-loop", playback_settings.loop)
	append_option(arguments, "-ss", playback_settings.pos)
	append_option(arguments, "-t", playback_settings.duration)

	arguments[#arguments + 1] = "-fast"
	arguments[#arguments + 1] = "-nodisp"
	arguments[#arguments + 1] = "-autoexit"
	arguments[#arguments + 1] = "-loglevel"
	arguments[#arguments + 1] = "quiet"
	arguments[#arguments + 1] = "-hide_banner"

	local play_file_id, error_message = platform.start_process(FFPLAY_PATH, arguments, resolved_path)

	if not play_file_id then
		mod:error(mod:localize("play_failed", resolved_path, error_message))

		return false
	end

	return play_file_id
end

return playback
