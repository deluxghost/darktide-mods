local mod = get_mod("Realms")
local SessionBootBase = require("scripts/multiplayer/session_boot_base")
local ConnectionHost = mod:io_dofile("Realms/scripts/mods/Realms/connection/connection_host")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local Native = mod:io_dofile("Realms/scripts/mods/Realms/runtime/native")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local STATES = table.enum("ready", "failed")
local BOOTSTRAP_LOBBY_ID = "0000000000000000"
local HostSessionBoot = class("RealmsHostSessionBoot", "SessionBootBase")

local function current_account_id()
	local backend = Managers.backend
	local account_id = backend and backend.account_id and backend:account_id()

	if type(account_id) ~= "string" or #account_id ~= 36 then
		return nil, "Official backend account ID is unavailable"
	end

	return account_id
end

local function current_peer_id()
	local peer_id = string.lower(tostring(Network.peer_id()))

	if #peer_id ~= 16 or string.match(peer_id, "^[0-9a-f]+$") == nil then
		return nil, "Network.peer_id returned an invalid local peer ID"
	end

	return peer_id
end

HostSessionBoot.init = function (self, event_object, options)
	HostSessionBoot.super.init(self, STATES, event_object)

	self._options = options

	local valid_password, password_error = SessionTicket.validate_password(options.password)

	if not valid_password then
		self:_fail(password_error)

		return
	end

	local account_id, account_error = current_account_id()

	if not account_id then
		self:_fail(account_error)

		return
	end

	local peer_id, peer_error = current_peer_id()

	if not peer_id then
		self:_fail(peer_error)

		return
	end

	self._engine_lobby = Network.join_lan_lobby(BOOTSTRAP_LOBBY_ID)

	if not self._engine_lobby then
		self:_fail("Network.join_lan_lobby did not create a local-session lobby")

		return
	end

	local local_port, start_error = Native.start_local_session(account_id, peer_id)

	if not local_port then
		self:_fail(start_error)

		return
	end

	local connection_manager = Managers.connection

	self._connection_host = ConnectionHost:new(
		connection_manager:network_event_delegate(),
		connection_manager:approve_channel_delegate(),
		self._engine_lobby,
		{
			accept_new_connections = options.accept_new_connections,
			local_port = local_port,
			max_members = options.max_members,
			mission_name = options.mission_name,
			network_hash = connection_manager.combined_hash,
			on_installed = options.on_installed,
			on_remote_connected = options.on_remote_connected,
			on_remote_disconnected = options.on_remote_disconnected,
			password = options.password,
			peer_id = peer_id,
			tick_rate = GameParameters.tick_rate,
		}
	)
	self._engine_lobby = nil
	self:_set_state(STATES.ready)

	mod:echo(mod:localize("host_listening", local_port))
end

HostSessionBoot._fail = function (self, reason)
	mod:error("Local-session boot failed: %s", tostring(reason))
	self:event_object():failed_to_boot(true, "game", DisconnectReason.HOST_BOOT_FAILED, tostring(reason))

	if self._engine_lobby then
		Network.leave_lan_lobby(self._engine_lobby)
		self._engine_lobby = nil
	end

	self:_set_state(STATES.failed)
end

HostSessionBoot.result = function (self)
	self:_update_crashify_properties("realms_listen_host")

	local connection_host = self._connection_host

	self._connection_host = nil

	return connection_host
end

HostSessionBoot.destroy = function (self)
	if self._connection_host then
		self._connection_host:delete()
		self._connection_host = nil
	elseif self._engine_lobby then
		Network.leave_lan_lobby(self._engine_lobby)
		self._engine_lobby = nil
	end

	self._options = nil
end

return HostSessionBoot
