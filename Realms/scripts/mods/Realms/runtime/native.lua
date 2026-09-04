local mod = get_mod("Realms")
local ffi = Mods.lua.ffi

mod:io_dofile("Realms/scripts/mods/Realms/runtime/cdef")

local Native = {}

local RUNTIME_PATH = "../mods/Realms/bin/darktide-realms.dll"
local ERROR_CAPACITY = 1024
local EVENT_TYPES = {
	error = 1,
	peer_discovered = 2,
	peer_joined = 3,
	peer_rejected = 4,
}
local ERROR_CODES = {
	relay_fatal = 1010,
}
local START_ERROR_CODES = {
	listen_port_unavailable = 1,
}
local instances = mod:persistent_table("instances")

instances.native = instances.native or {}

local state = instances.native
local poll_error_buffer
local poll_event

local function new_error_buffer()
	return ffi.new("char[?]", ERROR_CAPACITY)
end

local function read_error(buffer)
	local message = ffi.string(buffer)

	return message ~= "" and message or "Realms native runtime returned an unspecified error"
end

local function load_runtime()
	if state.runtime then
		return state.runtime
	end

	local loaded, runtime = pcall(ffi.load, RUNTIME_PATH)

	if not loaded then
		return nil, tostring(runtime)
	end

	state.runtime = runtime

	return runtime
end

function Native.initialize()
	if state.initialized then
		return true
	end

	local runtime, load_error = load_runtime()

	if not runtime then
		return false, load_error
	end

	local error_buffer = new_error_buffer()

	if runtime.RealmsRuntime_Initialize(error_buffer, ERROR_CAPACITY) == 0 then
		return false, read_error(error_buffer)
	end

	state.initialized = true

	return true
end

local function initialized_runtime()
	local initialized, initialize_error = Native.initialize()

	if not initialized then
		return nil, initialize_error
	end

	return state.runtime
end

function Native.resolve_addresses(address)
	local runtime, runtime_error = load_runtime()

	if not runtime then
		return nil, runtime_error
	end

	local resolved = ffi.new("RealmsResolvedAddresses")
	local error_buffer = new_error_buffer()

	resolved.struct_size = ffi.sizeof(resolved)

	if runtime.RealmsRuntime_ResolveAddresses(address, resolved, error_buffer, ERROR_CAPACITY) == 0 then
		return nil, read_error(error_buffer)
	end

	local addresses = {}

	for i = 0, tonumber(resolved.count) - 1 do
		addresses[#addresses + 1] = ffi.string(resolved.addresses[i])
	end

	return addresses
end

function Native.set_client_ipv6_member_address_support(enabled)
	local runtime, runtime_error = initialized_runtime()

	if not runtime then
		return false, runtime_error
	end

	local error_buffer = new_error_buffer()

	if runtime.RealmsRuntime_SetClientIpv6MemberAddressSupport(enabled and 1 or 0, error_buffer, ERROR_CAPACITY) == 0 then
		return false, read_error(error_buffer)
	end

	return true
end

function Native.start_local_session(account_id, peer_id, listen_port)
	local runtime, runtime_error = initialized_runtime()

	if not runtime then
		return nil, runtime_error
	end

	local requested_listen_port = listen_port == "" and 0 or tonumber(listen_port)

	if not requested_listen_port
		or requested_listen_port % 1 ~= 0
		or requested_listen_port < 0
		or requested_listen_port > 65535
	then
		return nil, "Listen UDP port is invalid"
	end

	local port = ffi.new("int[1]")
	local start_error_code = ffi.new("int[1]")
	local error_buffer = new_error_buffer()
	local result = runtime.RealmsRuntime_StartLocalSession(
		account_id,
		peer_id,
		requested_listen_port,
		port,
		start_error_code,
		error_buffer,
		ERROR_CAPACITY
	)

	if result == 0 then
		return nil, read_error(error_buffer), tonumber(start_error_code[0])
	end

	return tonumber(port[0])
end

function Native.is_peer_connected(peer_id)
	local runtime, runtime_error = initialized_runtime()

	if not runtime then
		return nil, runtime_error
	end

	local connected = ffi.new("int[1]")
	local error_buffer = new_error_buffer()

	if runtime.RealmsRuntime_IsPeerConnected(peer_id, connected, error_buffer, ERROR_CAPACITY) == 0 then
		return nil, read_error(error_buffer)
	end

	return connected[0] ~= 0
end

function Native.release_peer_transport_state(peer_id)
	local runtime, runtime_error = initialized_runtime()

	if not runtime then
		return false, runtime_error
	end

	local error_buffer = new_error_buffer()

	if runtime.RealmsRuntime_ReleasePeerTransportState(peer_id, error_buffer, ERROR_CAPACITY) == 0 then
		return false, read_error(error_buffer)
	end

	return true
end

function Native.adopt_peer_transport_state(peer_id)
	local runtime, runtime_error = initialized_runtime()

	if not runtime then
		return false, runtime_error
	end

	local error_buffer = new_error_buffer()

	if runtime.RealmsRuntime_AdoptPeerTransportState(peer_id, error_buffer, ERROR_CAPACITY) == 0 then
		return false, read_error(error_buffer)
	end

	return true
end

function Native.reap_abandoned_peer_transport_state(idle_timeout_ms)
	local runtime, runtime_error = initialized_runtime()

	if not runtime then
		return nil, runtime_error
	end

	local reaped_count = ffi.new("int[1]")
	local error_buffer = new_error_buffer()

	if runtime.RealmsRuntime_ReapAbandonedPeerTransportState(idle_timeout_ms, reaped_count, error_buffer, ERROR_CAPACITY) == 0 then
		return nil, read_error(error_buffer)
	end

	return tonumber(reaped_count[0])
end

function Native.poll_event()
	local runtime, runtime_error = initialized_runtime()

	if not runtime then
		return nil, runtime_error
	end

	poll_event = poll_event or ffi.new("RealmsRuntimeEvent")
	poll_error_buffer = poll_error_buffer or new_error_buffer()
	poll_error_buffer[0] = 0

	poll_event.struct_size = ffi.sizeof(poll_event)

	local result = runtime.RealmsRuntime_PollEvent(poll_event, poll_error_buffer, ERROR_CAPACITY)

	if result < 0 then
		return nil, read_error(poll_error_buffer)
	end
	if result == 0 then
		return false
	end

	return {
		channel_id = tonumber(poll_event.channel_id),
		code = tonumber(poll_event.code),
		message = ffi.string(poll_event.message),
		peer_id = ffi.string(poll_event.peer_id),
		type = tonumber(poll_event.type),
	}
end

function Native.close_local_session()
	local runtime, runtime_error = initialized_runtime()

	if not runtime then
		return false, runtime_error
	end

	local error_buffer = new_error_buffer()

	if runtime.RealmsRuntime_CloseLocalSession(error_buffer, ERROR_CAPACITY) == 0 then
		return false, read_error(error_buffer)
	end

	return true
end

Native.EVENT_TYPES = EVENT_TYPES
Native.ERROR_CODES = ERROR_CODES
Native.START_ERROR_CODES = START_ERROR_CODES

return Native
