local mod = get_mod("Realms")
local Native = mod:io_dofile("Realms/scripts/mods/Realms/runtime/native")
local ffi = Mods.lua.ffi
local Binary = {}
local ERROR_CAPACITY = 1024
local error_buffer = ffi.new("char[?]", ERROR_CAPACITY)
local message_id = ffi.new("uint32_t[1]")
local failed_channel = ffi.new("uint32_t[1]")
local metadata = ffi.new("RealmsBinaryMessage")
local receive_capacity = 4096
local receive_buffer

local function runtime()
	error_buffer[0] = 0

	return Native.initialized_runtime()
end

function Binary.attach(channel_id, peer_id, role)
	local native, native_error = runtime()

	if not native then
		return false, native_error
	end
	if native.RealmsRuntime_AttachBinaryChannel(channel_id, peer_id, role == "host" and 1 or 0, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Binary.detach(channel_id)
	local native, native_error = runtime()

	if not native then
		return false, native_error
	end
	if native.RealmsRuntime_DetachBinaryChannel(channel_id, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Binary.send(channel_id, sender, recipient, message_type, payload, reliable, lifetime_ms)
	local native, native_error = runtime()

	if not native then
		return false, native_error
	end
	local result = native.RealmsRuntime_SendBinary(channel_id, sender, recipient, message_type,
		reliable and 1 or 0, payload, #payload, lifetime_ms, message_id, error_buffer, ERROR_CAPACITY)

	if result == 0 then
		return false, ffi.string(error_buffer)
	end

	return true, tonumber(message_id[0])
end

function Binary.update()
	local native, native_error = runtime()

	if not native then
		return false, native_error, 0
	end
	if native.RealmsRuntime_UpdateBinary(failed_channel, error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer), tonumber(failed_channel[0])
	end

	return true
end

function Binary.poll(control_channel, control_message_id)
	local native, native_error = runtime()

	if not native then
		return nil, native_error
	end

	metadata.struct_size = ffi.sizeof(metadata)
	local result = native.RealmsRuntime_PollBinary(control_channel or 0, control_message_id or 0, metadata, receive_buffer, receive_buffer and receive_capacity or 0,
		error_buffer, ERROR_CAPACITY)

	if result == -2 then
		receive_capacity = math.max(receive_capacity, tonumber(metadata.payload_size))
		receive_buffer = ffi.new("uint8_t[?]", receive_capacity)
		result = native.RealmsRuntime_PollBinary(control_channel or 0, control_message_id or 0, metadata, receive_buffer, receive_capacity, error_buffer, ERROR_CAPACITY)
	end
	if result < 0 then
		return nil, ffi.string(error_buffer)
	end
	if result == 0 then
		return false
	end

	return {
		channel_id = tonumber(metadata.channel_id),
		message_type = tonumber(metadata.message_type),
		message_id = tonumber(metadata.message_id),
		reliable = metadata.reliable ~= 0,
		sender = ffi.string(metadata.sender_peer_id),
		recipient = ffi.string(metadata.recipient_peer_id),
		payload = metadata.payload_size == 0 and "" or ffi.string(receive_buffer, metadata.payload_size),
	}
end

function Binary.stats(channel_id)
	local native, native_error = runtime()

	if not native then
		return nil, native_error
	end

	local stats = ffi.new("RealmsBinaryStats")
	stats.struct_size = ffi.sizeof(stats)

	if native.RealmsRuntime_BinaryStats(channel_id, stats, error_buffer, ERROR_CAPACITY) == 0 then
		return nil, ffi.string(error_buffer)
	end

	return {
		queued_messages = tonumber(stats.queued_messages),
		queued_bytes = tonumber(stats.queued_bytes),
		sent_messages = tonumber(stats.sent_messages),
		received_messages = tonumber(stats.received_messages),
		expired_messages = tonumber(stats.expired_messages),
	}
end

return Binary
