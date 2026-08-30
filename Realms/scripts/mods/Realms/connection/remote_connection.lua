local mod = get_mod("Realms")
local MasterItems = require("scripts/backend/master_items")
local ClientSnapshot = mod:io_dofile("Realms/scripts/mods/Realms/protocol/client_snapshot")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local MechanismContext = mod:io_dofile("Realms/scripts/mods/Realms/protocol/mechanism_context")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local READY_RPCS = {
	"rpc_package_synchronizer_ready_peer",
	"rpc_voting_client_ready",
}

local RPCS = {
	"rpc_check_version",
	"rpc_connection_booted",
	"rpc_request_master_items_version",
	"rpc_request_host_type",
	"rpc_check_mechanism",
	"rpc_claim_slot",
	"rpc_sync_local_players",
	"rpc_ready_to_receive_tick_rate",
	"rpc_request_eac_approval",
	"rpc_ready_to_receive_local_profiles",
	"rpc_dlc_verification_client_done",
	"rpc_ready_to_receive_data",
	"rpc_sync_stat_version",
	"rpc_check_connected",
	"rpc_client_entered_connected_state",
}

for i = 1, #READY_RPCS do
	RPCS[#RPCS + 1] = READY_RPCS[i]
end

local RPC_LOOKUP = table.set(RPCS)
local STAGES = {
	version = 0,
	booted = 1,
	master_items = 2,
	host_type = 3,
	mechanism = 4,
	slot = 5,
	local_players = 6,
	tick_rate = 7,
	eac = 8,
	profiles = 9,
	dlc = 10,
	session_data = 11,
	stats = 12,
	mechanism_connected = 13,
	connected = 14,
	complete = 15,
}
local STAGE_TIMEOUT_SECONDS = 20
local ADMISSION_HANDOFF_TIMEOUT_SECONDS = 60
local RemoteConnection = class("RealmsRemoteConnection")

local function array_lengths_match(...)
	local arrays = { ... }
	local length = #arrays[1]

	for i = 2, #arrays do
		if #arrays[i] ~= length then
			return false
		end
	end

	return true
end

RemoteConnection.init = function (self, owner, channel_id, peer_id)
	self._owner = owner
	self._event_delegate = owner:event_delegate()
	self._channel_id = channel_id
	self._peer_id = peer_id
	self._stage = STAGES.version
	self._stage_elapsed = 0
	self._ticket_parts = {}
	self._ticket_length = 0
	self._slots = {}
	self._stat_ids = {}
	self._stat_versions = {}
	self._stat_versions_matched = {}
	self._profile_sync_pending = {}
	self._profiles_requested = false
	self._profile_sync_started = false
	self._mechanism_registered = false
	self._connected = false
	self._failed = false
	self._ready_rpcs_handed_off = false
	self._ready_rpcs_replayed = false
	self._captured_ready_rpcs = {}
	self._handed_off_rpcs = {}

	self._event_delegate:register_connection_channel_events(self, channel_id, unpack(RPCS))
end

RemoteConnection.destroy = function (self)
	local registered_rpcs = {}

	for i = 1, #RPCS do
		if not self._handed_off_rpcs[RPCS[i]] then
			registered_rpcs[#registered_rpcs + 1] = RPCS[i]
		end
	end

	self._event_delegate:unregister_channel_events(self._channel_id, unpack(registered_rpcs))

	if self._mechanism_registered then
		Managers.mechanism:remove_client(self._channel_id)
	end

	local stats_manager = Managers.stats

	if stats_manager then
		for i = 1, #self._stat_ids do
			local stat_id = self._stat_ids[i]

			if stats_manager:user_state(stat_id) ~= nil then
				stats_manager:remove_user(stat_id)
			end
		end
	end

	if not self._connected then
		for i = 1, #self._slots do
			Managers.player:release_slot(self._slots[i])
		end
	end
	self._owner = nil
	self._event_delegate = nil
end

RemoteConnection.handoff_rpc = function (self, rpc_name)
	if not self._connected or self._handed_off_rpcs[rpc_name] or not RPC_LOOKUP[rpc_name] then
		return false
	end

	self._event_delegate:unregister_channel_events(self._channel_id, rpc_name)
	self._handed_off_rpcs[rpc_name] = true

	return true
end

RemoteConnection.peer_id = function (self)
	return self._peer_id
end

RemoteConnection.channel_id = function (self)
	return self._channel_id
end

RemoteConnection.is_connected = function (self)
	return self._connected
end

RemoteConnection.profile_sync_started = function (self)
	return self._profile_sync_started
end

RemoteConnection.player_sync_data = function (self)
	if not self._local_player_id_array then
		return nil
	end

	return {
		account_id_array = self._account_id_array,
		is_human_controlled_array = self._is_human_controlled_array,
		last_mission_id = self._last_mission_id,
		local_player_id_array = self._local_player_id_array,
		player_instance_id_array = self._player_instance_id_array,
		player_session_id_array = self._player_session_id_array,
		profile_chunks_array = self._profile_chunks_array,
		slot_array = self._slots,
	}
end

RemoteConnection.profile_source = function (self)
	if not self._local_player_id_array or not self._profile_chunks_array then
		return nil
	end

	return {
		local_player_ids = self._local_player_id_array,
		peer_id = self._peer_id,
		profile_chunks_array = self._profile_chunks_array,
	}
end

RemoteConnection.status_line = function (self)
	return string.format("  remote=peer:%s channel:%s stage:%d connected:%s failed:%s", self._peer_id, tostring(self._channel_id), self._stage, tostring(self._connected), tostring(self._failed))
end

RemoteConnection._record_failure = function (self, reason)
	if self._failed then
		return false
	end

	self._failed = true
	self._owner:remote_failed(self, reason)

	return true
end

RemoteConnection.fail = function (self, reason, disconnect_reason)
	if self:_record_failure(reason) then
		self._owner:kick(self._channel_id, disconnect_reason or DisconnectReason.SERVER_ERROR)
	end
end

RemoteConnection._expect_stage = function (self, expected, rpc_name)
	if self._stage == expected then
		return true
	end

	self:fail(string.format("%s arrived at stage %d, expected %d", rpc_name, self._stage, expected), DisconnectReason.CLIENT_DATA_REJECTED)

	return false
end

RemoteConnection._advance = function (self, stage, checkpoint)
	self._stage = stage
	self._stage_elapsed = 0
	mod:info("Peer %s reached stage %d (%s)", self._peer_id, stage, checkpoint)

end

RemoteConnection.update = function (self, dt)
	if self._failed then
		return
	end

	local channel_state, reason = Network.channel_state(self._channel_id)

	if channel_state == "disconnecting" or channel_state == "disconnected" then
		self:_record_failure("Connection channel closed: " .. tostring(reason))

		return
	end

	if self._stage < STAGES.complete then
		self._stage_elapsed = self._stage_elapsed + dt

		local timeout = self._stage == STAGES.slot and ADMISSION_HANDOFF_TIMEOUT_SECONDS or STAGE_TIMEOUT_SECONDS

		if self._stage_elapsed > timeout then
			self:fail(string.format("Connection timed out at stage %d", self._stage), DisconnectReason.CONNECTION_FAILED)

			return
		end
	end

	if self._boot_request_pending and self._owner:is_installed() then
		self._boot_request_pending = false
		RPC.rpc_connection_booted_reply(self._channel_id)
		self:_advance(STAGES.master_items, "connection_booted")
	end

	if self._profiles_requested and self._profile_chunks_array and not self._profile_sync_started then
		self:_start_profile_sync()
	end

	if self._connected and not self._ready_rpcs_handed_off then
		if not self:_handoff_ready_rpcs() then
			return
		end
	end

	if self._ready_rpcs_handed_off and not self._ready_rpcs_replayed and self._owner:is_remote_integrated(self) then
		if not self:_replay_ready_rpcs() then
			return
		end
	end

	if self._stage == STAGES.stats then
		self:_update_stat_versions()
	end
end

RemoteConnection.rpc_check_version = function (self, channel_id, network_hash)
	if not self:_expect_stage(STAGES.version, "rpc_check_version") then
		return
	end

	local accepted, disconnect_reason = self._owner:can_accept_peer(self._peer_id)

	if not accepted then
		self:fail("Realms host is not accepting another player", disconnect_reason)

		return
	end

	RPC.rpc_check_version_reply(channel_id, network_hash == self._owner:network_hash())
	self:_advance(STAGES.booted, "version_checked")
end

RemoteConnection.rpc_connection_booted = function (self, channel_id)
	if not self:_expect_stage(STAGES.booted, "rpc_connection_booted") then
		return
	end

	if self._owner:is_installed() then
		RPC.rpc_connection_booted_reply(channel_id)
		self:_advance(STAGES.master_items, "connection_booted")
	else
		self._boot_request_pending = true
	end
end

RemoteConnection.rpc_request_master_items_version = function (self, channel_id)
	if not self:_expect_stage(STAGES.master_items, "rpc_request_master_items_version") then
		return
	end

	local metadata = MasterItems.get_cached_metadata()
	local url = metadata and metadata.url

	if type(url) ~= "string" then
		self:fail("Official master-items metadata has no URL", DisconnectReason.SERVER_ERROR)

		return
	end

	RPC.rpc_master_items_version_reply(channel_id, tostring(MasterItems.get_cached_version()), url)
	self:_advance(STAGES.host_type, "master_items_checked")
end

RemoteConnection.rpc_request_host_type = function (self, channel_id)
	if not self:_expect_stage(STAGES.host_type, "rpc_request_host_type") then
		return
	end

	RPC.rpc_request_host_type_reply(channel_id, false, self._owner:max_members())
	self:_advance(STAGES.mechanism, "host_type_sent")
end

RemoteConnection.rpc_check_mechanism = function (self, channel_id, ticket_part, is_last_part)
	if not self:_expect_stage(STAGES.mechanism, "rpc_check_mechanism") then
		return
	end
	if type(ticket_part) ~= "string" then
		self:fail("Realms session ticket chunk is not a string", DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	self._ticket_length = self._ticket_length + #ticket_part

	if self._ticket_length > SessionTicket.MAX_TICKET_SIZE then
		self:fail("Realms session ticket exceeds the protocol limit", DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	self._ticket_parts[#self._ticket_parts + 1] = ticket_part

	if not is_last_part then
		return
	end

	local accepted, admission_reason = self._owner:can_accept_peer(self._peer_id)

	if not accepted then
		self:fail("Realms host is not accepting another player", admission_reason)

		return
	end

	local snapshot, ticket_error, disconnect_reason = self._owner:validate_session_ticket(table.concat(self._ticket_parts))

	self._ticket_parts = nil

	if not snapshot then
		self:fail(ticket_error, disconnect_reason)

		return
	end

	local reply_data

	reply_data, ticket_error = MechanismContext.host_payload()

	if not reply_data then
		self:fail(ticket_error, DisconnectReason.SERVER_ERROR)

		return
	end

	RPC.rpc_check_mechanism_reply(channel_id, true, reply_data)

	self._client_snapshot = snapshot
	self:_advance(STAGES.slot, "session_ticket_verified")
end

RemoteConnection.rpc_claim_slot = function (self, channel_id)
	if not self:_expect_stage(STAGES.slot, "rpc_claim_slot") then
		return
	end

	local accepted, disconnect_reason = self._owner:can_accept_peer(self._peer_id)

	if not accepted then
		self:fail("Realms host is not accepting another player", disconnect_reason)

		return
	end

	RPC.rpc_claim_slot_reply(channel_id, true)
	self:_advance(STAGES.local_players, "slot_claimed")
end

RemoteConnection.rpc_sync_local_players = function (self, channel_id, local_player_id_array, is_human_controlled_array, account_id_array, character_id_array, player_session_id_array, last_mission_id)
	if not self:_expect_stage(STAGES.local_players, "rpc_sync_local_players") then
		return
	end
	if #local_player_id_array ~= 1 or not array_lengths_match(
		local_player_id_array,
		is_human_controlled_array,
		account_id_array,
		character_id_array,
		player_session_id_array
	) then
		self:fail("Realms requires exactly one valid local player per client", DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	local snapshot, snapshot_error = ClientSnapshot.validate(self._client_snapshot, {
		account_id = account_id_array[1],
		character_id = character_id_array[1],
		local_player_id = local_player_id_array[1],
	})

	self._client_snapshot = nil

	if not snapshot then
		self:fail("Realms client snapshot was rejected: " .. snapshot_error, DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	local slot = Managers.player:claim_slot()
	local instance_id = Application.guid()
	local stat_id = string.format("%s:%s", self._peer_id, local_player_id_array[1])

	self._slots[1] = slot
	self._stat_ids[1] = stat_id
	self._local_player_id_array = table.clone(local_player_id_array)
	self._is_human_controlled_array = table.clone(is_human_controlled_array)
	self._account_id_array = table.clone(account_id_array)
	self._player_session_id_array = table.clone(player_session_id_array)
	self._player_instance_id_array = { instance_id }
	self._last_mission_id = last_mission_id
	self._profile_chunks_array = { snapshot.profile_chunks }

	RPC.rpc_sync_local_players_reply(channel_id, local_player_id_array, { slot }, { instance_id })

	local stats_installed, stats_error = ClientSnapshot.install_stats(snapshot, stat_id, channel_id, local_player_id_array[1])

	if not stats_installed then
		self:fail("Realms client snapshot was rejected: " .. stats_error, DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	self:_advance(STAGES.tick_rate, "local_players_received")
end

RemoteConnection.rpc_ready_to_receive_tick_rate = function (self, channel_id)
	if not self:_expect_stage(STAGES.tick_rate, "rpc_ready_to_receive_tick_rate") then
		return
	end

	RPC.rpc_sync_tick_rate(channel_id, self._owner:tick_rate())
	self:_advance(STAGES.eac, "tick_rate_sent")
end

RemoteConnection.rpc_request_eac_approval = function (self, channel_id)
	if not self:_expect_stage(STAGES.eac, "rpc_request_eac_approval") then
		return
	end

	RPC.rpc_request_eac_approval_reply(channel_id, true)
	self:_advance(STAGES.profiles, "eac_approved")
end

RemoteConnection.rpc_ready_to_receive_local_profiles = function (self, channel_id)
	if not self:_expect_stage(STAGES.profiles, "rpc_ready_to_receive_local_profiles") then
		return
	end

	self._profiles_requested = true

	if self._profile_chunks_array then
		self:_start_profile_sync()
	end
end

RemoteConnection._start_profile_sync = function (self)
	self._profile_sync_started = true

	local synchronizer = self._owner:profile_synchronizer()
	local sources = self._owner:initial_profile_sources(self)

	synchronizer:register_rpcs(self._channel_id)

	for i = 1, #sources do
		local source = sources[i]

		synchronizer:start_initial_sync(self._channel_id, source.peer_id, source.local_player_ids)
		self._profile_sync_pending[source.peer_id] = true

		for player_index = 1, #source.local_player_ids do
			synchronizer:sync_player_profile(self._channel_id, source.peer_id, source.local_player_ids[player_index], source.profile_chunks_array[player_index])
		end
	end
end

RemoteConnection.initial_profile_sync_completed = function (self, peer_id, local_player_ids)
	if not self._profile_sync_pending[peer_id] then
		return false
	end

	self._owner:profile_synchronizer():finalize_initial_sync(self._channel_id, peer_id, local_player_ids)
	self._profile_sync_pending[peer_id] = nil

	if not next(self._profile_sync_pending) then
		RPC.rpc_sync_local_profiles_reply(self._channel_id)
		self:_advance(STAGES.dlc, "profiles_synced")
	end

	return true
end

RemoteConnection.rpc_dlc_verification_client_done = function (self, channel_id, platform)
	if not self:_expect_stage(STAGES.dlc, "rpc_dlc_verification_client_done") then
		return
	end

	RPC.rpc_dlc_verification_host_response(channel_id, nil)
	self:_advance(STAGES.session_data, "dlc_verified")
end

RemoteConnection.rpc_ready_to_receive_data = function (self, channel_id)
	if not self:_expect_stage(STAGES.session_data, "rpc_ready_to_receive_data") then
		return
	end

	RPC.rpc_session_seed_sync(channel_id, self._owner:session_seed())
	RPC.rpc_data_sync_done(channel_id)
	self:_advance(STAGES.stats, "session_data_sent")
end

RemoteConnection.rpc_sync_stat_version = function (self, channel_id, local_player_id, version)
	if not self:_expect_stage(STAGES.stats, "rpc_sync_stat_version") then
		return
	end

	self._stat_versions[local_player_id] = version
	self:_update_stat_versions()
end

RemoteConnection._update_stat_versions = function (self)
	for i = 1, #self._local_player_id_array do
		local local_player_id = self._local_player_id_array[i]
		local version = self._stat_versions[local_player_id]

		if version ~= nil and not self._stat_versions_matched[local_player_id] then
			local stat_id = self._stat_ids[i]

			if Managers.stats:user_state(stat_id) == Managers.stats.user_states.idle then
				if Managers.stats:user_version(stat_id) == version then
					self._stat_versions_matched[local_player_id] = true
				else
					self._stat_versions[local_player_id] = nil
					RPC.rpc_stat_version_mismatch(self._channel_id, local_player_id)
				end
			end
		end
	end

	if table.size(self._stat_versions_matched) == #self._local_player_id_array then
		RPC.rpc_stat_version_matched(self._channel_id)
		self:_advance(STAGES.mechanism_connected, "stats_synced")
	end
end

RemoteConnection._handoff_ready_rpcs = function (self)
	for i = 1, #READY_RPCS do
		local rpc_name = READY_RPCS[i]

		if not self:handoff_rpc(rpc_name) then
			self:fail("Failed handing off " .. rpc_name .. " to the integrated session", DisconnectReason.SERVER_ERROR)

			return false
		end
	end

	self._ready_rpcs_handed_off = true
	mod:info("Peer %s handed off the client-ready RPC bridge", self._peer_id)

	return true
end

RemoteConnection._replay_ready_rpcs = function (self)
	local registered_channel_objects = self._event_delegate._registered_channel_objects

	for i = 1, #READY_RPCS do
		local rpc_name = READY_RPCS[i]
		local registered_channels = registered_channel_objects[rpc_name]

		if not registered_channels or not registered_channels[self._channel_id] then
			self:fail("Host integration did not register " .. rpc_name, DisconnectReason.SERVER_ERROR)

			return false
		end
	end

	local event_table = self._event_delegate.event_table
	local captured_count = 0

	for i = 1, #READY_RPCS do
		local rpc_name = READY_RPCS[i]

		if self._captured_ready_rpcs[rpc_name] then
			captured_count = captured_count + 1
			rawget(event_table, rpc_name)(event_table, self._channel_id)
		end
	end

	self._ready_rpcs_replayed = true
	self._captured_ready_rpcs = nil
	mod:info("Peer %s completed the client-ready RPC bridge captured=%d", self._peer_id, captured_count)

	return true
end

RemoteConnection.rpc_package_synchronizer_ready_peer = function (self, channel_id)
	if not self._connected then
		self:fail("rpc_package_synchronizer_ready_peer arrived before the final connection state", DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	self._captured_ready_rpcs.rpc_package_synchronizer_ready_peer = true
end

RemoteConnection.rpc_voting_client_ready = function (self, channel_id)
	if not self._connected then
		self:fail("rpc_voting_client_ready arrived before the final connection state", DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	self._captured_ready_rpcs.rpc_voting_client_ready = true
end

RemoteConnection.rpc_check_connected = function (self, channel_id)
	if not self:_expect_stage(STAGES.mechanism_connected, "rpc_check_connected") then
		return
	end

	Managers.mechanism:add_client(channel_id)
	self._mechanism_registered = true
	RPC.rpc_check_connected_reply(channel_id)
	self:_advance(STAGES.connected, "mechanism_connected")
end

RemoteConnection.rpc_client_entered_connected_state = function (self, channel_id)
	if not self:_expect_stage(STAGES.connected, "rpc_client_entered_connected_state") then
		return
	end

	self._connected = true
	self:_advance(STAGES.complete, "connected")
	self._owner:remote_connected(self)
end

return RemoteConnection
