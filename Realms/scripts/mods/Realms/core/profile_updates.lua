local mod = get_mod("Realms")
local ProfileUpdate = mod:io_dofile("Realms/scripts/mods/Realms/protocol/profile_update")

local ProfileUpdates = {}
local Session
local Preparation
local GameplayControl
local observed_connection
local local_change
local pending_notice
local pending_cancel
local pending_delivery
local pending_by_peer = {}
local latest_sequence_by_peer = {}

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function local_peer_id()
	return normalize_peer_id(Network.peer_id())
end

local function active_connection()
	local connection_manager = Managers.connection

	return connection_manager and (connection_manager._connection_host or connection_manager._connection_client) or nil
end

local function reset()
	observed_connection = active_connection()
	local_change = nil
	pending_notice = nil
	pending_cancel = nil
	pending_delivery = nil
	table.clear(pending_by_peer)
	table.clear(latest_sequence_by_peer)
end

local function ensure_session()
	local connection = active_connection()

	if connection ~= observed_connection then
		reset()
	end

	return connection
end

local function local_player(local_player_id)
	local player_manager = Managers.player

	return player_manager and player_manager:player(Network.peer_id(), local_player_id) or nil
end

local function mark_host_pending(peer_id, local_player_id, sequence, profile_received)
	peer_id = normalize_peer_id(peer_id)
	pending_by_peer[peer_id] = {
		local_player_id = local_player_id,
		profile_received = profile_received,
		sequence = sequence,
	}
end

local function send_to_host(message_type, data)
	if Preparation.is_waiting() then
		return Preparation.send_to_host(message_type, data)
	end

	return GameplayControl.send_to_host(message_type, data)
end

local function flush_client_messages()
	if pending_notice then
		local sent = send_to_host("profile_pending", pending_notice)

		if not sent then
			return
		end

		pending_notice = nil
	end

	local message_type = pending_delivery and "profile_update" or pending_cancel and "profile_cancel"
	local data = pending_delivery or pending_cancel

	if not data then
		return
	end

	local sent = send_to_host(message_type, data)

	if sent then
		pending_delivery = nil
		pending_cancel = nil
	end
end

local function clear_host_pending(peer_id, local_player_id, sequence)
	peer_id = normalize_peer_id(peer_id)

	local pending = pending_by_peer[peer_id]

	if pending and pending.local_player_id == local_player_id and pending.sequence == sequence then
		pending_by_peer[peer_id] = nil
	end
end

local function fail_local_update(request, sequence, message)
	mod:error("%s", message)

	if request.role == "host" then
		clear_host_pending(local_peer_id(), request.local_player_id, sequence)
	else
		pending_delivery = nil
		pending_cancel = {
			local_player_id = request.local_player_id,
			sequence = sequence,
		}
		flush_client_messages()
	end
end

local function start_fetch()
	local request = local_change

	if not request or request.fetching then
		return
	end

	local player = local_player(request.local_player_id)
	local characters = Managers.backend and Managers.backend.interfaces and Managers.backend.interfaces.characters

	if not player or not characters then
		fail_local_update(request, request.sequence, "Failed reading the local profile for Realms synchronization")

		return
	end

	local account_id = player:account_id()
	local character_id = player:character_id()
	local sequence = request.sequence
	local role = request.role

	request.fetching = true
	characters:fetch_account_character(account_id, character_id, true, true):next(function (backend_profile_data)
		request.fetching = false

		if local_change ~= request or active_connection() ~= request.connection or not Session.is_active() then
			return
		end
		if request.sequence ~= sequence then
			start_fetch()

			return
		end

		local current_player = local_player(request.local_player_id)

		if not current_player
			or current_player:account_id() ~= account_id
			or current_player:character_id() ~= character_id
		then
			fail_local_update(request, sequence, "Local profile identity changed during Realms synchronization")

			return
		end

		local created, data, profile, create_error = pcall(
			ProfileUpdate.create,
			sequence,
			current_player,
			backend_profile_data
		)

		if not created then
			fail_local_update(request, sequence, "Failed creating the local Realms profile update: " .. tostring(data))

			return
		end
		if not data then
			fail_local_update(request, sequence, "Failed creating the local Realms profile update: " .. tostring(create_error))

			return
		end

		if role == "host" then
			local applied, apply_error = request.connection:update_local_profile(request.local_player_id, profile)

			if not applied then
				fail_local_update(request, sequence, "Failed applying the local Realms profile update: " .. tostring(apply_error))

				return
			end

			mark_host_pending(local_peer_id(), request.local_player_id, sequence, true)
		else
			pending_cancel = nil
			pending_delivery = data
			flush_client_messages()
		end
	end):catch(function (fetch_error)
		request.fetching = false

		if local_change ~= request or active_connection() ~= request.connection or not Session.is_active() then
			return
		end
		if request.sequence ~= sequence then
			start_fetch()

			return
		end

		fail_local_update(request, sequence, "Failed fetching the local profile for Realms synchronization: " .. tostring(fetch_error))
	end)
end

local function request_local_update(local_player_id, role)
	local connection = ensure_session()

	if not local_change or local_change.role ~= role or local_change.local_player_id ~= local_player_id then
		local_change = {
			connection = connection,
			fetching = false,
			local_player_id = local_player_id,
			role = role,
			sequence = 0,
		}
	end

	local_change.sequence = local_change.sequence + 1

	if role == "host" then
		mark_host_pending(local_peer_id(), local_player_id, local_change.sequence, false)
	else
		pending_cancel = nil
		pending_delivery = nil
		pending_notice = {
			local_player_id = local_player_id,
			sequence = local_change.sequence,
		}
		flush_client_messages()
	end

	start_fetch()
end

local function expected_remote_identity(peer_id, local_player_id)
	local player_manager = Managers.player
	local player = player_manager and player_manager:player(peer_id, local_player_id)

	if not player then
		return nil
	end

	return {
		account_id = player:account_id(),
		character_id = player:character_id(),
		local_player_id = local_player_id,
	}
end

function ProfileUpdates.install(session, preparation, gameplay_control)
	Session = session
	Preparation = preparation
	GameplayControl = gameplay_control

	GameplayControl.register_host_handler("profile_pending", ProfileUpdates.receive_pending)
	GameplayControl.register_host_handler("profile_cancel", ProfileUpdates.receive_cancel)
	GameplayControl.register_host_handler("profile_update", ProfileUpdates.receive_update)
	GameplayControl.register_disconnect_handler("profile_updates", function (peer_id)
		ProfileUpdates.remote_disconnected(peer_id)
	end)
end

function ProfileUpdates.intercept_client_notification(local_player_id)
	if not Session.is_active_client() then
		return false
	end
	if not Managers.mechanism:profile_changes_are_allowed() then
		return true
	end

	request_local_update(local_player_id, "client")

	return true
end

function ProfileUpdates.receive_cancel(channel_id, peer_id, data)
	peer_id = normalize_peer_id(peer_id)

	local expected_identity = expected_remote_identity(peer_id, data.local_player_id)

	if not expected_identity then
		return false, "Profile update player is unavailable"
	end

	local latest_sequence = latest_sequence_by_peer[peer_id] or 0

	if data.sequence < latest_sequence then
		return true
	end
	if data.sequence > latest_sequence then
		return false, "Profile update cancellation has no pending notification"
	end

	clear_host_pending(peer_id, data.local_player_id, data.sequence)

	return true
end

function ProfileUpdates.intercept_host_profile_change(synchronizer, peer_id, local_player_id)
	if not Session.is_active_host() or normalize_peer_id(peer_id) ~= local_peer_id() then
		return false
	end

	local connection = active_connection()

	if not connection or connection:profile_synchronizer() ~= synchronizer then
		return false
	end

	request_local_update(local_player_id, "host")

	return true
end

function ProfileUpdates.receive_pending(channel_id, peer_id, data)
	peer_id = normalize_peer_id(peer_id)

	local expected_identity = expected_remote_identity(peer_id, data.local_player_id)

	if not expected_identity then
		return false, "Profile update player is unavailable"
	end

	local latest_sequence = latest_sequence_by_peer[peer_id] or 0

	if data.sequence <= latest_sequence then
		return true
	end

	latest_sequence_by_peer[peer_id] = data.sequence
	mark_host_pending(peer_id, data.local_player_id, data.sequence, false)

	return true
end

function ProfileUpdates.receive_update(channel_id, peer_id, data)
	peer_id = normalize_peer_id(peer_id)

	local expected_identity = expected_remote_identity(peer_id, data.identity.local_player_id)

	if not expected_identity then
		return false, "Profile update player is unavailable"
	end

	local latest_sequence = latest_sequence_by_peer[peer_id] or 0

	if data.sequence < latest_sequence then
		return true
	end
	if data.sequence == latest_sequence then
		local pending = pending_by_peer[peer_id]

		if not pending or pending.sequence ~= data.sequence or pending.profile_received then
			return true
		end
		if pending.local_player_id ~= data.identity.local_player_id then
			return false, "Profile update player does not match its pending notification"
		end
	end

	local update, validation_error = ProfileUpdate.validate(data, expected_identity)

	if not update then
		return false, validation_error
	end

	local connection = active_connection()
	local applied, apply_error = connection and connection:update_remote_profile(
		channel_id,
		peer_id,
		update.local_player_id,
		update.profile,
		update.profile_chunks
	)

	if not applied then
		return false, apply_error
	end

	latest_sequence_by_peer[peer_id] = update.sequence
	mark_host_pending(peer_id, update.local_player_id, update.sequence, true)

	return true
end

function ProfileUpdates.remote_disconnected(peer_id)
	peer_id = normalize_peer_id(peer_id)
	pending_by_peer[peer_id] = nil
	latest_sequence_by_peer[peer_id] = nil
end

function ProfileUpdates.ready_to_start(connection)
	if next(pending_by_peer) then
		return false
	end

	local peer_ids = {
		local_peer_id(),
	}
	local peers_filter = {
		[peer_ids[1]] = true,
	}

	for _, peer_id in pairs(connection:connected_peers()) do
		peer_id = normalize_peer_id(peer_id)
		peer_ids[#peer_ids + 1] = peer_id
		peers_filter[peer_id] = true
	end

	return connection:profile_synchronizer():profiles_synced(peer_ids, peers_filter)
end

function ProfileUpdates.update()
	local connection = ensure_session()

	if not Session.is_active() then
		if connection or local_change or next(pending_by_peer) then
			reset()
		end

		return
	end

	flush_client_messages()

	if Session.is_active_host() then
		local synchronizer = connection:profile_synchronizer()

		for peer_id, pending in pairs(pending_by_peer) do
			local profile_updates = synchronizer._profile_updates[peer_id]
			local profile_applied = not profile_updates or profile_updates[pending.local_player_id] == nil

			if pending.profile_received and profile_applied and synchronizer:peer_profiles_synced(peer_id) then
				pending_by_peer[peer_id] = nil
			end
		end
	end
end

return ProfileUpdates
