local mod = get_mod("Realms")
local ConnectionClient = require("scripts/multiplayer/connection/connection_client")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local SessionBootBase = require("scripts/multiplayer/session_boot_base")
local ClientSnapshot = mod:io_dofile("Realms/scripts/mods/Realms/protocol/client_snapshot")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")
local Steam = mod:io_dofile("Realms/scripts/mods/Realms/runtime/steam")
local Eos = mod:io_dofile("Realms/scripts/mods/Realms/runtime/eos")

-- Message transports bridge the engine's UDP traffic to a loopback port.
local TRANSPORTS = {
	steam = {
		runtime = Steam,
		disconnect_reason = DisconnectReason.STEAM_CONNECTION_FAILED,
		label = "Steam",
	},
	eos = {
		runtime = Eos,
		disconnect_reason = DisconnectReason.EOS_CONNECTION_FAILED,
		label = "EOS",
	},
}

local HOST_TYPES = MatchmakingConstants.HOST_TYPES
local STATES = table.enum("transport", "password", "handshake", "searching", "joining", "validating", "ready", "failed")
local ADDRESS_TIMEOUT_SECONDS = 8
local JOIN_TIMEOUT_SECONDS = 20
local VALIDATION_TIMEOUT_SECONDS = 20
local ClientSessionBoot = class("RealmsClientSessionBoot", "SessionBootBase")

ClientSessionBoot.init = function (self, event_object, options)
	ClientSessionBoot.super.init(self, STATES, event_object)

	self._options = options
	self._transport = options.transport and TRANSPORTS[options.transport]
	self._password_submitted = options.password ~= nil and options.password ~= ""
	if HAS_STEAM then
		Steam.disconnect()
	end
	Eos.disconnect()
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

	if self._transport then
		self:_connect_transport()
	else
		self._browser = LanClient.create_lobby_browser(self._wan_client)
		self:_set_state(STATES.handshake)
	end
end

ClientSessionBoot._connect_transport = function (self)
	local started, start_error = self._transport.runtime.connect(self._options.remote, self._password_submitted)

	if not started then
		self:_fail(start_error)

		return
	end

	self._elapsed = 0
	self:_set_state(STATES.transport)
end

ClientSessionBoot._request_password = function (self, incorrect)
	self:_clear()
	self._transport.runtime.disconnect()
	table.clear(self._buffered_connection_events)
	self._admission_accepted = false
	self._mechanism_context = nil
	self:_set_state(STATES.password)
	self._password_incorrect = incorrect
end

ClientSessionBoot.submit_password = function (self, password)
	if self:state() ~= STATES.password then
		return false, mod:localize("client_boot_failed")
	end

	local valid, validation_error = SessionTicket.validate_password(password)

	if not valid then
		return false, mod:localize(validation_error)
	end
	self._options.password = password
	self._password_submitted = true
	self:_connect_transport()

	return true
end

ClientSessionBoot.cancel_password = function (self)
	if self:state() ~= STATES.password then
		return
	end

	self._transport.runtime.disconnect()
	self:event_object():failed_to_boot(false, "game", "leave_to_hub")
	self:_set_state(STATES.failed)
	self._options.on_cancelled()
end

ClientSessionBoot.transport_event = function (self, transport, event)
	if self._options.transport ~= transport or self._options.remote ~= event.remote then
		return
	end
	local events = self._transport.runtime.EVENT_TYPES

	if self:state() == STATES.transport then
		if event.type == events.client_ready then
			self._options.server_addresses = {"127.0.0.1"}
			self._options.server_port = event.port
			self._address_index = 1
			self:_reset_browser()
			self._elapsed = 0
			self:_set_state(STATES.handshake)
		elseif event.type == events.password_required then
			self:_request_password(false)
		elseif event.type == events.client_error then
			self:_fail(event.message)
		end
	elseif event.type == events.client_error and self:state() == STATES.handshake then
		self:_fail(event.message)
	end
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
	if self._transport and disconnect_reason == DisconnectReason.PASSWORD_INCORRECT then
		self:_request_password(true)

		return
	end

	disconnect_reason = disconnect_reason or (self._transport and self._transport.disconnect_reason or DisconnectReason.CONNECTION_FAILED)

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

	if state == STATES.password then
		if not Managers.ui:view_instance("realms_join_view") then
			self._password_view_context = {
				steam_id = self._options.transport == "steam" and self._options.remote or nil,
				incorrect = self._password_incorrect,
				submit = callback(self, "submit_password"),
				cancel = callback(self, "cancel_password"),
			}
			mod.open_join_view(self._password_view_context)
		end

		return
	end

	if state ~= STATES.ready and state ~= STATES.failed then
		self._elapsed = self._elapsed + dt

		local timeout = state == STATES.transport and JOIN_TIMEOUT_SECONDS
			or state == STATES.joining and JOIN_TIMEOUT_SECONDS
			or state == STATES.validating and VALIDATION_TIMEOUT_SECONDS
			or ADDRESS_TIMEOUT_SECONDS

		if self._elapsed > timeout then
			if state == STATES.transport then
				self:_fail(self._transport.label .. " connection timed out")

				return
			end
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
			-- LAN discovery sends one UDP request. Retry within the existing address deadline.
			self:_reset_browser()
			self._browser:establish_connection_to_server(self:_current_address(), self._options.server_port)
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
	local steam_remote = self._options.transport == "steam" and self._options.remote or nil

	connection_client._realms_steam_host = steam_remote or self._mechanism_context.steam_host_id
	connection_client._realms_transport = self._options.transport or "ip"

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
	if self._transport and self:state() ~= STATES.ready then
		self._transport.runtime.disconnect()
	end
	if self:state() ~= STATES.ready and self:state() ~= STATES.failed and self._options.on_cancelled then
		self._options.on_cancelled()
	end
	if self:state() ~= STATES.ready then
		self:_set_state(STATES.failed)
	end

	local password_view = Managers.ui:view_instance("realms_join_view")

	if self._password_view_context and password_view and password_view._join_context == self._password_view_context then
		Managers.ui:close_view("realms_join_view")
	end

	self:_clear()
	self._options = nil
	self._mechanism_context = nil
	self._wan_client = nil
end

return ClientSessionBoot
