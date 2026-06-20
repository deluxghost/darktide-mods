local mod = get_mod("SimpleAudio")
local ffi = Mods.lua.ffi

local AUDIO_DLL_PATH = "../mods/SimpleAudio/bin/darktide-audio.dll"
local ERROR_BUFFER_SIZE = 1024
local MAX_DISTANCE = 100
local DECAY = 0.01
local SOUND_TYPE = {
	["nil"] = "2d_sound",
	["boolean"] = "start_stop_event",
	["number"] = "source_sound",
	["Vector3"] = "3d_sound",
	["Unit"] = "unit_sound",
}
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

local instances = mod:persistent_table("instances")
local wwise_hooks = {}

if instances.audio == nil then
	ffi.cdef([[
		int DarktideAudio_Init();
		int DarktideAudio_PlayFile(const char* audio_path, int volume, double left_volume, double right_volume);
		int DarktideAudio_Shutdown();
		int DarktideAudio_LastError(char* buffer, int buffer_size);
	]])
	instances.audio = ffi.load(AUDIO_DLL_PATH)
	instances.error_buffer = ffi.new("char[?]", ERROR_BUFFER_SIZE)
end

local function audio_error()
	instances.audio.DarktideAudio_LastError(instances.error_buffer, ERROR_BUFFER_SIZE)

	return ffi.string(instances.error_buffer)
end

local function userdata_type(value)
	if type(value) ~= "userdata" then
		return nil
	end

	if Unit.alive(value) then
		return "Unit"
	elseif Vector3.is_valid(value) then
		return "Vector3"
	end
end

local function sound_type(value)
	local value_type = userdata_type(value) or type(value)

	return SOUND_TYPE[value_type] or value_type
end

local function caller_mod_name()
	local highest_mod_in_stack
	local highest_non_library_mod_in_stack

	for i = 2, 32 do
		local info = debug.getinfo(i, "S")

		if not info then
			break
		end

		local source = info.source:gsub("\\", "/")
		local calling_mod_name = source:match("/mods/([^/]+)/scripts/")

		if not calling_mod_name and i > 2 then
			break
		end

		if calling_mod_name and calling_mod_name ~= "dmf" then
			highest_mod_in_stack = calling_mod_name

			if calling_mod_name ~= "SimpleAudio" then
				highest_non_library_mod_in_stack = calling_mod_name
			end
		end
	end

	return highest_non_library_mod_in_stack or highest_mod_in_stack or "unknown"
end

local function resolve_audio_path(audio_path)
	local normalized_path = audio_path:gsub("\\", "/"):gsub("^/", "")

	if normalized_path:match("^%a:/") then
		return normalized_path
	end

	local caller_name = caller_mod_name()

	if normalized_path:sub(1, #caller_name + 1) == caller_name .. "/" then
		return "../mods/" .. normalized_path
	end

	if normalized_path:sub(1, 6) == "audio/" then
		return "../mods/" .. caller_name .. "/" .. normalized_path
	end

	return "../mods/" .. caller_name .. "/audio/" .. normalized_path
end

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

	local input_type = userdata_type(unit_or_position)

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

if instances.audio.DarktideAudio_Init() ~= 1 then
	mod:error(mod:localize("init_failed", audio_error()))
end

local function play_with_mix(audio_path, playback_settings, volume, left_volume, right_volume)
	playback_settings = playback_settings or {}

	local final_volume = math.round((volume or 100) * volume_adjustment(playback_settings.audio_type))
	local result = instances.audio.DarktideAudio_PlayFile(audio_path, final_volume, left_volume or 1, right_volume or 1)

	if result ~= 1 then
		mod:error(mod:localize("play_failed", audio_path, audio_error()))

		return false
	end

	return true
end

local function run_wwise_hooks(event_name, position_or_unit_or_id, optional_a, optional_b)
	for pattern, hook_data in pairs(wwise_hooks) do
		if event_name:match(pattern) then
			local now = Managers.time:time("main")
			local delta = hook_data.last_run and now - hook_data.last_run or nil

			hook_data.last_run = now

			for _, callback in pairs(hook_data.callbacks) do
				return callback(
					sound_type(position_or_unit_or_id),
					event_name,
					delta,
					position_or_unit_or_id,
					optional_a,
					optional_b
				)
			end
		end
	end
end

mod.play_file = function(audio_path, playback_settings, unit_or_position)
	local volume, left_volume, right_volume = spatial_mix(unit_or_position)

	return play_with_mix(resolve_audio_path(audio_path), playback_settings, volume, left_volume, right_volume)
end

mod.hook_sound = function(pattern, callback)
	if not wwise_hooks[pattern] then
		wwise_hooks[pattern] = {
			callbacks = {},
		}
	end

	wwise_hooks[pattern].callbacks[caller_mod_name()] = callback
end

mod.on_all_mods_loaded = function()
	mod:hook(WwiseWorld, "trigger_resource_event", function(func, wwise_world, event_name, ...)
		local hook_result = run_wwise_hooks(event_name, ...)

		if hook_result == false then
			return
		end

		return func(wwise_world, event_name, ...)
	end)
end

mod.on_unload = function()
	if instances.audio then
		instances.audio.DarktideAudio_Shutdown()
	end
end
