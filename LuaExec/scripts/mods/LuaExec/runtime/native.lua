local mod = get_mod("LuaExec")
local ffi = Mods.lua.ffi

local native = {}

local RUNTIME_PATH = "../mods/LuaExec/bin/luaexec-runtime.dll"
local REQUEST_BUFFER_SIZE = 4 * 1024 * 1024 + 1
local ERROR_BUFFER_SIZE = 4096

local instances = mod:persistent_table("instances")
instances.luaexec_runtime = instances.luaexec_runtime or {}

local state = instances.luaexec_runtime

if not pcall(ffi.typeof, "LuaExecRuntime_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } LuaExecRuntime_CDEF;

		int LuaExecRuntime_Start(char* error_buffer, int error_buffer_size);
		void LuaExecRuntime_Stop(void);
		int LuaExecRuntime_PollRequest(int* request_id, char* buffer, int buffer_size, char* error_buffer, int error_buffer_size);
		int LuaExecRuntime_SendResponse(int request_id, const char* payload, char* error_buffer, int error_buffer_size);
	]])
end

local request_id_buffer = ffi.new("int[1]")
local request_buffer = ffi.new("char[?]", REQUEST_BUFFER_SIZE)
local error_buffer = ffi.new("char[?]", ERROR_BUFFER_SIZE)

local function buffer_string(buffer)
	local value = ffi.string(buffer)

	if value == "" then
		return nil
	end

	return value
end

local function load_runtime()
	if state.runtime then
		return state.runtime
	end

	local ok, runtime_or_error = pcall(ffi.load, RUNTIME_PATH)

	if not ok then
		return nil, tostring(runtime_or_error)
	end

	state.runtime = runtime_or_error

	return state.runtime
end

native.start = function()
	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local ok = runtime.LuaExecRuntime_Start(error_buffer, ERROR_BUFFER_SIZE)

	if ok == 0 then
		return false, buffer_string(error_buffer) or "LuaExec runtime failed to start"
	end

	return true
end

native.poll_request = function()
	local runtime = state.runtime

	if not runtime then
		return nil
	end

	local result = runtime.LuaExecRuntime_PollRequest(request_id_buffer, request_buffer, REQUEST_BUFFER_SIZE, error_buffer, ERROR_BUFFER_SIZE)

	if result == 0 then
		return nil
	end
	if result < 0 then
		return false, buffer_string(error_buffer) or "LuaExec runtime failed to poll request"
	end

	return tonumber(request_id_buffer[0]), ffi.string(request_buffer)
end

native.send_response = function(request_id, payload)
	local runtime = state.runtime

	if not runtime then
		return false, "LuaExec runtime is not initialized"
	end

	local ok = runtime.LuaExecRuntime_SendResponse(request_id, payload, error_buffer, ERROR_BUFFER_SIZE)

	if ok == 0 then
		return false, buffer_string(error_buffer) or "LuaExec runtime failed to send response"
	end

	return true
end

native.stop = function()
	local runtime = state.runtime

	if runtime then
		runtime.LuaExecRuntime_Stop()
	end

	state.runtime = nil
end

return native
