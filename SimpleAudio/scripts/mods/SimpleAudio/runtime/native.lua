local mod = get_mod("SimpleAudio")
local ffi = Mods.lua.ffi

local windows = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/platform/windows")

local native = {}

local RUNTIME_PATH = "../mods/SimpleAudio/bin/simple-audio-runtime.dll"
local ERROR_BUFFER_SIZE = 4096
local EVENT_FINISHED = 1
local EVENT_ERROR = 2

local instances = mod:persistent_table("instances")
instances.simple_audio_runtime = instances.simple_audio_runtime or {}

local state = instances.simple_audio_runtime
state.play_callbacks = state.play_callbacks or {}

if not pcall(ffi.typeof, "SimpleAudioRuntime_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } SimpleAudioRuntime_CDEF;

		int SimpleAudioRuntime_Initialize(char* error_buffer, int error_buffer_size);
		int SimpleAudioRuntime_Play(const char* path, double volume_gain, double left_gain, double right_gain, double pos, double duration, int loop_count, char* error_buffer, int error_buffer_size);
		int SimpleAudioRuntime_Stop(int play_id);
		void SimpleAudioRuntime_StopAll(void);
		int SimpleAudioRuntime_IsPlaying(int play_id);
		int SimpleAudioRuntime_PollEvent(int* event_type, int* play_id, char* message_buffer, int message_buffer_size);
		void SimpleAudioRuntime_Shutdown(void);
	]])
end

local function error_buffer()
	return ffi.new("char[?]", ERROR_BUFFER_SIZE)
end

local event_type_buffer = ffi.new("int[1]")
local event_play_id_buffer = ffi.new("int[1]")
local event_message_buffer = error_buffer()

local function buffer_string(buffer)
	return ffi.string(buffer)
end

local function load_runtime()
	if state.runtime then
		return state.runtime
	end

	local ok, runtime_or_error = pcall(ffi.load, windows.path(RUNTIME_PATH))

	if not ok then
		return nil, tostring(runtime_or_error)
	end

	state.runtime = runtime_or_error

	return state.runtime
end

local function normalize_loop_count(loop)
	if loop == nil or loop == false then
		return 0
	end
	if loop == true then
		return -1
	end

	return math.max(tonumber(loop) or 0, 0)
end

local function playback_seconds(value, field_name, default)
	if value == nil or value == false then
		return default
	end

	local seconds = tonumber(value)

	if not seconds then
		return nil, string.format("playback_settings.%s must be numeric seconds, got %s", field_name, tostring(value))
	end

	return seconds
end

native.initialize = function()
	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local buffer = error_buffer()
	local ok = runtime.SimpleAudioRuntime_Initialize(buffer, ERROR_BUFFER_SIZE)

	if ok == 0 then
		return false, buffer_string(buffer)
	end

	return true
end

native.play = function(path, options)
	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local pos, pos_error = playback_seconds(options.pos, "pos", 0)

	if pos_error then
		return false, pos_error
	end

	local duration, duration_error = playback_seconds(options.duration, "duration", -1)

	if duration_error then
		return false, duration_error
	end

	local buffer = error_buffer()
	local play_id = runtime.SimpleAudioRuntime_Play(
		windows.path(path),
		options.volume_gain or 1,
		options.left_gain or 1,
		options.right_gain or 1,
		pos,
		duration,
		normalize_loop_count(options.loop),
		buffer,
		ERROR_BUFFER_SIZE
	)

	if play_id <= 0 then
		return false, buffer_string(buffer)
	end

	if type(options.on_finished) == "function" then
		state.play_callbacks[tonumber(play_id)] = options.on_finished
	end

	return tonumber(play_id)
end

native.stop = function(play_id)
	local runtime = state.runtime

	if not runtime then
		return play_id == nil
	end

	if play_id == nil then
		runtime.SimpleAudioRuntime_StopAll()
		state.play_callbacks = {}

		return true
	end

	local stopped = runtime.SimpleAudioRuntime_Stop(play_id) ~= 0

	if stopped then
		state.play_callbacks[play_id] = nil
	end

	return stopped
end

native.is_playing = function(play_id)
	local runtime = state.runtime

	if not runtime or play_id == nil then
		return false
	end

	return runtime.SimpleAudioRuntime_IsPlaying(play_id) ~= 0
end

native.update = function()
	local runtime = state.runtime

	if not runtime then
		return
	end

	while true do
		local result = runtime.SimpleAudioRuntime_PollEvent(event_type_buffer, event_play_id_buffer, event_message_buffer, ERROR_BUFFER_SIZE)

		if result == 0 then
			return
		end
		if result < 0 then
			mod:error("Failed to poll SimpleAudio runtime event")

			return
		end

		local id = tonumber(event_play_id_buffer[0])

		if event_type_buffer[0] == EVENT_FINISHED then
			local callback = state.play_callbacks[id]
			state.play_callbacks[id] = nil

			if callback then
				callback()
			end
		elseif event_type_buffer[0] == EVENT_ERROR then
			state.play_callbacks[id] = nil
			mod:error(buffer_string(event_message_buffer))
		end
	end
end

native.shutdown = function()
	local runtime = state.runtime

	if runtime then
		runtime.SimpleAudioRuntime_Shutdown()
	end

	state.play_callbacks = {}
	state.runtime = nil
end

return native
