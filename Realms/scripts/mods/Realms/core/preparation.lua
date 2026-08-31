local mod = get_mod("Realms")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local Views = require("scripts/ui/views/views")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local PreparationProtocol = mod:io_dofile("Realms/scripts/mods/Realms/protocol/preparation_protocol")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")
local PreparationViewModel = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/model")

local Preparation = {
	__class_name = "RealmsPreparationController",
}
local state = mod:persistent_table("preparation_state")
local client_member_peers = {}
local registered_channels = {}
local client_hello_sent = false
local view_open_failure_logged = false
local Session
local ProfileUpdates

local CLIENT_TO_HOST_RPC = "rpc_check_mechanism"
local HOST_TO_CLIENT_RPC = "rpc_check_mechanism_reply"
local VIEW_NAME = "realms_preparation_view"
local COUNTDOWN_DURATION = 5
local REASSEMBLY_TIMEOUT = 10
local PREPARATION_BYPASS_GAME_MODES = {
	hub = true,
	hub_singleplay = true,
	shooting_range = true,
}

state.phase = state.phase or "inactive"
state.finalizing = state.finalizing or false
state.ready_by_peer = state.ready_by_peer or {}
state.revision = state.revision or 0
state.role = state.role or "none"

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function should_bypass_preparation(mission_name)
	if not mod:get("mission_preparation") then
		return true
	end

	local mission_template = MissionTemplates[mission_name]
	local game_mode_name = mission_template and mission_template.game_mode_name

	return PREPARATION_BYPASS_GAME_MODES[game_mode_name] == true
end

local function active_host_connection()
	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_host

	return connection and connection._realms_protocol == SessionTicket.PROTOCOL_VERSION and connection or nil
end

local function active_client_connection()
	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_client

	return connection and connection._realms_protocol == SessionTicket.PROTOCOL_VERSION and connection or nil
end

local function realms_boot_in_progress()
	local session_manager = Managers.multiplayer_session
	local session_boot = session_manager and session_manager._session_boot
	local class_name = session_boot and session_boot.__class_name

	return class_name == "RealmsHostSessionBoot" or class_name == "RealmsClientSessionBoot"
end

local function client_connected_to_host(connection)
	local connection_manager = Managers.connection

	if not connection_manager then
		return false
	end

	table.clear(client_member_peers)
	connection_manager:member_peers(client_member_peers)

	return table.contains(client_member_peers, connection:host())
end

local function control_delegate()
	local connection_manager = Managers.connection

	return connection_manager and connection_manager:network_event_delegate() or nil
end

local function close_view()
	local ui_manager = Managers.ui

	if ui_manager and ui_manager:view_active(VIEW_NAME) and not ui_manager:is_view_closing(VIEW_NAME) then
		ui_manager:close_view(VIEW_NAME, true)
	end
end

local function open_view()
	local ui_manager = Managers.ui

	if not ui_manager or not Views[VIEW_NAME] then
		return false
	end
	if ui_manager:view_active(VIEW_NAME) then
		return true
	end

	local opened = ui_manager:open_view(VIEW_NAME, nil, false, true, nil, {})

	if opened then
		view_open_failure_logged = false
	elseif not view_open_failure_logged then
		view_open_failure_logged = true
		mod:error("Failed to open the preparation view")
	end

	return opened
end

local function unregister_channel(channel_id)
	local registration = registered_channels[channel_id]

	if not registration then
		return
	end

	local delegate = control_delegate()
	local objects = delegate and delegate._registered_channel_objects[registration.rpc_name]

	if objects and objects[channel_id] == Preparation then
		delegate:unregister_channel_events(channel_id, registration.rpc_name)
	end

	registered_channels[channel_id] = nil
end

local function unregister_all_channels()
	local channel_ids = table.keys(registered_channels)

	for i = 1, #channel_ids do
		unregister_channel(channel_ids[i])
	end

	client_hello_sent = false
end

local function register_channel(channel_id, peer_id)
	if type(channel_id) ~= "number" then
		return false, "Preparation control channel is unavailable"
	end

	if registered_channels[channel_id] then
		return true
	end

	local delegate = control_delegate()

	if not delegate then
		return false, "Network event delegate is unavailable"
	end

	local rpc_name = state.role == "host" and CLIENT_TO_HOST_RPC or HOST_TO_CLIENT_RPC
	local objects = delegate._registered_channel_objects[rpc_name]
	local existing = objects and objects[channel_id]

	if existing and existing ~= Preparation then
		if existing.__class_name ~= Preparation.__class_name then
			return false, string.format("RPC %s is still owned by %s", rpc_name, tostring(existing.__class_name))
		end

		delegate:unregister_channel_events(channel_id, rpc_name)
	end

	delegate:register_connection_channel_events(Preparation, channel_id, rpc_name)
	registered_channels[channel_id] = {
		peer_id = peer_id and normalize_peer_id(peer_id) or nil,
		receive_chunks = nil,
		receive_size = 0,
		receive_started_at = nil,
		rpc_name = rpc_name,
	}

	return true
end

local function send_frames(payload, send_frame)
	for offset = 1, #payload, PreparationProtocol.MAX_FRAME_SIZE do
		local chunk = string.sub(payload, offset, offset + PreparationProtocol.MAX_FRAME_SIZE - 1)
		local is_last = offset + PreparationProtocol.MAX_FRAME_SIZE > #payload

		send_frame(chunk, is_last)
	end

	return true
end

local function send_message(channel_id, message_type, data)
	local payload, encode_error = PreparationProtocol.encode(message_type, data)

	if not payload then
		mod:error("Failed encoding %s message: %s", message_type, encode_error)

		return false, encode_error
	end

	return send_frames(payload, function (chunk, is_last)
		if state.role == "host" then
			RPC.rpc_check_mechanism_reply(channel_id, is_last, chunk)
		else
			RPC.rpc_check_mechanism(channel_id, chunk, is_last)
		end
	end)
end

local function ready_peer_ids()
	local peer_ids = {}

	for peer_id, ready in pairs(state.ready_by_peer) do
		if ready then
			peer_ids[#peer_ids + 1] = peer_id
		end
	end

	table.sort(peer_ids)

	return peer_ids
end

local function countdown_remaining_ms()
	if not state.countdown_end_time then
		return 0
	end

	local remaining = math.ceil((state.countdown_end_time - Managers.time:time("main")) * 1000)

	return math.clamp(remaining, 0, COUNTDOWN_DURATION * 1000)
end

local function snapshot_data()
	local connection = active_host_connection()

	return {
		countdown_remaining_ms = countdown_remaining_ms(),
		finalizing = state.finalizing,
		max_members = connection:max_members(),
		ready_peer_ids = ready_peer_ids(),
		revision = state.revision,
		started = state.phase == "started",
	}
end

local function send_snapshot(channel_id)
	return send_message(channel_id, "snapshot", snapshot_data())
end

local function broadcast_snapshot()
	local channel_ids = table.keys(registered_channels)

	for i = 1, #channel_ids do
		send_snapshot(channel_ids[i])
	end
end

local function reset(role, phase, mission_name)
	unregister_all_channels()
	close_view()
	state.mission_name = mission_name
	state.phase = phase
	state.countdown_end_time = nil
	state.finalizing = false
	state.ready_by_peer = {}
	state.revision = 0
	state.role = role
end

local function local_peer_id()
	return normalize_peer_id(Network.peer_id())
end

local function all_session_players_ready()
	local player_count = 0

	for _, ready in pairs(state.ready_by_peer) do
		player_count = player_count + 1

		if not ready then
			return false
		end
	end

	return player_count > 0
end

local function update_host_countdown()
	local should_count_down = state.role == "host"
		and state.phase == "waiting"
		and not state.finalizing
		and all_session_players_ready()

	if should_count_down == (state.countdown_end_time ~= nil) then
		return
	end

	state.countdown_end_time = should_count_down and Managers.time:time("main") + COUNTDOWN_DURATION or nil
end

local function set_host_ready(peer_id, ready)
	if state.finalizing then
		return
	end

	if state.ready_by_peer[peer_id] == ready then
		return
	end

	state.ready_by_peer[peer_id] = ready
	update_host_countdown()
	state.revision = state.revision + 1
	broadcast_snapshot()
end

local function fail_control_channel(channel_id, reason)
	mod:info("Rejected preparation control channel=%s: %s", tostring(channel_id), reason)

	if state.role == "host" then
		local connection = active_host_connection()

		if connection and connection:is_realms_channel(channel_id) then
			connection:kick(channel_id, DisconnectReason.CLIENT_DATA_REJECTED)
		end
	else
		mod:error(mod:localize("preparation_control_failed"))
		Managers.multiplayer_session:leave("realms_invalid_preparation_control")
	end
end

local function apply_snapshot(data)
	if data.revision < state.revision then
		return
	end

	local ready_by_peer = {}

	for i = 1, #data.ready_peer_ids do
		ready_by_peer[data.ready_peer_ids[i]] = true
	end

	state.ready_by_peer = ready_by_peer
	state.revision = data.revision
	state.finalizing = data.finalizing
	Session.apply_remote_max_members(data.max_members)

	if data.started then
		state.phase = "started"
		state.countdown_end_time = nil
		state.finalizing = false
		unregister_all_channels()
	else
		state.phase = "waiting"
		state.countdown_end_time = data.countdown_remaining_ms > 0
			and Managers.time:time("main") + data.countdown_remaining_ms / 1000
			or nil
	end
end

function Preparation.host_boot_started(mission_name)
	reset("host", "host_booting", mission_name)
end

function Preparation.client_boot_started()
	reset("client", "client_booting")
end

function Preparation.client_context_received(mission_name, preparation_phase)
	if state.role ~= "client" or state.phase ~= "client_booting" then
		return false
	end

	state.mission_name = mission_name
	state.phase = preparation_phase == "preparing" and "waiting" or "started"

	return true
end

function Preparation.host_mechanism_configured(mission_name)
	if state.role ~= "host" or state.phase ~= "host_booting" then
		return
	end

	state.mission_name = mission_name or state.mission_name

	if should_bypass_preparation(state.mission_name) then
		state.phase = "bypassed"

		return
	end

	state.phase = "waiting"
	state.ready_by_peer[local_peer_id()] = false
	state.revision = state.revision + 1
end

function Preparation.host_installed()
	if state.role ~= "host" or state.phase ~= "waiting" or not active_host_connection() then
		return false
	end

	local mechanism_data = Managers.mechanism and Managers.mechanism:mechanism_data()

	state.mission_name = mechanism_data and mechanism_data.mission_name or state.mission_name

	return true
end

function Preparation.intercept_all_players_ready()
	if state.role ~= "host" or not Preparation.is_waiting() then
		return false
	end

	mod:info("Deferred all_players_ready until every Realms player is ready")

	return true
end

function Preparation.remote_connected(channel_id, peer_id)
	if state.role ~= "host" or state.phase ~= "waiting" and state.phase ~= "started" then
		return
	end

	peer_id = normalize_peer_id(peer_id)

	if state.phase == "started" then
		unregister_channel(channel_id)

		return
	end

	local registered, register_error = register_channel(channel_id, peer_id)

	if not registered then
		fail_control_channel(channel_id, register_error)

		return
	end

	state.ready_by_peer[peer_id] = false
	update_host_countdown()
	state.revision = state.revision + 1
	broadcast_snapshot()
end

function Preparation.remote_disconnected(channel_id, peer_id)
	peer_id = normalize_peer_id(peer_id)
	unregister_channel(channel_id)

	if state.role == "host" and state.phase == "waiting" and state.ready_by_peer[peer_id] ~= nil then
		state.ready_by_peer[peer_id] = nil
		update_host_countdown()
		state.revision = state.revision + 1
		broadcast_snapshot()
	end
end

function Preparation.server_settings_changed()
	if state.role ~= "host" or state.phase ~= "waiting" then
		return
	end

	state.revision = state.revision + 1
	broadcast_snapshot()
end

local function receive_message(channel_id, payload)
	local message, decode_error = PreparationProtocol.decode(payload)

	if not message then
		fail_control_channel(channel_id, decode_error)

		return
	end

	if state.role == "host" then
		local registration = registered_channels[channel_id]
		local peer_id = registration and registration.peer_id

		if state.phase ~= "waiting" and state.phase ~= "started" or type(peer_id) ~= "string" then
			fail_control_channel(channel_id, "Host received preparation control outside an active phase")

			return
		end
		if message.type == "hello" then
			send_snapshot(channel_id)

			if state.phase == "started" then
				unregister_channel(channel_id)
			end
		elseif state.phase == "waiting" and message.type == "profile_cancel" then
			local accepted, accept_error = ProfileUpdates.receive_cancel(channel_id, peer_id, message.data)

			if accepted == false then
				fail_control_channel(channel_id, accept_error)
			end
		elseif state.phase == "waiting" and message.type == "profile_pending" then
			local accepted, accept_error = ProfileUpdates.receive_pending(channel_id, peer_id, message.data)

			if accepted == false then
				fail_control_channel(channel_id, accept_error)
			end
		elseif state.phase == "waiting" and message.type == "profile_update" then
			local accepted, accept_error = ProfileUpdates.receive_update(channel_id, peer_id, message.data)

			if accepted == false then
				fail_control_channel(channel_id, accept_error)
			end
		elseif state.phase == "waiting" and message.type == "ready" then
			set_host_ready(peer_id, message.data.ready)
		else
			fail_control_channel(channel_id, "Host received an invalid preparation message type")
		end
	elseif state.role == "client" then
		if message.type ~= "snapshot" then
			fail_control_channel(channel_id, "Client received an invalid preparation message type")

			return
		end

		apply_snapshot(message.data)
	end
end

local function receive_frame(channel_id, is_last, chunk)
	local registration = registered_channels[channel_id]

	if not registration
		or type(is_last) ~= "boolean"
		or type(chunk) ~= "string"
		or #chunk == 0
		or #chunk > PreparationProtocol.MAX_FRAME_SIZE
	then
		fail_control_channel(channel_id, "Preparation control frame is invalid")

		return
	end

	if not registration.receive_chunks then
		registration.receive_chunks = {}
		registration.receive_size = 0
		registration.receive_started_at = Managers.time:time("main")
	end

	registration.receive_chunks[#registration.receive_chunks + 1] = chunk
	registration.receive_size = registration.receive_size + #chunk

	if registration.receive_size > PreparationProtocol.MAX_MESSAGE_SIZE then
		fail_control_channel(channel_id, "Preparation control message exceeds the size limit")

		return
	end
	if not is_last then
		return
	end

	local payload = table.concat(registration.receive_chunks)

	registration.receive_chunks = nil
	registration.receive_size = 0
	registration.receive_started_at = nil

	receive_message(channel_id, payload)
end

local function expire_partial_messages()
	if not next(registered_channels) then
		return
	end

	local t = Managers.time:time("main")

	for channel_id, registration in pairs(registered_channels) do
		if registration.receive_started_at and t - registration.receive_started_at > REASSEMBLY_TIMEOUT then
			registration.receive_chunks = nil
			registration.receive_size = 0
			registration.receive_started_at = nil
			fail_control_channel(channel_id, "Preparation control message reassembly timed out")
		end
	end
end

function Preparation.rpc_check_mechanism(self, channel_id, payload, is_last)
	receive_frame(channel_id, is_last, payload)
end

function Preparation.rpc_check_mechanism_reply(self, channel_id, is_last, payload)
	receive_frame(channel_id, is_last, payload)
end

function Preparation.local_ready()
	return state.ready_by_peer[local_peer_id()] or false
end

function Preparation.phase()
	return state.phase
end

function Preparation.role()
	return state.role
end

function Preparation.connection_phase()
	if state.role ~= "host" then
		return nil
	end
	if state.phase == "waiting" then
		return "preparing"
	end
	if state.phase == "started" or state.phase == "bypassed" then
		return "started"
	end

	return nil
end

function Preparation.mission_name()
	return state.mission_name
end

function Preparation.enter_state()
	return Preparation.ensure_view()
end

function Preparation.ensure_view()
	if state.phase == "started" then
		return true
	end
	if not Preparation.is_waiting() then
		return false
	end

	return open_view()
end

function Preparation.exit_state()
	close_view()
end

function Preparation.is_waiting()
	return state.phase == "waiting" and (active_host_connection() ~= nil or active_client_connection() ~= nil or realms_boot_in_progress())
end

function Preparation.is_started()
	return state.phase == "started"
end

function Preparation.is_finalizing()
	return state.finalizing
end

function Preparation.allows_profile_changes()
	return Preparation.is_waiting() and not state.finalizing
end

function Preparation.action_label()
	return Preparation.local_ready() and "preparation_cancel_ready" or "preparation_ready"
end

function Preparation.perform_action()
	if not Preparation.is_waiting() or state.finalizing then
		return false
	end

	local ready = Preparation.local_ready()

	if state.role == "host" then
		set_host_ready(local_peer_id(), not ready)
	else
		local connection = active_client_connection()
		local channel_id = connection and connection:host_channel()

		if channel_id then
			send_message(channel_id, "ready", {
				ready = not ready,
			})
		end
	end

	return true
end

function Preparation.open_inventory(view)
	if state.finalizing then
		return
	end

	local player_manager = Managers.player
	local player = player_manager and player_manager:local_player(1)

	if not player then
		return
	end

	if Preparation.local_ready() then
		Preparation.perform_action()
	end

	Managers.ui:open_view("inventory_background_view", nil, nil, nil, nil, {
		parent = view,
		player = player,
	})
end

function Preparation.countdown_remaining()
	local remaining_ms = countdown_remaining_ms()

	return remaining_ms > 0 and math.ceil(remaining_ms / 1000) or nil
end

function Preparation.mission_header()
	return PreparationViewModel.mission_header(state.mission_name)
end

function Preparation.mission_details()
	return PreparationViewModel.mission_details(state.mission_name)
end

function Preparation.install(session, profile_updates)
	Session = session
	ProfileUpdates = profile_updates
end

function Preparation.send_to_host(message_type, data)
	if state.role ~= "client" or state.phase ~= "waiting" then
		return false, "Preparation client channel is unavailable"
	end

	local connection = active_client_connection()
	local channel_id = connection and connection:host_channel()

	if not channel_id or not registered_channels[channel_id] then
		return false, "Preparation host channel is unavailable"
	end

	return send_message(channel_id, message_type, data)
end

function Preparation.player_rows()
	return PreparationViewModel.player_rows(state.ready_by_peer)
end

function Preparation.update()
	expire_partial_messages()

	if state.role == "host" then
		local connection = active_host_connection()

		if state.phase == "waiting" and connection then
			local connected_peers = connection:connected_peers()

			for channel_id, peer_id in pairs(connected_peers) do
				if not registered_channels[channel_id] then
					Preparation.remote_connected(channel_id, peer_id)
				end
			end

			if state.countdown_end_time and Managers.time:time("main") >= state.countdown_end_time then
				state.finalizing = true
				state.countdown_end_time = nil
				state.revision = state.revision + 1
				broadcast_snapshot()

				return
			end
			if state.finalizing and ProfileUpdates.ready_to_start(connection) then
				state.phase = "started"
				state.finalizing = false
				state.revision = state.revision + 1
				broadcast_snapshot()
				unregister_all_channels()
				Managers.mechanism:trigger_event("all_players_ready")

				return
			end
		elseif not connection then
			local manager = Managers.multiplayer_session

			if not manager or not manager:is_booting_session() then
				reset("none", "inactive")
			end
		end
	elseif state.role == "client" then
		local connection = active_client_connection()

		if connection then
			if state.phase == "started" or not client_connected_to_host(connection) then
				return
			end

			local channel_id = connection:host_channel()
			local registered, register_error = register_channel(channel_id, connection:host())

			if not registered then
				fail_control_channel(channel_id, register_error)
			elseif not client_hello_sent then
				client_hello_sent = send_message(channel_id, "hello", {})
			end

		elseif state.phase == "client_booting" then
			local manager = Managers.multiplayer_session

			if manager and not manager:is_booting_session() then
				reset("none", "inactive")
			end
		elseif not connection then
			reset("none", "inactive")
		end
	end
end

return Preparation
