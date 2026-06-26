local mod = get_mod("SimpleAudio")

local paths = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/paths")
local utilities = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/core/utilities")

local hooks_api = {}
local registered_hooks = {}
local silenced = {}

hooks_api.hook_sound = function(pattern, callback)
	if not registered_hooks[pattern] then
		registered_hooks[pattern] = {
			callbacks = {},
		}
	end

	registered_hooks[pattern].callbacks[paths.caller_mod_name()] = callback
end

hooks_api.silence_sounds = function(patterns)
	if type(patterns) == "string" then
		silenced[patterns] = true

		return
	end

	for _, pattern in ipairs(patterns) do
		silenced[pattern] = true
	end
end

hooks_api.unsilence_sounds = function(patterns)
	if type(patterns) == "string" then
		silenced[patterns] = nil

		return
	end

	for _, pattern in ipairs(patterns) do
		silenced[pattern] = nil
	end
end

hooks_api.is_sound_silenced = function(event_name)
	for pattern in pairs(silenced) do
		if event_name:match(pattern) then
			return true
		end
	end

	return false
end

local function run_hooks(sound_type, event_name, position_or_unit_or_id, optional_a, optional_b)
	for pattern, hook_data in pairs(registered_hooks) do
		if event_name:match(pattern) then
			local now = Managers.time:time("main")
			local delta = hook_data.last_run and now - hook_data.last_run or nil

			hook_data.last_run = now

			for _, callback in pairs(hook_data.callbacks) do
				return callback(
					sound_type,
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

hooks_api.install = function()
	mod:hook(WwiseWorld, "trigger_resource_event", function(func, wwise_world, event_name, ...)
		local position_or_unit_or_id, optional_a, optional_b = ...
		local hook_result = run_hooks(
			utilities.sound_type(position_or_unit_or_id),
			event_name,
			position_or_unit_or_id,
			optional_a,
			optional_b
		)

		if hook_result == false or hooks_api.is_sound_silenced(event_name) then
			return
		end

		return func(wwise_world, event_name, ...)
	end)

	mod:hook(DialogueSystemWwise, "trigger_vorbis_external_event", function(func, dialogue_system, sound_event, sound_source, file_path, wwise_source_id)
		local event_name = file_path:gsub("^wwise/externals/", "")
		local hook_result = run_hooks("external_sound", event_name, wwise_source_id, sound_event, sound_source)

		if hook_result == false
			or hooks_api.is_sound_silenced(event_name)
			or hooks_api.is_sound_silenced(file_path)
		then
			return
		end

		return func(dialogue_system, sound_event, sound_source, file_path, wwise_source_id)
	end)
end

return hooks_api
