local ffi = Mods.lua.ffi

local BIN = "../mods/GoodOldOutlines/bin/"
local ERROR_CAPACITY = 1024
local declared = pcall(ffi.typeof, "GoodOldOutlines_RuntimeAbiDeclared")
if not declared then
	ffi.cdef([[
		const void* GoodOldOutlines_GetConfig(uint32_t* size, char* error, int capacity);
		int GoodOldOutlines_ApplyConfig(const void* data, uint32_t size, char* error, int capacity);
		int GoodOldOutlines_RestoreConfig(char* error, int capacity);
		int GoodOldOutlines_Start(const char* shader_directory, char* error, int capacity);
		int GoodOldOutlines_SetEnabled(int enabled);
		const char* GoodOldOutlines_GetError(void);
		int GoodOldOutlines_Remove(char* error, int capacity);
		typedef int GoodOldOutlines_RuntimeAbiDeclared;
	]])
end

local function new(state)
	local error_buffer = ffi.new("char[?]", ERROR_CAPACITY)
	local config_size = ffi.new("uint32_t[1]")
	local api = {}

	local function library()
		if not state.library then
			state.library = ffi.load(BIN .. "GoodOldOutlines.dll")
		end
		return state.library
	end

	local function result(code)
		if code ~= 1 then
			return false, ffi.string(error_buffer)
		end
		return true, nil
	end

	local function check(code)
		assert(result(code))
	end

	function api.snapshot()
		local pointer = library().GoodOldOutlines_GetConfig(config_size, error_buffer, ERROR_CAPACITY)
		assert(pointer ~= nil, ffi.string(error_buffer))
		return ffi.string(pointer, config_size[0])
	end

	function api.start()
		check(library().GoodOldOutlines_Start(BIN, error_buffer, ERROR_CAPACITY))
	end

	function api.apply_config(snapshot)
		return result(library().GoodOldOutlines_ApplyConfig(snapshot, #snapshot, error_buffer, ERROR_CAPACITY))
	end

	function api.restore_config()
		check(library().GoodOldOutlines_RestoreConfig(error_buffer, ERROR_CAPACITY))
	end

	function api.set_enabled(enabled)
		assert(library().GoodOldOutlines_SetEnabled(enabled and 1 or 0) == 1, "Cannot change outline runtime state")
	end

	function api.remove()
		return result(library().GoodOldOutlines_Remove(error_buffer, ERROR_CAPACITY))
	end

	function api.error_message()
		local message = library().GoodOldOutlines_GetError()
		if message ~= nil then
			return ffi.string(message)
		end
	end

	return api
end

return { new = new }
