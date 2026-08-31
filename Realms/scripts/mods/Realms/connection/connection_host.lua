local mod = get_mod("Realms")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local PlayerManager = require("scripts/foundation/managers/player/player_manager")
local ProfileSynchronizerHost = require("scripts/loading/profile_synchronizer_host")
local Native = mod:io_dofile("Realms/scripts/mods/Realms/runtime/native")
local RemoteConnection = mod:io_dofile("Realms/scripts/mods/Realms/connection/remote_connection")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local ABANDONED_PEER_TIMEOUT_MS = 30000
local NATIVE_EVENT_POLL_INTERVAL = 0.05

local function remote_for_peer(self, peer_id)
	for _, remote in pairs(self._remote_connections) do
		if remote:peer_id() == peer_id then
			return remote
		end
	end
end

local HOST_TYPES = MatchmakingConstants.HOST_TYPES
local ConnectionHost = class("ConnectionHost")

ConnectionHost.init = function (self, event_delegate, approve_delegate, engine_lobby, options)
	self._event_delegate = event_delegate
	self._approve_delegate = approve_delegate
	self._engine_lobby = engine_lobby
	self._lobby_id = options.peer_id
	self._network_hash = options.network_hash
	self._tick_rate = options.tick_rate
	self._max_members = options.max_members
	self._accept_new_connections = options.accept_new_connections
	self._password = options.password
	self._local_port = options.local_port
	self._mission_name = options.mission_name
	self._on_installed = options.on_installed
	self._on_remote_connected = options.on_remote_connected
	self._on_remote_disconnected = options.on_remote_disconnected
	self._session_seed = math.random_seed()
	self._peer_id = Network.peer_id()
	self._remote_connections = {}
	self._peer_profile_syncs = {}
	self._events = {}
	self._pending_channel_closes = {}
	self._installed = false
	self._destroyed = false
	self._native_event_poll_elapsed = NATIVE_EVENT_POLL_INTERVAL
	self._native_maintenance_elapsed = 0
	self._realms_protocol = SessionTicket.PROTOCOL_VERSION
	self._profile_synchronizer_host = ProfileSynchronizerHost:new(event_delegate)

	approve_delegate:register(self._lobby_id, "connection", self)

	mod:info("Created listen host lobby=%s peer=%s port=%d max_members=%d", self._lobby_id, self._peer_id, self._local_port, self._max_members)
end

ConnectionHost.destroy = function (self)
	self._destroyed = true
	self._approve_delegate:unregister(self._lobby_id, "connection")

	local channel_ids = table.keys(self._remote_connections)

	for i = 1, #channel_ids do
		local channel_id = channel_ids[i]

		self:_destroy_remote(channel_id, self._remote_connections[channel_id])
	end

	self._profile_synchronizer_host:delete()
	self._profile_synchronizer_host = nil

	local closed, close_error = Native.close_local_session()

	if not closed then
		mod:error("Failed closing native local session: %s", close_error)
	end

	Network.leave_lan_lobby(self._engine_lobby)

	self._engine_lobby = nil
	self._approve_delegate = nil
	self._event_delegate = nil
	self._on_installed = nil
	self._on_remote_connected = nil
	self._on_remote_disconnected = nil
end

ConnectionHost.event_delegate = function (self)
	return self._event_delegate
end

ConnectionHost.network_hash = function (self)
	return self._network_hash
end

ConnectionHost.profile_synchronizer = function (self)
	return self._profile_synchronizer_host
end

ConnectionHost.update_local_profile = function (self, local_player_id, profile)
	local player = Managers.player:player(self._peer_id, local_player_id)

	if not player or player:peer_id() ~= self._peer_id then
		return false, "Realms host profile identity is unavailable"
	end

	self._profile_synchronizer_host:override_singleplay_profile(self._peer_id, local_player_id, profile)

	return true
end

ConnectionHost.update_remote_profile = function (self, channel_id, peer_id, local_player_id, profile, profile_chunks)
	local remote = self._remote_connections[channel_id]

	if not remote or not remote:is_connected() or remote:peer_id() ~= peer_id then
		return false, "Realms profile update channel is unavailable"
	end
	if not remote:update_profile_source(local_player_id, profile_chunks) then
		return false, "Realms profile update player is unavailable"
	end

	self._profile_synchronizer_host:override_singleplay_profile(peer_id, local_player_id, profile)

	return true
end

ConnectionHost.is_installed = function (self)
	return self._installed
end

ConnectionHost.is_realms_channel = function (self, channel_id)
	return self._remote_connections[channel_id] ~= nil
end

ConnectionHost.validate_session_ticket = function (self, ticket)
	local payload, decode_error, disconnect_reason = SessionTicket.decode(ticket)

	if not payload then
		return nil, decode_error, disconnect_reason
	end

	return SessionTicket.validate(payload, self._peer_id, self._password)
end

ConnectionHost.can_accept_peer = function (self, peer_id)
	if not self._accept_new_connections then
		return false, DisconnectReason.SERVER_PRIVATE
	end
	if peer_id == self._peer_id then
		return false, DisconnectReason.CLIENT_DATA_REJECTED
	end
	if self:num_connections() > self._max_members - 1 then
		return false, DisconnectReason.SERVER_FULL
	end

	for _, remote in pairs(self._remote_connections) do
		if remote:peer_id() == peer_id then
			return true
		end
	end

	return false, DisconnectReason.CLIENT_DATA_REJECTED
end

ConnectionHost.approve_channel = function (self, channel_id, peer_id, lobby_id, message)
	if self._destroyed
		or lobby_id ~= self._lobby_id
		or message ~= "connection"
		or self._remote_connections[channel_id]
	then
		return false
	end

	for _, remote in pairs(self._remote_connections) do
		if remote:peer_id() == peer_id then
			return false
		end
	end

	local adopted, adopt_error = Native.adopt_peer_transport_state(peer_id)

	if not adopted then
		mod:error("Failed adopting native peer transport state peer=%s error=%s", peer_id, adopt_error)

		return false
	end

	local remote = RemoteConnection:new(self, channel_id, peer_id)

	self._remote_connections[channel_id] = remote
	self._events[#self._events + 1] = {
		name = "connecting",
		parameters = {
			channel_id = channel_id,
			peer_id = peer_id,
		},
	}
	mod:info("Approved connection channel=%d peer=%s", channel_id, peer_id)

	return true
end

ConnectionHost.remote_failed = function (self, remote, reason)
	self._events[#self._events + 1] = {
		name = "disconnected",
		parameters = {
			channel_id = remote:channel_id(),
			game_reason = reason,
			peer_id = remote:peer_id(),
		},
	}

	mod:info("Remote connection failed channel=%d peer=%s reason=%s", remote:channel_id(), remote:peer_id(), tostring(reason))
end

local function send_player_connected(channel_id, remote)
	local data = remote:player_sync_data()

	RPC.rpc_player_connected(
		channel_id,
		remote:peer_id(),
		data.local_player_id_array,
		data.is_human_controlled_array,
		data.account_id_array,
		data.player_session_id_array,
		data.slot_array,
		data.player_instance_id_array
	)
end

local BOT_NETWORK_STRING_PLACEHOLDER = ""

local function create_host_sync_data(peer_id)
	local data = Managers.player:create_sync_data(peer_id, true)
	local player_count = #data.local_player_id_array

	for i = 1, player_count do
		if data.is_human_controlled_array[i] then
			assert(type(data.account_id_array[i]) == "string", "Realms host human player is missing an account ID")
			assert(type(data.player_session_id_array[i]) == "string", "Realms host human player is missing a telemetry session ID")
			assert(type(data.player_instance_id_array[i]) == "string", "Realms host human player is missing a telemetry instance ID")
		else
			data.account_id_array[i] = PlayerManager.NO_ACCOUNT_ID
			data.player_session_id_array[i] = BOT_NETWORK_STRING_PLACEHOLDER
			data.player_instance_id_array[i] = BOT_NETWORK_STRING_PLACEHOLDER
		end
	end

	return data
end

ConnectionHost._start_peer_profile_sync = function (self, target_remote, source_remote)
	local synchronizer = self._profile_synchronizer_host
	local target_channel_id = target_remote:channel_id()
	local source = source_remote:profile_source()

	synchronizer:start_initial_sync(target_channel_id, source.peer_id, source.local_player_ids)

	for i = 1, #source.local_player_ids do
		synchronizer:sync_player_profile(target_channel_id, source.peer_id, source.local_player_ids[i], source.profile_chunks_array[i])
	end

	self._peer_profile_syncs[target_channel_id] = self._peer_profile_syncs[target_channel_id] or {}
	self._peer_profile_syncs[target_channel_id][source.peer_id] = {
		source = source_remote,
		target = target_remote,
	}
end

ConnectionHost.is_remote_integrated = function (self, remote)
	local peer_id = remote:peer_id()
	local member_peers = Managers.connection:member_peers()

	for i = 1, #member_peers do
		if member_peers[i] == peer_id then
			return true
		end
	end

	return false
end

ConnectionHost.remote_connected = function (self, remote)
	local channel_id = remote:channel_id()
	local peer_id = remote:peer_id()

	if not remote:handoff_rpc("rpc_check_mechanism") then
		remote:fail("Failed handing off the Realms preparation RPC", DisconnectReason.SERVER_ERROR)

		return
	end

	local host_sync_data = create_host_sync_data(self._peer_id)
	local bot_synchronizer_host = Managers.bot:synchronizer_host()

	bot_synchronizer_host:add_peer(channel_id)

	RPC.rpc_sync_host_local_players(
		channel_id,
		host_sync_data.local_player_id_array,
		host_sync_data.is_human_controlled_array,
		host_sync_data.account_id_array,
		host_sync_data.player_session_id_array,
		host_sync_data.slot_array,
		host_sync_data.player_instance_id_array
	)

	for other_channel_id, other_remote in pairs(self._remote_connections) do
		if other_channel_id ~= channel_id and other_remote:is_connected() then
			send_player_connected(channel_id, other_remote)
			self:_start_peer_profile_sync(other_remote, remote)
		end
	end

	self._events[#self._events + 1] = {
		name = "connected",
		parameters = {
			channel_id = channel_id,
			peer_id = peer_id,
			player_sync_data = remote:player_sync_data(),
		},
	}
	mod:info("Remote connection completed channel=%d peer=%s", channel_id, peer_id)

	if self._on_remote_connected then
		self._on_remote_connected(channel_id, peer_id)
	end
end

ConnectionHost.initial_profile_sources = function (self, connecting_remote)
	local sources = {
		connecting_remote:profile_source(),
	}
	local host_sync_data = create_host_sync_data(self._peer_id)

	sources[#sources + 1] = {
		local_player_ids = host_sync_data.local_player_id_array,
		peer_id = self._peer_id,
		profile_chunks_array = host_sync_data.profile_chunks_array,
	}

	for _, remote in pairs(self._remote_connections) do
		if remote ~= connecting_remote and remote:is_connected() then
			sources[#sources + 1] = remote:profile_source()
		end
	end

	return sources
end

ConnectionHost._finish_profile_sync = function (self, completed)
	for _, remote in pairs(self._remote_connections) do
		if remote:channel_id() == completed.channel_id
			and remote:initial_profile_sync_completed(completed.peer_id, completed.peer_player_ids)
		then
			return
		end
	end

	local channel_syncs = self._peer_profile_syncs[completed.channel_id]
	local peer_profile_sync = channel_syncs and channel_syncs[completed.peer_id]

	if not peer_profile_sync then
		return
	end

	self._profile_synchronizer_host:finalize_initial_sync(completed.channel_id, completed.peer_id, completed.peer_player_ids)
	send_player_connected(completed.channel_id, peer_profile_sync.source)
	channel_syncs[completed.peer_id] = nil

	if not next(channel_syncs) then
		self._peer_profile_syncs[completed.channel_id] = nil
	end
end

ConnectionHost._destroy_remote = function (self, channel_id, remote)
	local peer_id = remote:peer_id()

	if self._on_remote_disconnected then
		self._on_remote_disconnected(channel_id, peer_id)
	end

	if remote:is_connected() then
		for other_channel_id, other_remote in pairs(self._remote_connections) do
			if other_channel_id ~= channel_id and other_remote:is_connected() then
				RPC.rpc_player_disconnected(other_channel_id, peer_id)
			end
		end
	end

	if remote:is_connected() or remote:profile_sync_started() then
		self._profile_synchronizer_host:peer_disconnected(peer_id, channel_id)
	end

	remote:delete()
	self._remote_connections[channel_id] = nil
	self._peer_profile_syncs[channel_id] = nil

	for target_channel_id, channel_syncs in pairs(self._peer_profile_syncs) do
		channel_syncs[peer_id] = nil

		if not next(channel_syncs) then
			self._peer_profile_syncs[target_channel_id] = nil
		end
	end

	local released, release_error = Native.release_peer_transport_state(peer_id)

	if not released then
		mod:error("Native peer transport release failed peer=%s error=%s", peer_id, release_error)
	end
end

ConnectionHost.remove = function (self, channel_id)
	local remote = self._remote_connections[channel_id]

	if remote then
		self:_destroy_remote(channel_id, remote)
	end
end

ConnectionHost.disconnect = function (self, channel_id)
	self._engine_lobby:close_channel(channel_id)
end

ConnectionHost.kick = function (self, channel_id, reason, optional_details)
	if self._pending_channel_closes[channel_id] then
		return
	end

	RPC.rpc_kicked(channel_id, reason, optional_details)

	self._pending_channel_closes[channel_id] = 1
end

ConnectionHost.close_all_channels = function (self, reason, optional_details)
	local channel_ids = table.keys(self._remote_connections)

	for i = 1, #channel_ids do
		self:kick(channel_ids[i], reason, optional_details)
	end
end

ConnectionHost.set_admission_policy = function (self, accept_new_connections, max_members, password)
	self._accept_new_connections = accept_new_connections
	self._max_members = max_members
	self._password = password

	return true
end

ConnectionHost._close_pending_channels = function (self)
	if not next(self._pending_channel_closes) then
		return
	end

	local channel_ids = table.keys(self._pending_channel_closes)

	for i = 1, #channel_ids do
		local channel_id = channel_ids[i]
		local updates_remaining = self._pending_channel_closes[channel_id]

		if updates_remaining > 0 then
			self._pending_channel_closes[channel_id] = updates_remaining - 1
		else
			self._pending_channel_closes[channel_id] = nil
			self._engine_lobby:close_channel(channel_id)
		end
	end
end

ConnectionHost._maintain_native_state = function (self, dt)
	self._native_maintenance_elapsed = self._native_maintenance_elapsed + dt

	if self._native_maintenance_elapsed < 1 then
		return
	end

	self._native_maintenance_elapsed = 0

	local reaped_count, reap_error = Native.reap_abandoned_peer_transport_state(ABANDONED_PEER_TIMEOUT_MS)

	if reaped_count == nil then
		mod:error("Abandoned native peer cleanup failed: %s", reap_error)
	elseif reaped_count > 0 then
		mod:info("Released %d abandoned native peer slots", reaped_count)
	end
end

ConnectionHost._poll_native_events = function (self, dt)
	self._native_event_poll_elapsed = self._native_event_poll_elapsed + dt

	if self._native_event_poll_elapsed < NATIVE_EVENT_POLL_INTERVAL then
		return
	end

	self._native_event_poll_elapsed = self._native_event_poll_elapsed % NATIVE_EVENT_POLL_INTERVAL
	while true do
		local event, event_error = Native.poll_event()

		if event == false then
			return
		end
		if event == nil then
			mod:error("Native event polling failed: %s", event_error)

			return
		end

		if event.type == Native.EVENT_TYPES.error then
			mod:error("Native event failed code=%d peer=%s channel=%d message=%s", event.code, event.peer_id, event.channel_id, event.message)
		elseif event.type == Native.EVENT_TYPES.peer_rejected then
			if not remote_for_peer(self, event.peer_id) then
				local released, release_error = Native.release_peer_transport_state(event.peer_id)

				if not released then
					mod:error("Rejected peer transport release failed peer=%s error=%s", event.peer_id, release_error)
				end
			end

			mod:info("Rejected peer=%s code=%d message=%s", event.peer_id, event.code, event.message)
		else
			mod:debug("Native peer event type=%d peer=%s channel=%d", event.type, event.peer_id, event.channel_id)
		end
	end
end

ConnectionHost.update = function (self, dt)
	self:_close_pending_channels()
	self:_poll_native_events(dt)
	self:_maintain_native_state(dt)
	self._profile_synchronizer_host:update(dt)

	local completed_syncs = self._profile_synchronizer_host:completed_initial_syncs()

	for i = 1, #completed_syncs do
		self:_finish_profile_sync(completed_syncs[i])
	end

	for _, remote in pairs(self._remote_connections) do
		remote:update(dt)
	end
end

ConnectionHost.next_event = function (self)
	if table.is_empty(self._events) then
		return nil
	end

	local event = table.remove(self._events, 1)

	return event.name, event.parameters
end

ConnectionHost.register_profile_synchronizer = function (self)
	Managers.profile_synchronization:set_profile_synchroniser_host(self._profile_synchronizer_host)
	self._installed = true

	if self._on_installed then
		self._on_installed()
	end
end

ConnectionHost.unregister_profile_synchronizer = function (self)
	self._installed = false

	if Managers.profile_synchronization then
		Managers.profile_synchronization:set_profile_synchroniser_host(nil)
	end
end

ConnectionHost.allocation_state = function (self)
	return self:num_connections() + 1, self._max_members
end

ConnectionHost.num_connections = function (self)
	return table.size(self._remote_connections)
end

ConnectionHost.max_members = function (self)
	return self._max_members
end

ConnectionHost.tick_rate = function (self)
	return self._tick_rate
end

ConnectionHost.host = function (self)
	return self._peer_id
end

ConnectionHost.engine_lobby = function (self)
	return self._engine_lobby
end

ConnectionHost.engine_lobby_id = function (self)
	return self._lobby_id
end

ConnectionHost.host_is_dedicated_server = function (self)
	return false
end

ConnectionHost.host_type = function (self)
	return HOST_TYPES.player
end

ConnectionHost.server_name = function (self)
	return mod:localize("mod_name")
end

ConnectionHost.session_seed = function (self)
	return self._session_seed
end

ConnectionHost.session_id = function (self)
	return "realms-" .. self._peer_id
end

ConnectionHost.connecting_peers = function (self)
	local peers = {}

	for _, remote in pairs(self._remote_connections) do
		if not remote:is_connected() then
			peers[#peers + 1] = remote:peer_id()
		end
	end

	return peers
end

ConnectionHost.has_connecting_peers = function (self)
	for _, remote in pairs(self._remote_connections) do
		if not remote:is_connected() then
			return true
		end
	end

	return false
end

ConnectionHost.local_port = function (self)
	return self._local_port
end

ConnectionHost.mission_name = function (self)
	return self._mission_name
end

ConnectionHost.set_mission_name = function (self, mission_name)
	self._mission_name = mission_name
end

ConnectionHost.connected_peers = function (self)
	local peers = {}

	for channel_id, remote in pairs(self._remote_connections) do
		if remote:is_connected() then
			peers[channel_id] = remote:peer_id()
		end
	end

	return peers
end

ConnectionHost.status_lines = function (self)
	local lines = {}
	local channel_ids = table.keys(self._remote_connections)

	table.sort(channel_ids)

	for i = 1, #channel_ids do
		lines[#lines + 1] = self._remote_connections[channel_ids[i]]:status_line()
	end

	return lines
end

return ConnectionHost
