local function new(mod)
	-- installed tracks hook ownership, including unfinished cleanup; active tracks drawing.
	local state = mod:persistent_table("runtime")
	local Config = mod:io_dofile("GoodOldOutlines/scripts/mods/GoodOldOutlines/runtime/config")
	local Native = mod:io_dofile("GoodOldOutlines/scripts/mods/GoodOldOutlines/runtime/native").new(state)
	local api = {}

	local function synchronize_renderer()
		-- This getter waits for the previous renderer job before its config changes.
		Application.render_config("settings", "outline_enabled")
	end

	local function enable()
		assert(not state.installed, "Outline runtime is already installed")
		synchronize_renderer()
		local modified = Config.prepare(Native.snapshot())
		Native.start()
		state.installed = true
		local applied, message = Native.apply_config(modified)
		if not applied then
			local removed, remove_message = Native.remove()
			state.installed = not removed
			if not removed then
				error(string.format("%s; outline hook cleanup failed: %s", message, remove_message), 0)
			end
			error(message, 0)
		end
		synchronize_renderer()
		Native.set_enabled(true)
		state.active = true
		mod:info("Runtime outline replacement enabled")
	end

	function api.disable()
		state.pending = false
		if not state.installed then
			return
		end
		Native.set_enabled(false)
		state.active = false
		synchronize_renderer()
		Native.restore_config()
		synchronize_renderer()
		assert(Native.remove())
		state.installed = false
		-- Retain the DLL and its PSOs: submitted GPU work can outlive Lua callbacks.
		mod:info("Original outline rendering restored")
	end

	function api.request_enable()
		state.pending = not state.active
	end

	function api.update()
		if state.pending and mod:is_enabled() then
			state.pending = false
			enable()
		end
		if not state.active then
			return
		end
		local message = Native.error_message()
		if message then
			mod:error("%s", message)
			get_mod("DMF").mod_state_changed(mod:get_name(), false)
		end
	end

	return api
end

return { new = new }
