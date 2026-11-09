local mod = get_mod("Realms")
local ffi = Mods.lua.ffi
local Native = mod:io_dofile("Realms/scripts/mods/Realms/runtime/native")
local Steam = {}
Steam.EVENT_TYPES = {
	join_requested = 1,
	client_ready = 2,
	password_required = 3,
	client_error = 4,
	host_error = 5,
	presence_updated = 6,
}
local ERROR_CAPACITY = 1024

if not pcall(ffi.typeof, "RealmsSteam_CDEF") then
	ffi.cdef([[
		typedef struct RealmsSteamEvent {
			uint32_t struct_size;
			uint32_t type;
			int32_t code;
			uint32_t local_port;
			char steam_id[21];
			char message[256];
		} RealmsSteamEvent;
		typedef struct RealmsSteamStatus {
			uint32_t struct_size;
			int32_t authentication;
			int32_t relay;
			uint32_t listening;
			uint32_t connections;
			uint32_t client_port;
			uint64_t sent_bytes;
			uint64_t received_bytes;
			int32_t client_state;
			uint64_t dropped_datagrams;
		} RealmsSteamStatus;
		int RealmsRuntime_SteamInitialize(char *steam_id, int capacity, char *error, int error_capacity);
		int RealmsRuntime_SteamStartHost(int password_required, char *error, int error_capacity);
		void RealmsRuntime_SteamStopHost(void);
		void RealmsRuntime_SteamSetPasswordRequired(int required);
		int RealmsRuntime_SteamConnect(const char *steam_id, const char *game_peer_id, int password_supplied, char *error, int error_capacity);
		void RealmsRuntime_SteamDisconnect(void);
		int RealmsRuntime_SteamPollEvent(RealmsSteamEvent *event, char *error, int error_capacity);
		int RealmsRuntime_SteamStatus(RealmsSteamStatus *status, char *error, int error_capacity);
		void RealmsRuntime_SteamUpdate(void);
		int RealmsRuntime_SteamPublishTarget(const char *host_steam_id, char *error, int error_capacity);
		int RealmsRuntime_SteamFriendTarget(const char *steam_id, char *host_steam_id, int capacity, char *error, int error_capacity);
		int RealmsRuntime_SteamInvite(const char *steam_id, const char *host_steam_id, char *error, int error_capacity);
		void RealmsRuntime_SteamShutdown(void);
		typedef struct { int unused; } RealmsSteam_CDEF;
	]])
end

local error_buffer = ffi.new("char[?]", ERROR_CAPACITY)
local id_buffer = ffi.new("char[21]")
local event_buffer = ffi.new("RealmsSteamEvent")

local function runtime()
	return assert(Native.loaded_runtime(), "Steam runtime has not been loaded")
end

local function command(name, ...)
	local arguments = {...}

	arguments[#arguments + 1] = error_buffer
	arguments[#arguments + 1] = ERROR_CAPACITY

	local result = runtime()[name](unpack(arguments))

	if result == 0 then
		return false, ffi.string(error_buffer)
	end

	return true
end

function Steam.initialize()
	local library, load_error = Native.load_runtime()

	if not library then
		return nil, load_error
	end
	if library.RealmsRuntime_SteamInitialize(id_buffer, 21, error_buffer, ERROR_CAPACITY) == 0 then
		return nil, ffi.string(error_buffer)
	end

	return ffi.string(id_buffer)
end

function Steam.start_host(password_required)
	return command("RealmsRuntime_SteamStartHost", password_required and 1 or 0)
end

function Steam.stop_host()
	runtime().RealmsRuntime_SteamStopHost()
end

function Steam.password_changed(required)
	runtime().RealmsRuntime_SteamSetPasswordRequired(required and 1 or 0)
end

function Steam.connect(steam_id, password_submitted)
	return command("RealmsRuntime_SteamConnect", steam_id, string.lower(tostring(Network.peer_id())), password_submitted and 1 or 0)
end

function Steam.disconnect()
	if Native.loaded_runtime() then
		runtime().RealmsRuntime_SteamDisconnect()
	end
end

function Steam.publish_target(steam_id)
	return command("RealmsRuntime_SteamPublishTarget", steam_id or "")
end

function Steam.friend_target(steam_id)
	local result = runtime().RealmsRuntime_SteamFriendTarget(steam_id, id_buffer, 21, error_buffer, ERROR_CAPACITY)

	if result < 0 then
		return nil, ffi.string(error_buffer)
	end

	return result == 1 and ffi.string(id_buffer) or nil
end

function Steam.invite(steam_id, host_steam_id)
	return command("RealmsRuntime_SteamInvite", steam_id, host_steam_id)
end

function Steam.poll_event()
	event_buffer.struct_size = ffi.sizeof(event_buffer)

	local result = runtime().RealmsRuntime_SteamPollEvent(event_buffer, error_buffer, ERROR_CAPACITY)

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
		steam_id = ffi.string(event_buffer.steam_id),
		message = ffi.string(event_buffer.message),
	}
end

function Steam.shutdown()
	if Native.loaded_runtime() then
		runtime().RealmsRuntime_SteamShutdown()
	end
end

function Steam.status()
	local status = ffi.new("RealmsSteamStatus")

	status.struct_size = ffi.sizeof(status)

	local success, status_error = command("RealmsRuntime_SteamStatus", status)

	if not success then
		return nil, status_error
	end

	return {
		authentication = tonumber(status.authentication),
		relay = tonumber(status.relay),
		listening = status.listening ~= 0,
		connections = tonumber(status.connections),
		client_port = tonumber(status.client_port),
		client_state = tonumber(status.client_state),
		dropped_datagrams = tonumber(status.dropped_datagrams),
		sent_bytes = tonumber(status.sent_bytes),
		received_bytes = tonumber(status.received_bytes),
	}
end

function Steam.update()
	runtime().RealmsRuntime_SteamUpdate()
end

return Steam
