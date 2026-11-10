local mod = get_mod("Realms")
local ffi = Mods.lua.ffi
local Native = mod:io_dofile("Realms/scripts/mods/Realms/runtime/native")
local Eos = {}
Eos.STATES = {
	stopped = 0,
	starting = 1,
	logging_in = 2,
	ready = 3,
	failed = 4,
}
Eos.EVENT_TYPES = {
	client_ready = 2,
	password_required = 3,
	client_error = 4,
	host_error = 5,
	login_succeeded = 16,
	login_failed = 17,
	host_code = 18,
	host_code_failed = 19,
	code_resolved = 20,
	code_failed = 21,
	log = 22,
}
Eos.CODE_ERRORS = {
	not_found = 1,
}
Eos.CODE_LENGTH = 6
Eos.CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local ERROR_CAPACITY = 1024

if not pcall(ffi.typeof, "RealmsEos_CDEF") then
	ffi.cdef([[
		typedef struct RealmsEosEvent {
			uint32_t struct_size;
			uint32_t type;
			int32_t code;
			uint32_t local_port;
			char remote[33];
			char text[64];
			char message[256];
		} RealmsEosEvent;
		typedef struct RealmsEosStatus {
			uint32_t struct_size;
			uint32_t state;
			int32_t last_result;
			int32_t nat_type;
			uint32_t hosting;
			uint32_t connections;
			uint32_t client_port;
			int32_t client_network_type;
			uint64_t sent_bytes;
			uint64_t received_bytes;
			uint64_t dropped_datagrams;
			uint64_t fragmented_datagrams;
		} RealmsEosStatus;
		int RealmsRuntime_EosAvailable(char *error, int error_capacity);
		int RealmsRuntime_EosStart(const char *display_name, char *error, int error_capacity);
		void RealmsRuntime_EosStop(int exiting);
		int RealmsRuntime_EosStartHost(int password_required, char *error, int error_capacity);
		void RealmsRuntime_EosStopHost(void);
		void RealmsRuntime_EosSetInvitesOpen(int open);
		void RealmsRuntime_EosSetPasswordRequired(int required);
		int RealmsRuntime_EosResolveCode(const char *code, char *error, int error_capacity);
		int RealmsRuntime_EosConnect(const char *remote_id, const char *game_peer_id, int password_supplied, char *error, int error_capacity);
		void RealmsRuntime_EosDisconnect(void);
		int RealmsRuntime_EosPollEvent(RealmsEosEvent *event, char *error, int error_capacity);
		int RealmsRuntime_EosStatus(RealmsEosStatus *status, char *error, int error_capacity);
		typedef struct { int unused; } RealmsEos_CDEF;
	]])
end

local error_buffer = ffi.new("char[?]", ERROR_CAPACITY)
local event_buffer = ffi.new("RealmsEosEvent")
-- Reused because status is read every frame while a disabled host still has EOS players.
local status = ffi.new("RealmsEosStatus")

local function runtime()
	return assert(Native.loaded_runtime(), "EOS runtime has not been loaded")
end

local function command(name, ...)
	local arguments = {...}

	arguments[#arguments + 1] = error_buffer
	arguments[#arguments + 1] = ERROR_CAPACITY

	if runtime()[name](unpack(arguments)) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

-- Returns the canonical code for user input in any case and with surrounding whitespace.
function Eos.normalize_code(value)
	if type(value) ~= "string" then
		return nil
	end

	local code = string.upper(string.gsub(value, "%s", ""))

	if #code ~= Eos.CODE_LENGTH or string.find(code, "[^" .. Eos.CODE_ALPHABET .. "]") then
		return nil
	end

	return code
end

function Eos.available()
	local library, load_error = Native.load_runtime()

	if not library then
		return false, load_error
	end
	if library.RealmsRuntime_EosAvailable(error_buffer, ERROR_CAPACITY) == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Eos.start(display_name)
	return command("RealmsRuntime_EosStart", display_name or "")
end

function Eos.stop(exiting)
	if Native.loaded_runtime() then
		runtime().RealmsRuntime_EosStop(exiting and 1 or 0)
	end
end

function Eos.start_host(password_required)
	return command("RealmsRuntime_EosStartHost", password_required and 1 or 0)
end

function Eos.stop_host()
	runtime().RealmsRuntime_EosStopHost()
end

function Eos.set_invites_open(open)
	runtime().RealmsRuntime_EosSetInvitesOpen(open and 1 or 0)
end

function Eos.password_changed(required)
	runtime().RealmsRuntime_EosSetPasswordRequired(required and 1 or 0)
end

function Eos.resolve_code(code)
	return command("RealmsRuntime_EosResolveCode", code)
end

function Eos.connect(remote_id, password_submitted)
	return command("RealmsRuntime_EosConnect", remote_id, string.lower(tostring(Network.peer_id())), password_submitted and 1 or 0)
end

function Eos.disconnect()
	if Native.loaded_runtime() then
		runtime().RealmsRuntime_EosDisconnect()
	end
end

function Eos.poll_event()
	event_buffer.struct_size = ffi.sizeof(event_buffer)

	local result = runtime().RealmsRuntime_EosPollEvent(event_buffer, error_buffer, ERROR_CAPACITY)

	if result < 0 then
		return nil, ffi.string(error_buffer)
	end
	if result == 0 then
		return nil
	end

	return {
		type = tonumber(event_buffer.type),
		code = tonumber(event_buffer.code),
		port = tonumber(event_buffer.local_port),
		remote = ffi.string(event_buffer.remote),
		text = ffi.string(event_buffer.text),
		message = ffi.string(event_buffer.message),
	}
end

-- Number of open EOS bridge connections, or 0 when the status cannot be read.
function Eos.connection_count()
	status.struct_size = ffi.sizeof(status)

	return runtime().RealmsRuntime_EosStatus(status, error_buffer, ERROR_CAPACITY) ~= 0 and tonumber(status.connections) or 0
end

function Eos.status()
	status.struct_size = ffi.sizeof(status)

	local success, status_error = command("RealmsRuntime_EosStatus", status)

	if not success then
		return nil, status_error
	end

	return {
		state = tonumber(status.state),
		last_result = tonumber(status.last_result),
		nat_type = tonumber(status.nat_type),
		hosting = status.hosting ~= 0,
		connections = tonumber(status.connections),
		client_port = tonumber(status.client_port),
		client_network_type = tonumber(status.client_network_type),
		sent_bytes = tonumber(status.sent_bytes),
		received_bytes = tonumber(status.received_bytes),
		dropped_datagrams = tonumber(status.dropped_datagrams),
		fragmented_datagrams = tonumber(status.fragmented_datagrams),
	}
end

return Eos
