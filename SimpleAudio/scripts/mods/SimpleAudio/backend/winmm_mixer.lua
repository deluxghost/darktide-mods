local mod = get_mod("SimpleAudio")
local ffi = Mods.lua.ffi

local filesystem = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/filesystem")
local windows = mod:io_dofile("SimpleAudio/scripts/mods/SimpleAudio/windows")

local mixer = {}

local OUTPUT_CHANNELS = 2
local OUTPUT_SAMPLE_RATE = 48000
local BITS_PER_SAMPLE = 16
local BYTES_PER_SAMPLE = 2
local BYTES_PER_FRAME = OUTPUT_CHANNELS * BYTES_PER_SAMPLE
local BUFFER_FRAMES = 1024
local SAMPLES_PER_BUFFER = BUFFER_FRAMES * OUTPUT_CHANNELS
local BUFFER_BYTES = BUFFER_FRAMES * BYTES_PER_FRAME
local MIX_BUFFER_BYTES = SAMPLES_PER_BUFFER * ffi.sizeof("double")
local BUFFER_COUNT = 4
local INITIAL_QUEUE_COUNT = 2
local WAVE_FORMAT_PCM = 1
local CALLBACK_NULL = 0
local MMSYSERR_NOERROR = 0
local WHDR_PREPARED = 0x00000002
local WHDR_DONE = 0x00000001

local instances = mod:persistent_table("instances")
instances.simple_audio_mixer = instances.simple_audio_mixer or {}

local state = instances.simple_audio_mixer
state.buffers = state.buffers or {}
state.played_files = state.played_files or {}
state.play_id = state.play_id or 0
state.voices = state.voices or {}

if not pcall(ffi.typeof, "SimpleAudio_WAVEHDR") then
	ffi.cdef([[
		typedef void* SimpleAudio_HWAVEOUT;
		typedef unsigned short SimpleAudio_WORD;
		typedef unsigned int SimpleAudio_UINT;
		typedef unsigned long SimpleAudio_ULONG;
		typedef unsigned long long SimpleAudio_UINT_PTR;
		typedef unsigned long long SimpleAudio_DWORD_PTR;

		typedef struct {
			SimpleAudio_WORD wFormatTag;
			SimpleAudio_WORD nChannels;
			SimpleAudio_ULONG nSamplesPerSec;
			SimpleAudio_ULONG nAvgBytesPerSec;
			SimpleAudio_WORD nBlockAlign;
			SimpleAudio_WORD wBitsPerSample;
			SimpleAudio_WORD cbSize;
		} SimpleAudio_WAVEFORMATEX;

		typedef struct SimpleAudio_WAVEHDR {
			char* lpData;
			SimpleAudio_ULONG dwBufferLength;
			SimpleAudio_ULONG dwBytesRecorded;
			SimpleAudio_DWORD_PTR dwUser;
			SimpleAudio_ULONG dwFlags;
			SimpleAudio_ULONG dwLoops;
			struct SimpleAudio_WAVEHDR* lpNext;
			SimpleAudio_DWORD_PTR reserved;
		} SimpleAudio_WAVEHDR;

		SimpleAudio_UINT waveOutOpen(SimpleAudio_HWAVEOUT* phwo, SimpleAudio_UINT_PTR uDeviceID, const SimpleAudio_WAVEFORMATEX* pwfx, SimpleAudio_DWORD_PTR dwCallback, SimpleAudio_DWORD_PTR dwInstance, SimpleAudio_ULONG fdwOpen);
		SimpleAudio_UINT waveOutPrepareHeader(SimpleAudio_HWAVEOUT hwo, SimpleAudio_WAVEHDR* pwh, SimpleAudio_UINT cbwh);
		SimpleAudio_UINT waveOutWrite(SimpleAudio_HWAVEOUT hwo, SimpleAudio_WAVEHDR* pwh, SimpleAudio_UINT cbwh);
		SimpleAudio_UINT waveOutUnprepareHeader(SimpleAudio_HWAVEOUT hwo, SimpleAudio_WAVEHDR* pwh, SimpleAudio_UINT cbwh);
		SimpleAudio_UINT waveOutReset(SimpleAudio_HWAVEOUT hwo);
		SimpleAudio_UINT waveOutClose(SimpleAudio_HWAVEOUT hwo);
	]])
end

local WAVE_MAPPER = ffi.cast("SimpleAudio_UINT_PTR", 0xFFFFFFFF)

local function has_flag(flags, flag)
	return math.floor(flags / flag) % 2 == 1
end

local function clamp_sample(value)
	if value > 32767 then
		return 32767
	elseif value < -32768 then
		return -32768
	end

	if value >= 0 then
		return math.floor(value + 0.5)
	end

	return math.ceil(value - 0.5)
end

local function winmm_error(function_name, result)
	return string.format("%s failed: WinMM error %d", function_name, tonumber(result))
end

local function complete_tracked_playback(play_id)
	local played_file = state.played_files[play_id]

	if not played_file then
		return
	end

	state.played_files[play_id] = nil

	if type(played_file.on_finished) == "function" then
		played_file.on_finished()
	end
end

local function clear_buffer_completions(buffer, complete_playback)
	if not buffer.completed_voice_ids then
		return
	end

	if complete_playback then
		for i = 1, #buffer.completed_voice_ids do
			complete_tracked_playback(buffer.completed_voice_ids[i])
		end
	end

	buffer.completed_voice_ids = nil
end

local function unprepare_buffer(buffer, complete_playback)
	if not buffer.prepared then
		return true
	end

	local result = state.winmm.waveOutUnprepareHeader(state.handle[0], buffer.header, ffi.sizeof("SimpleAudio_WAVEHDR"))

	if result ~= MMSYSERR_NOERROR then
		mod:error(winmm_error("waveOutUnprepareHeader", result))

		return false
	end

	buffer.prepared = false
	buffer.queued = false
	clear_buffer_completions(buffer, complete_playback)

	return true
end

local function create_buffer()
	local sample_buffer = ffi.new("int16_t[?]", SAMPLES_PER_BUFFER)
	local mix_buffer = ffi.new("double[?]", SAMPLES_PER_BUFFER)
	local header = ffi.new("SimpleAudio_WAVEHDR[1]")

	header[0].lpData = ffi.cast("char*", sample_buffer)
	header[0].dwBufferLength = BUFFER_BYTES

	return {
		header = header,
		mix = mix_buffer,
		samples = sample_buffer,
		completed_voice_ids = nil,
		prepared = false,
		queued = false,
	}
end

local function initialize()
	if state.handle then
		return true
	end

	state.winmm = state.winmm or ffi.load("winmm")

	local format = ffi.new("SimpleAudio_WAVEFORMATEX[1]")
	format[0].wFormatTag = WAVE_FORMAT_PCM
	format[0].nChannels = OUTPUT_CHANNELS
	format[0].nSamplesPerSec = OUTPUT_SAMPLE_RATE
	format[0].nAvgBytesPerSec = OUTPUT_SAMPLE_RATE * BYTES_PER_FRAME
	format[0].nBlockAlign = BYTES_PER_FRAME
	format[0].wBitsPerSample = BITS_PER_SAMPLE
	format[0].cbSize = 0

	local handle = ffi.new("SimpleAudio_HWAVEOUT[1]")
	local result = state.winmm.waveOutOpen(handle, WAVE_MAPPER, format, 0, 0, CALLBACK_NULL)

	if result ~= MMSYSERR_NOERROR then
		return false, winmm_error("waveOutOpen", result)
	end

	state.handle = handle
	state.buffers = {}
	state.voices = {}

	for i = 1, BUFFER_COUNT do
		state.buffers[i] = create_buffer()
	end

	return true
end

local function active_voice_count()
	local count = 0

	for _ in pairs(state.voices) do
		count = count + 1
	end

	return count
end

local function active_voice_ids()
	local voice_ids = {}

	for voice_id in pairs(state.voices) do
		voice_ids[#voice_ids + 1] = voice_id
	end

	return voice_ids
end

local function prepared_buffer_count()
	local count = 0

	for i = 1, #state.buffers do
		if state.buffers[i].queued then
			count = count + 1
		end
	end

	return count
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

local function close_voice(voice)
	if voice and voice.handle then
		filesystem.close(voice.handle)
		voice.handle = nil
	end
end

local function remove_voice(voice_id)
	local voice = state.voices[voice_id]

	if not voice then
		return
	end

	close_voice(voice)
	state.voices[voice_id] = nil
end

local function remove_all_voices()
	local voice_ids = active_voice_ids()

	for i = 1, #voice_ids do
		remove_voice(voice_ids[i])
	end
end

local function seek_voice(voice, frame)
	filesystem.seek(voice.handle, frame * BYTES_PER_FRAME)
	voice.cursor = frame
end

local function playback_seconds(value, field_name)
	if value == nil or value == false then
		return nil
	end

	local seconds = tonumber(value)

	if not seconds then
		return nil, string.format("playback_settings.%s must be numeric seconds, got %s", field_name, tostring(value))
	end

	return seconds
end

local function playback_range(source, options)
	local start_frame = 0
	local end_frame = source.frame_count
	local position, position_error = playback_seconds(options.pos, "pos")

	if position_error then
		return nil, nil, position_error
	end

	if position then
		start_frame = math.clamp(math.floor(position * OUTPUT_SAMPLE_RATE), 0, source.frame_count)
	end

	local duration, duration_error = playback_seconds(options.duration, "duration")

	if duration_error then
		return nil, nil, duration_error
	end

	if duration then
		end_frame = math.min(start_frame + math.max(math.floor(duration * OUTPUT_SAMPLE_RATE), 0), source.frame_count)
	end

	return start_frame, end_frame
end

local function voice_has_sample(voice)
	while voice.cursor >= voice.end_frame do
		if voice.remaining_loops == 0 then
			return false
		end
		if voice.remaining_loops > 0 then
			voice.remaining_loops = voice.remaining_loops - 1
		end

		seek_voice(voice, voice.start_frame)
	end

	return true
end

local function add_completed_voice(buffer, voice_id)
	buffer.completed_voice_ids = buffer.completed_voice_ids or {}
	buffer.completed_voice_ids[#buffer.completed_voice_ids + 1] = voice_id
end

local function mix_voice_chunk(buffer, voice, output_frame_offset, frames)
	local byte_count = frames * BYTES_PER_FRAME
	local bytes_read = filesystem.read(voice.handle, voice.scratch, byte_count)

	if bytes_read % BYTES_PER_FRAME ~= 0 then
		error(string.format("Audio cache read returned a partial frame: %d bytes", bytes_read))
	end

	local frames_read = bytes_read / BYTES_PER_FRAME

	for frame = 0, frames_read - 1 do
		local source_index = frame * OUTPUT_CHANNELS
		local output_index = (output_frame_offset + frame) * OUTPUT_CHANNELS

		buffer.mix[output_index] = buffer.mix[output_index] + tonumber(voice.scratch[source_index]) * voice.left_gain
		buffer.mix[output_index + 1] = buffer.mix[output_index + 1] + tonumber(voice.scratch[source_index + 1]) * voice.right_gain
	end

	voice.cursor = voice.cursor + frames_read

	return frames_read
end

local function mix_voice(buffer, voice_id, voice)
	local output_frame_offset = 0

	while output_frame_offset < BUFFER_FRAMES do
		if not voice_has_sample(voice) then
			add_completed_voice(buffer, voice_id)
			remove_voice(voice_id)

			return
		end

		local frames_available = voice.end_frame - voice.cursor
		local frames_to_read = math.min(BUFFER_FRAMES - output_frame_offset, frames_available)

		if frames_to_read <= 0 then
			voice.cursor = voice.end_frame
		else
			local frames_read = mix_voice_chunk(buffer, voice, output_frame_offset, frames_to_read)

			if frames_read == 0 then
				voice.cursor = voice.end_frame
			end
			if frames_read < frames_to_read then
				voice.cursor = voice.end_frame
			end

			output_frame_offset = output_frame_offset + frames_read
		end
	end
end

local function write_output_samples(buffer)
	for i = 0, SAMPLES_PER_BUFFER - 1 do
		buffer.samples[i] = clamp_sample(buffer.mix[i])
	end
end

local function fill_buffer(buffer)
	ffi.fill(buffer.mix, MIX_BUFFER_BYTES)
	buffer.completed_voice_ids = nil

	local voice_ids = active_voice_ids()

	for i = 1, #voice_ids do
		local voice_id = voice_ids[i]
		local voice = state.voices[voice_id]

		if voice then
			mix_voice(buffer, voice_id, voice)
		end
	end

	write_output_samples(buffer)
end

local function queue_buffer(buffer)
	fill_buffer(buffer)

	local result = state.winmm.waveOutPrepareHeader(state.handle[0], buffer.header, ffi.sizeof("SimpleAudio_WAVEHDR"))

	if result ~= MMSYSERR_NOERROR then
		return false, winmm_error("waveOutPrepareHeader", result)
	end

	buffer.prepared = true
	result = state.winmm.waveOutWrite(state.handle[0], buffer.header, ffi.sizeof("SimpleAudio_WAVEHDR"))

	if result ~= MMSYSERR_NOERROR then
		unprepare_buffer(buffer, false)

		return false, winmm_error("waveOutWrite", result)
	end

	buffer.queued = true

	return true
end

local function reclaim_finished_buffers()
	for i = 1, #state.buffers do
		local buffer = state.buffers[i]

		if buffer.queued and has_flag(tonumber(buffer.header[0].dwFlags), WHDR_DONE) then
			unprepare_buffer(buffer, true)
		end
	end
end

local function queue_available_buffers(target_count)
	local active_count = active_voice_count()

	if active_count == 0 then
		return true
	end

	local queued_count = prepared_buffer_count()

	for i = 1, #state.buffers do
		if queued_count >= target_count then
			break
		end

		local buffer = state.buffers[i]

		if not buffer.queued then
			local ok, error_message = queue_buffer(buffer)

			if not ok then
				return false, error_message
			end

			queued_count = queued_count + 1

			if active_voice_count() == 0 then
				break
			end
		end
	end

	return true
end

mixer.play = function(source, options)
	local ok, error_message = initialize()

	if not ok then
		return false, error_message
	end

	local start_frame, end_frame, range_error = playback_range(source, options)

	if not start_frame then
		return false, range_error
	end

	if start_frame >= end_frame then
		return false, "Playback range is empty"
	end

	local handle = filesystem.open_read(source.pcm_path)

	state.play_id = state.play_id + 1

	state.voices[state.play_id] = {
		cursor = start_frame,
		end_frame = end_frame,
		handle = handle,
		left_gain = (options.volume_gain or 1) * (options.left_gain or 1),
		remaining_loops = normalize_loop_count(options.loop),
		right_gain = (options.volume_gain or 1) * (options.right_gain or 1),
		scratch = ffi.new("int16_t[?]", SAMPLES_PER_BUFFER),
		start_frame = start_frame,
	}
	state.played_files[state.play_id] = {
		on_finished = options.on_finished,
	}

	seek_voice(state.voices[state.play_id], start_frame)

	reclaim_finished_buffers()

	local queued, queue_error = queue_available_buffers(INITIAL_QUEUE_COUNT)

	if not queued then
		remove_voice(state.play_id)
		state.played_files[state.play_id] = nil

		return false, queue_error
	end

	return state.play_id
end

mixer.stop = function(play_id)
	if play_id == nil then
		remove_all_voices()
		state.played_files = {}

		if state.handle then
			local result = state.winmm.waveOutReset(state.handle[0])

			if result ~= MMSYSERR_NOERROR then
				mod:error(winmm_error("waveOutReset", result))
			end

			for i = 1, #state.buffers do
				unprepare_buffer(state.buffers[i], false)
			end
		end

		return true
	end

	if not state.voices[play_id] and not state.played_files[play_id] then
		return false
	end

	remove_voice(play_id)
	state.played_files[play_id] = nil

	return true
end

mixer.is_playing = function(play_id)
	return play_id ~= nil and state.played_files[play_id] ~= nil
end

mixer.update = function()
	if not state.handle then
		return
	end

	reclaim_finished_buffers()

	local queued, error_message = queue_available_buffers(BUFFER_COUNT)

	if not queued then
		mod:error(error_message)
		mixer.stop()
	end
end

mixer.shutdown = function()
	if not state.handle then
		return
	end

	remove_all_voices()
	state.played_files = {}

	local result = state.winmm.waveOutReset(state.handle[0])

	if result ~= MMSYSERR_NOERROR then
		mod:error(winmm_error("waveOutReset", result))
	end

	for i = 1, #state.buffers do
		unprepare_buffer(state.buffers[i], false)
	end

	result = state.winmm.waveOutClose(state.handle[0])

	if result ~= MMSYSERR_NOERROR then
		mod:error(winmm_error("waveOutClose", result))
	end

	state.handle = nil
	state.buffers = {}
end

return mixer
