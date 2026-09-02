local mod = get_mod("Realms")
local ConnectionClient = require("scripts/multiplayer/connection/connection_client")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local SessionBootBase = require("scripts/multiplayer/session_boot_base")
local ClientSnapshot = mod:io_dofile("Realms/scripts/mods/Realms/protocol/client_snapshot")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local HOST_TYPES = MatchmakingConstants.HOST_TYPES
local STATES = table.enum("handshake", "searching", "joining", "validating", "ready", "failed")
local ADDRESS_TIMEOUT_SECONDS = 8
local JOIN_TIMEOUT_SECONDS = 20
local VALIDATION_TIMEOUT_SECONDS = 20
local ClientSessionBoot = class("RealmsClientSessionBoot", "SessionBootBase")

ClientSessionBoot.init = function (self, event_object, options)
	ClientSessionBoot.super.init(self, STATES, event_object)

	self._options = options
	self._address_index = 1
	self._address_failures = {}
	self._buffered_connection_events = {}
	self._admission_accepted = false
	self._elapsed = 0
	self._mechanism_context = nil
	self._wan_client = Managers.connection:client()
	event_object._realms_protocol = SessionTicket.PROTOCOL_VERSION

	if not self._wan_client then
		self:_fail("ConnectionManager client is unavailable")

		return
	end

	self._browser = LanClient.create_lobby_browser(self._wan_client)
	self:_set_state(STATES.handshake)
end

ClientSessionBoot._current_address = function (self)
	return self._options.server_addresses[self._address_index]
end

ClientSessionBoot._reset_browser = function (self)
	if self._browser then
		LanClient.destroy_lobby_browser(self._wan_client, self._browser)
	end

	self._browser = LanClient.create_lobby_browser(self._wan_client)
end

ClientSessionBoot._try_next_address = function (self, reason)
	local address = self:_current_address()

	self._address_failures[#self._address_failures + 1] = string.format("%s: %s", address, reason)

	if self._connection_client then
		self._connection_client:delete()
		self._connection_client = nil
	elseif self._engine_lobby then
		Network.leave_lan_lobby(self._engine_lobby)
		self._engine_lobby = nil
	end

	table.clear(self._buffered_connection_events)

	self._admission_accepted = false
	self._mechanism_context = nil
	self._address_index = self._address_index + 1

	if not self:_current_address() then
		self:_fail("All resolved server addresses failed (" .. table.concat(self._address_failures, "; ") .. ")")

		return false
	end

	self:_reset_browser()
	self._elapsed = 0
	self:_set_state(STATES.handshake)
	mod:info("Trying resolved server address %s", self:_current_address())

	return true
end

ClientSessionBoot._fail = function (self, reason, disconnect_reason)
	if self:state() == STATES.failed then
		return
	end

	disconnect_reason = disconnect_reason or DisconnectReason.CONNECTION_FAILED

	mod:info("Client boot failed: %s", tostring(reason))
	self:event_object():failed_to_boot(true, "game", disconnect_reason, tostring(reason))

	if self._options.on_failed then
		self._options.on_failed()
	end

	self:_set_state(STATES.failed)
end

ClientSessionBoot._find_host_lobby = function (self)
	return self._browser:num_lobbies() > 0 and self._browser:lobby(1) or nil
end

ClientSessionBoot._create_connection = function (self)
	local snapshot, snapshot_error = ClientSnapshot.capture()

	if not snapshot then
		self:_fail(snapshot_error)

		return
	end

	local options = self._options
	local ticket, ticket_error = SessionTicket.create(options.host_peer_id, options.password, snapshot)

	if not ticket then
		self:_fail(ticket_error)

		return
	end

	self._connection_client = ConnectionClient:new(
		Managers.connection:network_event_delegate(),
		self._engine_lobby,
		Network.leave_lan_lobby,
		Managers.connection.combined_hash,
		HOST_TYPES.player,
		nil,
		ticket
	)
	self._connection_client._realms_protocol = SessionTicket.PROTOCOL_VERSION
	self._connection_client:boot_complete()
	self._engine_lobby = nil
	self._elapsed = 0
	self:_set_state(STATES.validating)
end

ClientSessionBoot.admission_accepted = function (self, mechanism_context)
	if self:state() == STATES.validating then
		self._mechanism_context = mechanism_context
		self._admission_accepted = true
	end
end

ClientSessionBoot.admission_rejected = function (self, reason, disconnect_reason)
	if self:state() == STATES.validating then
		self:_fail(reason, disconnect_reason)
	end
end

ClientSessionBoot._buffer_connection_events = function (self)
	while true do
		local event, parameters = self._connection_client:next_event()

		if not event then
			return nil
		end
		if event == "disconnected" then
			return parameters
		end

		self._buffered_connection_events[#self._buffered_connection_events + 1] = {
			name = event,
			parameters = parameters,
		}
	end
end

ClientSessionBoot._update_validation = function (self, dt)
	if self._admission_accepted then
		self:_set_state(STATES.ready)
		self:event_object():set_booted()

		return
	end

	self._connection_client:update(dt)

	local disconnection = self:_buffer_connection_events()

	if not disconnection then
		return
	end

	local game_reason = disconnection.game_reason
	local disconnect_reason = game_reason

	if game_reason == "version_mismatch" then
		disconnect_reason = DisconnectReason.GAME_VERSION_MISMATCH
	elseif not DisconnectReason.is_known(disconnect_reason) then
		disconnect_reason = DisconnectReason.CONNECTION_FAILED
	end

	self:_fail(game_reason or disconnection.engine_reason or "Connection closed during admission", disconnect_reason)
end

ClientSessionBoot.update = function (self, dt)
	local state = self:state()

	if state ~= STATES.ready and state ~= STATES.failed then
		self._elapsed = self._elapsed + dt

		local timeout = state == STATES.joining and JOIN_TIMEOUT_SECONDS
			or state == STATES.validating and VALIDATION_TIMEOUT_SECONDS
			or ADDRESS_TIMEOUT_SECONDS

		if self._elapsed > timeout then
			self:_try_next_address("connection timed out in " .. tostring(state))

			return
		end
	end

	if self:state() == STATES.handshake then
		local address = self:_current_address()
		local status = self._browser:client_handshake_status(address, self._options.server_port)

		if status == 2 then
			self._browser:establish_connection_to_server(address, self._options.server_port)
			self._elapsed = 0
			self:_set_state(STATES.searching)
		elseif status ~= 1 then
			self:_try_next_address("engine client handshake returned status " .. tostring(status))
		end
	elseif self:state() == STATES.searching then
		local lobby_data = self:_find_host_lobby()

		if lobby_data then
			self._engine_lobby = Network.join_lan_lobby(lobby_data.id)

			if not self._engine_lobby then
				self:_fail("Network.join_lan_lobby did not create the Realms client lobby")
			else
				self._elapsed = 0
				self:_set_state(STATES.joining)
			end
		elseif not self._browser:is_refreshing() then
			self:_try_next_address("lobby browser did not return the requested Realms host")
		end
	elseif self:state() == STATES.joining then
		local lobby_state = self._engine_lobby:state()

		if lobby_state == "failed" then
			self:_try_next_address("engine lobby failed to join")
		elseif lobby_state == "joined" then
			local host_peer_id = string.lower(tostring(self._engine_lobby:lobby_host()))

			if #host_peer_id ~= 16 or string.match(host_peer_id, "^[0-9a-f]+$") == nil then
				self:_fail("Joined lobby returned an invalid host peer ID")
			else
				self._options.host_peer_id = host_peer_id
				self:_create_connection()
			end
		end
	elseif self:state() == STATES.validating then
		self:_update_validation(dt)
	end
end

ClientSessionBoot.result = function (self)
	self:_update_crashify_properties("realms_client")

	local connection_client = self._connection_client

	connection_client._realms_mechanism_context = self._mechanism_context

	for i = #self._buffered_connection_events, 1, -1 do
		table.insert(connection_client._events, 1, self._buffered_connection_events[i])
	end

	self._connection_client = nil

	return connection_client
end

ClientSessionBoot._clear = function (self)
	if self._connection_client then
		self._connection_client:delete()
		self._connection_client = nil
	elseif self._engine_lobby then
		Network.leave_lan_lobby(self._engine_lobby)
		self._engine_lobby = nil
	end

	if self._browser then
		LanClient.destroy_lobby_browser(self._wan_client, self._browser)
		self._browser = nil
	end
end

ClientSessionBoot.destroy = function (self)
	if self:state() ~= STATES.ready and self:state() ~= STATES.failed and self._options.on_cancelled then
		self._options.on_cancelled()
	end

	self:_clear()
	self._options = nil
	self._mechanism_context = nil
	self._wan_client = nil
end

return ClientSessionBoot
