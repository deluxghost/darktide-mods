local mod = get_mod("SimpleAudio")
local ffi = Mods.lua.ffi

local windows = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/platform/windows")

local native = {}

local RUNTIME_PATH = "../mods/SimpleAudio/bin/simple-audio-runtime.dll"
local ERROR_BUFFER_SIZE = 4096
local INITIALIZATION_SLOW_NOTIFY_SECONDS = 10
local STATUS_UNINITIALIZED = 0
local STATUS_INITIALIZING = 1
local STATUS_READY = 2
local STATUS_FAILED = 3
local STATUS_SHUTTING_DOWN = 4
local EVENT_FINISHED = 1
local EVENT_ERROR = 2

local instances = mod:persistent_table("instances")
instances.simple_audio_runtime = instances.simple_audio_runtime or {}

local state = instances.simple_audio_runtime
state.play_callbacks = state.play_callbacks or {}
state.play_options = state.play_options or {}
state.update_callbacks = state.update_callbacks or {}
state.initialization_restart_pending = state.initialization_restart_pending or false

if not pcall(ffi.typeof, "SimpleAudioRuntime_CDEF") then
	ffi.cdef([[
		typedef struct { int unused; } SimpleAudioRuntime_CDEF;
		typedef void* SimpleAudio_HANDLE;
		typedef unsigned long SimpleAudio_DWORD;
		typedef int SimpleAudio_BOOL;
		typedef unsigned short SimpleAudio_WCHAR;

		typedef struct {
			SimpleAudio_DWORD dwLowDateTime;
			SimpleAudio_DWORD dwHighDateTime;
		} SimpleAudio_FILETIME;

		typedef struct {
			SimpleAudio_DWORD dwFileAttributes;
			SimpleAudio_FILETIME ftCreationTime;
			SimpleAudio_FILETIME ftLastAccessTime;
			SimpleAudio_FILETIME ftLastWriteTime;
			SimpleAudio_DWORD nFileSizeHigh;
			SimpleAudio_DWORD nFileSizeLow;
			SimpleAudio_DWORD dwReserved0;
			SimpleAudio_DWORD dwReserved1;
			SimpleAudio_WCHAR cFileName[260];
			SimpleAudio_WCHAR cAlternateFileName[14];
		} SimpleAudio_WIN32_FIND_DATAW;

		int SimpleAudioRuntime_StartInitialize(char* error_buffer, int error_buffer_size);
		int SimpleAudioRuntime_InitializationStatus(void);
		int SimpleAudioRuntime_InitializationStage(char* buffer, int buffer_size);
		int SimpleAudioRuntime_InitializationError(char* buffer, int buffer_size);
		int SimpleAudioRuntime_Play(const char* path, const char* filters, double volume_gain, double pos, double duration, int loop_count, int spatial, double source_x, double source_y, double source_z, double listener_x, double listener_y, double listener_z, double listener_front_x, double listener_front_y, double listener_front_z, double listener_top_x, double listener_top_y, double listener_top_z, char* error_buffer, int error_buffer_size);
		int SimpleAudioRuntime_FileInfo(const char* path, int* sample_rate, int* channels, double* duration, long long* bit_rate, char** tags_json, char* error_buffer, int error_buffer_size);
		void SimpleAudioRuntime_FreeString(char* value);
		int SimpleAudioRuntime_SetPosition(int play_id, double volume_gain, double source_x, double source_y, double source_z, double listener_x, double listener_y, double listener_z, double listener_front_x, double listener_front_y, double listener_front_z, double listener_top_x, double listener_top_y, double listener_top_z, char* error_buffer, int error_buffer_size);
		int SimpleAudioRuntime_Stop(int play_id);
		void SimpleAudioRuntime_StopAll(void);
		int SimpleAudioRuntime_IsPlaying(int play_id);
		int SimpleAudioRuntime_PollEvent(int* event_type, int* play_id, char* message_buffer, int message_buffer_size);
		void SimpleAudioRuntime_Shutdown(void);
		SimpleAudio_DWORD SimpleAudioRuntime_GetLastError(void);
		int SimpleAudioRuntime_MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, SimpleAudio_WCHAR* lpWideCharStr, int cchWideChar);
		int SimpleAudioRuntime_WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const SimpleAudio_WCHAR* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, SimpleAudio_BOOL* lpUsedDefaultChar);
		SimpleAudio_HANDLE SimpleAudioRuntime_FindFirstFileW(const SimpleAudio_WCHAR* lpFileName, SimpleAudio_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAudio_BOOL SimpleAudioRuntime_FindNextFileW(SimpleAudio_HANDLE hFindFile, SimpleAudio_WIN32_FIND_DATAW* lpFindFileData);
		SimpleAudio_BOOL SimpleAudioRuntime_FindClose(SimpleAudio_HANDLE hFindFile);
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

local function spatial_value(spatial_data, key)
	return spatial_data and spatial_data[key] or 0
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

native.runtime = load_runtime

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

local function initialization_error(runtime)
	local buffer = error_buffer()
	runtime.SimpleAudioRuntime_InitializationError(buffer, ERROR_BUFFER_SIZE)

	local error_message = buffer_string(buffer)

	if error_message == "" then
		return "unknown error"
	end

	return error_message
end

local function initialization_stage(runtime)
	local buffer = error_buffer()
	runtime.SimpleAudioRuntime_InitializationStage(buffer, ERROR_BUFFER_SIZE)

	return buffer_string(buffer)
end

local function runtime_not_ready_error(runtime, status)
	if status == STATUS_INITIALIZING then
		return "SimpleAudio runtime is still initializing"
	end
	if status == STATUS_FAILED then
		return initialization_error(runtime)
	end
	if status == STATUS_SHUTTING_DOWN then
		return "SimpleAudio runtime is shutting down"
	end

	return "SimpleAudio runtime is not initialized"
end

local function ready_runtime()
	local runtime, load_error = load_runtime()

	if not runtime then
		return nil, load_error
	end

	local status = tonumber(runtime.SimpleAudioRuntime_InitializationStatus())

	if status ~= STATUS_READY then
		return nil, runtime_not_ready_error(runtime, status)
	end

	return runtime
end

local function reset_initialization_tracking()
	state.initialization_elapsed = 0
	state.initialization_slow_notified = false
	state.initialization_failure_reported = false
end

local function start_runtime_initialization(runtime)
	local buffer = error_buffer()
	local ok = runtime.SimpleAudioRuntime_StartInitialize(buffer, ERROR_BUFFER_SIZE)

	if ok == 0 then
		return false, buffer_string(buffer)
	end

	state.initialization_restart_pending = false
	reset_initialization_tracking()

	return true
end

native.start_initialize = function()
	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local status = tonumber(runtime.SimpleAudioRuntime_InitializationStatus())

	if status == STATUS_SHUTTING_DOWN then
		state.initialization_restart_pending = true
		reset_initialization_tracking()

		return true
	end

	return start_runtime_initialization(runtime)
end

native.play = function(path, options)
	local runtime, runtime_error = ready_runtime()

	if not runtime then
		return false, runtime_error
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
	local spatial_data = options.spatial_data
	local spatial_enabled = spatial_data and 1 or 0
	local play_id = runtime.SimpleAudioRuntime_Play(
		windows.path(path),
		options.filters,
		options.volume_gain or 1,
		pos,
		duration,
		normalize_loop_count(options.loop),
		spatial_enabled,
		spatial_value(spatial_data, "source_x"),
		spatial_value(spatial_data, "source_y"),
		spatial_value(spatial_data, "source_z"),
		spatial_value(spatial_data, "listener_x"),
		spatial_value(spatial_data, "listener_y"),
		spatial_value(spatial_data, "listener_z"),
		spatial_value(spatial_data, "listener_front_x"),
		spatial_value(spatial_data, "listener_front_y"),
		spatial_value(spatial_data, "listener_front_z"),
		spatial_value(spatial_data, "listener_top_x"),
		spatial_value(spatial_data, "listener_top_y"),
		spatial_value(spatial_data, "listener_top_z"),
		buffer,
		ERROR_BUFFER_SIZE
	)

	if play_id <= 0 then
		return false, buffer_string(buffer)
	end

	if type(options.on_finished) == "function" then
		state.play_callbacks[tonumber(play_id)] = options.on_finished
	end
	if type(options.on_update) == "function" then
		state.update_callbacks[tonumber(play_id)] = options.on_update
	end

	state.play_options[tonumber(play_id)] = {
		base_volume_gain = options.base_volume_gain or options.volume_gain or 1,
	}

	return tonumber(play_id)
end

native.file_info = function(path)
	local runtime, runtime_error = ready_runtime()

	if not runtime then
		return false, runtime_error
	end

	local sample_rate_buffer = ffi.new("int[1]")
	local channels_buffer = ffi.new("int[1]")
	local duration_buffer = ffi.new("double[1]")
	local bit_rate_buffer = ffi.new("long long[1]")
	local tags_json_buffer = ffi.new("char*[1]")
	local buffer = error_buffer()
	local ok = runtime.SimpleAudioRuntime_FileInfo(
		windows.path(path),
		sample_rate_buffer,
		channels_buffer,
		duration_buffer,
		bit_rate_buffer,
		tags_json_buffer,
		buffer,
		ERROR_BUFFER_SIZE
	)

	if ok == 0 then
		return false, buffer_string(buffer)
	end
	if tags_json_buffer[0] == nil then
		return false, "Audio metadata is missing"
	end

	local tags_json = ffi.string(tags_json_buffer[0])
	runtime.SimpleAudioRuntime_FreeString(tags_json_buffer[0])

	local tags_ok, tags = pcall(cjson.decode, tags_json)

	if not tags_ok or type(tags) ~= "table" then
		return false, "Audio metadata is invalid"
	end

	local info = {
		sample_rate = tonumber(sample_rate_buffer[0]),
		channels = tonumber(channels_buffer[0]),
		bit_rate = tonumber(bit_rate_buffer[0]),
		tags = tags,
	}

	local duration = tonumber(duration_buffer[0])

	if duration >= 0 then
		info.duration = duration
	end

	return info
end

native.stop = function(play_id)
	local runtime = state.runtime

	if not runtime then
		return play_id == nil
	end

	if play_id == nil then
		runtime.SimpleAudioRuntime_StopAll()
		state.play_callbacks = {}
		state.play_options = {}
		state.update_callbacks = {}

		return true
	end

	local stopped = runtime.SimpleAudioRuntime_Stop(play_id) ~= 0

	if stopped then
		state.play_callbacks[play_id] = nil
		state.play_options[play_id] = nil
		state.update_callbacks[play_id] = nil
	end

	return stopped
end

native.set_position = function(play_id, spatial_volume, spatial_data)
	play_id = tonumber(play_id)

	local runtime = state.runtime
	local options = state.play_options[play_id]

	if not runtime or not options then
		return false
	end

	local volume_gain = (spatial_volume or 100) / 100 * options.base_volume_gain
	local buffer = error_buffer()
	local ok = runtime.SimpleAudioRuntime_SetPosition(
		play_id,
		volume_gain,
		spatial_data.source_x,
		spatial_data.source_y,
		spatial_data.source_z,
		spatial_data.listener_x,
		spatial_data.listener_y,
		spatial_data.listener_z,
		spatial_data.listener_front_x,
		spatial_data.listener_front_y,
		spatial_data.listener_front_z,
		spatial_data.listener_top_x,
		spatial_data.listener_top_y,
		spatial_data.listener_top_z,
		buffer,
		ERROR_BUFFER_SIZE
	)

	if ok == 0 then
		return false, buffer_string(buffer)
	end

	return true
end

native.is_playing = function(play_id)
	local runtime = state.runtime

	if not runtime or play_id == nil then
		return false
	end

	return runtime.SimpleAudioRuntime_IsPlaying(play_id) ~= 0
end

local function clear_playback_state(play_id)
	state.play_callbacks[play_id] = nil
	state.play_options[play_id] = nil
	state.update_callbacks[play_id] = nil
end

local function poll_events(runtime)
	while true do
		local result = runtime.SimpleAudioRuntime_PollEvent(event_type_buffer, event_play_id_buffer, event_message_buffer, ERROR_BUFFER_SIZE)

		if result == 0 then
			return true
		end
		if result < 0 then
			mod:error("Failed to poll SimpleAudio runtime event")

			return false
		end

		local id = tonumber(event_play_id_buffer[0])

		if event_type_buffer[0] == EVENT_FINISHED then
			local callback = state.play_callbacks[id]
			clear_playback_state(id)

			if callback then
				callback(id)
			end
		elseif event_type_buffer[0] == EVENT_ERROR then
			clear_playback_state(id)
			mod:error(buffer_string(event_message_buffer))
		end
	end
end

local function update_playbacks(dt)
	for id, callback in pairs(state.update_callbacks) do
		if state.update_callbacks[id] == callback and native.is_playing(id) then
			callback(id, dt)
		else
			clear_playback_state(id)
		end
	end
end

local function clear_all_playback_state()
	state.play_callbacks = {}
	state.play_options = {}
	state.update_callbacks = {}
end

local function update_initialization(runtime, dt)
	local status = tonumber(runtime.SimpleAudioRuntime_InitializationStatus())

	if status == STATUS_UNINITIALIZED and state.initialization_restart_pending then
		local started, start_error = start_runtime_initialization(runtime)

		if not started then
			state.initialization_restart_pending = false
			state.initialization_failure_reported = true
			mod:error(mod:localize("initialize_failed", start_error))

			return STATUS_FAILED
		end

		return STATUS_INITIALIZING
	elseif status == STATUS_INITIALIZING then
		state.initialization_elapsed = (state.initialization_elapsed or 0) + (dt or 0)

		if not state.initialization_slow_notified and state.initialization_elapsed >= INITIALIZATION_SLOW_NOTIFY_SECONDS then
			state.initialization_slow_notified = true

			local stage = initialization_stage(runtime)
			mod:notify(mod:localize("initialize_slow"))
			mod:info(string.format("SimpleAudio initialization is still running after %.1f seconds at stage: %s", state.initialization_elapsed, stage))
		end
	elseif status == STATUS_FAILED then
		if not state.initialization_failure_reported then
			state.initialization_failure_reported = true

			local error_message = mod:localize("initialize_failed", initialization_error(runtime))
			mod:error(error_message)
			clear_all_playback_state()
		end
	elseif status == STATUS_READY then
		state.initialization_elapsed = nil
	end

	return status
end

native.update = function(dt)
	local runtime = state.runtime

	if not runtime then
		return
	end

	if update_initialization(runtime, dt) ~= STATUS_READY then
		return
	end

	if not poll_events(runtime) then
		return
	end

	update_playbacks(dt)
end

native.shutdown = function()
	local runtime = state.runtime
	state.initialization_restart_pending = false

	if runtime then
		runtime.SimpleAudioRuntime_Shutdown()

		if tonumber(runtime.SimpleAudioRuntime_InitializationStatus()) == STATUS_UNINITIALIZED then
			state.runtime = nil
		end
	end

	clear_all_playback_state()
end

return native
