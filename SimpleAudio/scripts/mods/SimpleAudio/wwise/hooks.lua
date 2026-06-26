local mod = get_mod("SimpleAudio")

local context = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/context")

local wwise_hooks = {}
local registered_hooks = {}
local silenced = {}

local SOUND_TYPE = {
	["nil"] = "2d_sound",
	["boolean"] = "start_stop_event",
	["number"] = "source_sound",
	["Vector3"] = "3d_sound",
	["Unit"] = "unit_sound",
}

local function infer_sound_type(value)
	local value_type = context.userdata_type(value) or type(value)

	return SOUND_TYPE[value_type] or value_type
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
		local hook_result = run_hooks(
			infer_sound_type(position_or_unit_or_id),
			event_name,
			position_or_unit_or_id,
			optional_a,
			optional_b
		)

		if hook_result == false or wwise_hooks.is_sound_silenced(event_name) then
			return
		end

		return func(wwise_world, event_name, ...)
	end)

	mod:hook(DialogueSystemWwise, "trigger_vorbis_external_event", function(func, dialogue_system, sound_event, sound_source, file_path, wwise_source_id)
		local event_name = file_path:gsub("^wwise/externals/", "")
		local hook_result = run_hooks("external_sound", event_name, wwise_source_id, sound_event, sound_source)

		if hook_result == false
			or wwise_hooks.is_sound_silenced(event_name)
			or wwise_hooks.is_sound_silenced(file_path)
		then
			return
		end

		return func(dialogue_system, sound_event, sound_source, file_path, wwise_source_id)
	end)
end

return wwise_hooks
