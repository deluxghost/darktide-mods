local mod = get_mod("SimpleAudio")

local context = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/context")

local wwise_hooks = {}
local registered_hooks = {}
local silenced = {}

local COMMON_SOUND_PATTERNS = {
	"husk",
	"foley",
	"footstep",
	"locomotion",
	"material",
	"upper_body",
	"vce",
}

local SOUND_TYPE = {
	["nil"] = "2d_sound",
	["boolean"] = "start_stop_event",
	["number"] = "source_sound",
	["Vector3"] = "3d_sound",
	["Unit"] = "unit_sound",
}

local log_wwise = mod:get("log_wwise", false)
local log_wwise_ui = mod:get("log_wwise_ui", false)
local log_wwise_common = mod:get("log_wwise_common", false)
local log_silenced = mod:get("log_silenced", true)
local log_wwise_verbose = mod:get("log_wwise_verbose", false)
local log_to_chat = mod:get("log_to_chat", false)

local function infer_sound_type(value)
	local value_type = context.userdata_type(value) or type(value)

	return SOUND_TYPE[value_type] or value_type
end

local function is_ui_sound(event_name)
	return event_name:find("events/ui/", 1, true) ~= nil
end

local function is_common_sound(event_name)
	for _, pattern in ipairs(COMMON_SOUND_PATTERNS) do
		if event_name:find(pattern, 1, true) then
			return true
		end
	end

	return false
end

local function should_log_wwise_event(event_name, is_silenced)
	return log_wwise
		and (log_silenced or not is_silenced)
		and not (is_ui_sound(event_name) and not log_wwise_ui)
		and not (is_common_sound(event_name) and not log_wwise_common)
end

local function should_log_dialogue_event(is_silenced)
	return log_wwise and (log_silenced or not is_silenced)
end

local function log_event(event_name, sound_type, verbose_data)
	if log_wwise_verbose then
		mod:dump(verbose_data)
	elseif log_to_chat then
		mod:echo(event_name)
	else
		print(event_name, sound_type)
	end
end

wwise_hooks.hook_sound = function(pattern, callback)
	if not registered_hooks[pattern] then
		registered_hooks[pattern] = {
			callbacks = {},
		}
	end

	registered_hooks[pattern].callbacks[context.mod_name()] = callback
end

wwise_hooks.silence_sounds = function(patterns)
	if type(patterns) == "string" then
		silenced[patterns] = true

		return
	end

	for _, pattern in ipairs(patterns) do
		silenced[pattern] = true
	end
end

wwise_hooks.unsilence_sounds = function(patterns)
	if type(patterns) == "string" then
		silenced[patterns] = nil

		return
	end

	for _, pattern in ipairs(patterns) do
		silenced[pattern] = nil
	end
end

wwise_hooks.is_sound_silenced = function(event_name)
	for pattern in pairs(silenced) do
		if event_name:match(pattern) then
			return true
		end
	end

	return false
end

local function run_hooks(sound_type, event_name, position_or_unit_or_id, optional_a, optional_b)
	local should_silence

	for pattern, hook_data in pairs(registered_hooks) do
		if event_name:match(pattern) then
			local now = Managers.time:time("main")
			local delta = hook_data.last_run and now - hook_data.last_run or nil

			hook_data.last_run = now

			for _, callback in pairs(hook_data.callbacks) do
				local result = callback(
					sound_type,
					event_name,
					delta,
					position_or_unit_or_id,
					optional_a,
					optional_b
				)

				if result == false then
					should_silence = true
				end
			end
		end
	end

	if should_silence then
		return false
	end
end

wwise_hooks.install = function()
	mod:hook(WwiseWorld, "trigger_resource_event", function(func, wwise_world, event_name, ...)
		local position_or_unit_or_id, optional_a, optional_b = ...
		local sound_type = infer_sound_type(position_or_unit_or_id)
		local hook_result = run_hooks(
			sound_type,
			event_name,
			position_or_unit_or_id,
			optional_a,
			optional_b
		)
		local sound_is_silenced = hook_result == false or wwise_hooks.is_sound_silenced(event_name)

		if should_log_wwise_event(event_name, sound_is_silenced) then
			log_event(event_name, sound_type, {
				sound_type = sound_type,
				wwise_event_name = event_name,
				position_or_unit_or_id = position_or_unit_or_id,
				optional_a = optional_a,
				optional_b = optional_b,
				silenced = sound_is_silenced,
			})
		end

		if sound_is_silenced then
			return
		end

		return func(wwise_world, event_name, ...)
	end)

	mod:hook(DialogueSystemWwise, "trigger_vorbis_external_event", function(func, dialogue_system, sound_event, sound_source, file_path, wwise_source_id)
		local event_name = file_path:gsub("^wwise/externals/", "")
		local hook_result = run_hooks("external_sound", event_name, wwise_source_id, sound_event, sound_source)
		local sound_is_silenced = hook_result == false
			or wwise_hooks.is_sound_silenced(event_name)
			or wwise_hooks.is_sound_silenced(file_path)

		if should_log_dialogue_event(sound_is_silenced) then
			log_event(event_name, "external_sound", {
				sound_type = "external_sound",
				sound_event = sound_event,
				sound_source = sound_source,
				event_name = event_name,
				file_path = file_path,
				wwise_source_id = wwise_source_id,
				silenced = sound_is_silenced,
			})
		end

		if sound_is_silenced then
			return
		end

		return func(dialogue_system, sound_event, sound_source, file_path, wwise_source_id)
	end)
end

wwise_hooks.on_setting_changed = function(setting_name)
	if setting_name == "log_wwise" then
		log_wwise = mod:get("log_wwise", false)
	elseif setting_name == "log_wwise_ui" then
		log_wwise_ui = mod:get("log_wwise_ui", false)
	elseif setting_name == "log_wwise_common" then
		log_wwise_common = mod:get("log_wwise_common", false)
	elseif setting_name == "log_silenced" then
		log_silenced = mod:get("log_silenced", true)
	elseif setting_name == "log_wwise_verbose" then
		log_wwise_verbose = mod:get("log_wwise_verbose", false)
	elseif setting_name == "log_to_chat" then
		log_to_chat = mod:get("log_to_chat", false)
	end
end

return wwise_hooks
