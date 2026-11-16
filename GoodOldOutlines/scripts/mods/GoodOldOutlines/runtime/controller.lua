local function new(mod, outline_identity)
	local HEADER_WORDS, NODE_WORDS, FRAGMENTS_PER_PIXEL = 4, 4, 4
	-- installed tracks hook ownership, including unfinished cleanup; active tracks drawing.
	local state = mod:persistent_table("runtime")
	local Config = mod:io_dofile("GoodOldOutlines/scripts/mods/GoodOldOutlines/runtime/config")
	local Native = mod:io_dofile("GoodOldOutlines/scripts/mods/GoodOldOutlines/runtime/native").new(state)
	local api = {}
	local layer_width, layer_height

	function api.is_enabled()
		return mod:is_enabled() and not state.failed
	end

	local function synchronize_renderer()
		-- This getter waits for the previous renderer job before its config changes.
		Application.render_config("settings", "outline_enabled")
	end

	local function enable()
		assert(not state.installed, "Outline runtime is already installed")
		synchronize_renderer()
		local layers = mod:get("show_rear_outlines")
		local buffer_words, buffer_bytes = 0, 0
		if layers then
			layer_width, layer_height = RESOLUTION_LOOKUP.width, RESOLUTION_LOOKUP.height
			local pixels = layer_width * layer_height
			buffer_words = math.ceil((HEADER_WORDS + pixels * (1 + NODE_WORDS * FRAGMENTS_PER_PIXEL)) / 256) * 256
			buffer_bytes = buffer_words * 4
			assert(buffer_bytes <= 2147483647, "Layered outline buffer exceeds the render resource size limit")
		end
		local modified = Config.prepare(Native.snapshot(), layers, buffer_bytes)
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
		local configured, binding, layer_error = Native.configure_layers(layers)
		if not configured then
			Native.restore_config()
			synchronize_renderer()
			assert(Native.remove())
			state.installed = false
			return layer_error
		end
		outline_identity.set_buffer(binding, buffer_words)
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
		outline_identity.set_buffer(0, 0)
		Native.restore_config()
		synchronize_renderer()
		assert(Native.remove())
		state.installed = false
		-- Retain the DLL and its PSOs: submitted GPU work can outlive Lua callbacks.
		mod:info("Original outline rendering restored")
	end

	function api.request_enable()
		state.pending = api.is_enabled() and not state.active
	end

	function api.update()
		if state.active and mod:get("show_rear_outlines")
			and (layer_width ~= RESOLUTION_LOOKUP.width or layer_height ~= RESOLUTION_LOOKUP.height) then
			api.disable()
			api.request_enable()
		end
		if state.pending and api.is_enabled() then
			state.pending = false
			local message = enable()
			if message then
				state.failed = true
				return message
			end
		end
		if not state.active or state.failed then
			return
		end
		local message = Native.error_message()
		if message then
			state.failed = true
			return message
		end
		local warning = Native.warning_message()
		while warning do
			mod:warning("%s", warning)
			warning = Native.warning_message()
		end
	end

	return api
end

return { new = new }
