local mod = get_mod("SimpleAudio")

local paths = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/paths")
local utilities = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/utilities")

local wwise_hooks = {}
local hooks = {}

wwise_hooks.hook_sound = function(pattern, callback)
	if not hooks[pattern] then
		hooks[pattern] = {
			callbacks = {},
		}
	end

	hooks[pattern].callbacks[paths.caller_mod_name()] = callback
end

local function run_hooks(event_name, position_or_unit_or_id, optional_a, optional_b)
	for pattern, hook_data in pairs(hooks) do
		if event_name:match(pattern) then
			local now = Managers.time:time("main")
			local delta = hook_data.last_run and now - hook_data.last_run or nil

			hook_data.last_run = now

			for _, callback in pairs(hook_data.callbacks) do
				return callback(
					utilities.sound_type(position_or_unit_or_id),
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

wwise_hooks.install = function()
	mod:hook(WwiseWorld, "trigger_resource_event", function(func, wwise_world, event_name, ...)
		local hook_result = run_hooks(event_name, ...)

		if hook_result == false then
			return
		end

		return func(wwise_world, event_name, ...)
	end)
end

return wwise_hooks
