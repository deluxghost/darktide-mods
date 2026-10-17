local mod = get_mod("Realms")
local Native = mod:io_dofile("Realms/scripts/mods/Realms/runtime/native")
local ffi = Mods.lua.ffi
local Voice = {}
local MAX_PACKET_SIZE = 960
local ERROR_CAPACITY = 1024
local error_buffer = ffi.new("char[?]", ERROR_CAPACITY)
local receive_buffer = ffi.new("uint8_t[?]", MAX_PACKET_SIZE)
local packet = ffi.new("RealmsVoicePacket")
local started = false
local capture_enabled = false
local transmitting = false
local failure
local device_state = mod:persistent_table("voice_devices")

local function integer(value, minimum, maximum)
	return type(value) == "number" and value % 1 == 0 and value >= minimum and value <= maximum
end

local function runtime()
	error_buffer[0] = 0

	return Native.load_runtime()
end

local function capture_device()
	local current = Managers.chat and Managers.chat._current_capture_device

	if not current then
		return nil, "Game capture devices are not ready"
	end
	if current.device == "Default System Device" then
		return nil
	end

	return current.device
end

function Voice.start(options)
	if type(options) ~= "table" or (options.frame_ms ~= 10 and options.frame_ms ~= 20)
		or not integer(options.bitrate, 6000, 510000) or not integer(options.device_period_ms, 5, 20)
		or type(options.echo_cancellation) ~= "boolean" or type(options.noise_suppression) ~= "boolean"
	then
		return false, "Voice configuration is invalid"
	end

	if device_state.playback_device_id == nil then
		return false, "Game playback device is not ready"
	end

	local native, load_error = runtime()

	if not native then
		return false, load_error
	end

	local config = ffi.new("RealmsVoiceConfig")
	config.struct_size = ffi.sizeof(config)
	config.frame_ms = options.frame_ms
	config.bitrate = options.bitrate
	config.device_period_ms = options.device_period_ms
	config.playback_device_id = device_state.playback_device_id
	config.echo_cancellation = options.echo_cancellation and 1 or 0
	config.noise_suppression = options.noise_suppression and 1 or 0

	if native.RealmsRuntime_StartVoice(config, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end
	started = true
	capture_enabled = false
	transmitting = false
	failure = nil
	if not Managers.chat._current_capture_device then
		-- Device enumeration is local and does not require a successful Vivox login.
		Vivox.get_capture_devices(Managers.chat._account_handle or "")
	end

	return true
end

function Voice.stop()
	if not started then
		return true
	end

	local native = Native.loaded_runtime()

	if native.RealmsRuntime_StopVoice(error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end
	started = false
	capture_enabled = false
	transmitting = false

	return true
end

function Voice.set_capture(enabled)
	if type(enabled) ~= "boolean" then
		return false, "Voice capture flag must be a boolean"
	end

	local device_id, device_error

	if enabled then
		device_id, device_error = capture_device()

		if device_error then
			return false, device_error
		end
		if device_id == "No Device" then
			return false, "Microphone is disabled in the game settings"
		end
	end

	local native, load_error = runtime()

	if not native then
		return false, load_error
	end
	if native.RealmsRuntime_SetVoiceCapture(enabled and 1 or 0, device_id, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end
	capture_enabled = enabled
	if not enabled then
		transmitting = false
	end

	return true
end

function Voice.is_capture_enabled()
	return capture_enabled
end

function Voice.is_transmitting()
	return transmitting
end

function Voice.set_transmission(enabled)
	if type(enabled) ~= "boolean" then
		return false, "Voice transmission flag must be a boolean"
	end

	local native, load_error = runtime()

	if not native then
		return false, load_error
	end
	if native.RealmsRuntime_SetVoiceTransmission(enabled and 1 or 0, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end
	transmitting = enabled

	return true
end

function Voice.capture_available()
	local device, device_error = capture_device()

	return not device_error and device ~= "No Device"
end

function Voice.set_processing(echo_cancellation, noise_suppression)
	if type(echo_cancellation) ~= "boolean" or type(noise_suppression) ~= "boolean" then
		return false, "Voice processing flags must be booleans"
	end

	local native, load_error = runtime()

	if not native then
		return false, load_error
	end
	if native.RealmsRuntime_SetVoiceProcessing(echo_cancellation and 1 or 0, noise_suppression and 1 or 0, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Voice.update()
	if failure then
		return false, failure
	end
	if not started then
		return true
	end

	if Native.loaded_runtime().RealmsRuntime_UpdateVoice(error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Voice.set_volume(volume)
	if type(volume) ~= "number" or volume ~= volume or volume < 0 or volume > 2 then
		return false, "Voice volume is invalid"
	end

	local native, load_error = runtime()

	if not native then
		return false, load_error
	end
	if native.RealmsRuntime_SetVoiceVolume(volume, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Voice.poll()
	local native, load_error = runtime()

	if not native then
		return nil, load_error
	end

	packet.struct_size = ffi.sizeof(packet)
	local result = native.RealmsRuntime_PollVoicePacket(packet, receive_buffer, MAX_PACKET_SIZE, error_buffer, ERROR_CAPACITY)

	if result < 0 then
		return nil, ffi.string(error_buffer)
	end
	if result == 0 then
		return false
	end

	return {
		sequence = tonumber(packet.sequence),
		age_ms = tonumber(packet.age_ms),
		speaking = packet.speaking ~= 0,
		stream = tonumber(packet.stream),
		payload = ffi.string(receive_buffer, packet.payload_size),
	}
end

local function valid_speaker(speaker_id)
	return integer(speaker_id, 1, 4294967295)
end

function Voice.submit(speaker_id, payload)
	if not valid_speaker(speaker_id) or type(payload) ~= "string" then
		return false, "Voice speaker ID or payload is invalid"
	end

	local native, load_error = runtime()

	if not native then
		return false, load_error
	end
	if native.RealmsRuntime_SubmitVoicePacket(speaker_id, payload, #payload, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Voice.remove_speaker(speaker_id)
	if not valid_speaker(speaker_id) then
		return false, "Voice speaker ID is invalid"
	end

	local native, load_error = runtime()

	if not native then
		return false, load_error
	end
	if native.RealmsRuntime_RemoveVoiceSpeaker(speaker_id, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Voice.stats()
	local native, load_error = runtime()

	if not native then
		return nil, load_error
	end

	local stats = ffi.new("RealmsVoiceStats")
	stats.struct_size = ffi.sizeof(stats)

	if native.RealmsRuntime_VoiceStats(stats, error_buffer, ERROR_CAPACITY) == 0 then
		return nil, ffi.string(error_buffer)
	end

	local result = {}

	for _, field in ipairs({
		"capture_enabled", "maximum_packet_bytes", "codec_lookahead_frames", "capture_pending_frames",
		"playback_pending_frames", "capture_device_buffer_us", "playback_device_buffer_us", "encoded_frames",
		"encoded_bytes", "decoded_frames", "expired_packets", "dropped_packets", "dropped_capture_frames",
		"dropped_playback_frames", "playback_underrun_frames", "encode_time_us", "maximum_encode_time_us",
		"decode_time_us", "maximum_decode_time_us",
		"echo_cancellation", "noise_suppression", "reference_enabled", "processed_frames",
		"processing_time_us", "maximum_processing_time_us", "dropped_reference_frames",
	}) do
		result[field] = tonumber(stats[field])
	end

	return result
end

local function refresh_device(setting_id)
	if setting_id == "capture_device" then
		local stats, stats_error = Voice.stats()

		if not stats then
			return false, stats_error
		end
		if stats.capture_enabled == 0 then
			return true
		end

		local stopped, stop_error = Voice.set_capture(false)

		if not stopped then
			return false, stop_error
		end
		if capture_device() == "No Device" then
			return true
		end

		local enabled, enable_error = Voice.set_capture(true)

		if not enabled then
			return false, enable_error
		end

		return true
	end

	local native = Native.loaded_runtime()

	if native.RealmsRuntime_SetVoicePlaybackDevice(device_state.playback_device_id, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

local function device_changed(setting_id)
	if not started then
		return
	end

	local ok, message = refresh_device(setting_id)

	if not ok then
		Voice.stop()
		failure = message
	end
end

mod:hook_require("scripts/settings/options/sound_settings", function (settings)
	if device_state.playback_device_id == nil then
		-- Audio settings are applied during boot, before mods load. Reuse that original snapshot.
		local entry = settings.settings_by_id.sound_device
		local option = entry.options[entry.get_function() + 1]
		device_state.playback_device_id = option and option.device_id or 0
	end
end)

mod:hook_safe(Wwise, "set_active_device", function (device_id)
	local previous = device_state.playback_device_id
	device_state.playback_device_id = device_id

	if previous ~= device_id then
		device_changed("sound_device")
	end
end)

mod:hook_safe(CLASS.ChatManager, "set_capture_device", function ()
	device_changed("capture_device")
end)

return Voice
