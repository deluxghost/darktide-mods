local mod = get_mod("Realms")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local Views = require("scripts/ui/views/views")
local PreparationProtocol = mod:io_dofile("Realms/scripts/mods/Realms/protocol/preparation_protocol")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")
local PreparationViewModel = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/model")

local Preparation = {
	__class_name = "RealmsPreparationController",
}
local state = mod:persistent_table("preparation_state")
local client_hello_sent = false
local view_open_failure_logged = false
local Session
local SessionControl
local ProfileUpdates

local VIEW_NAME = "realms_preparation_view"
local COUNTDOWN_DURATION = 5
local PREPARATION_BYPASS_GAME_MODES = {
	hub = true,
	hub_singleplay = true,
	prologue_hub = true,
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

local function send_message(channel_id, message_type, data)
	if state.role == "host" then
		return SessionControl.send_to_client(channel_id, PreparationProtocol.NAME, message_type, data)
	end

	return SessionControl.send_to_host(PreparationProtocol.NAME, message_type, data)
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
		mission_name = state.mission_name,
		ready_peer_ids = ready_peer_ids(),
		revision = state.revision,
		started = state.phase == "started" or state.phase == "bypassed",
	}
end

local function send_snapshot(channel_id)
	return send_message(channel_id, "snapshot", snapshot_data())
end

local function broadcast_snapshot()
	return SessionControl.send_to_clients(PreparationProtocol.NAME, "snapshot", snapshot_data())
end

local function reset(role, phase, mission_name)
	close_view()
	client_hello_sent = false
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

local function apply_snapshot(data)
	if data.revision < state.revision then
		return
	end
	if data.revision > state.revision
		and state.phase ~= "client_booting"
		and (state.phase == "started" or state.mission_name ~= data.mission_name)
	then
		Session.client_mission_transition_started(data.mission_name)
	end

	local ready_by_peer = {}

	for i = 1, #data.ready_peer_ids do
		ready_by_peer[data.ready_peer_ids[i]] = true
	end

	state.ready_by_peer = ready_by_peer
	state.revision = data.revision
	state.finalizing = data.finalizing
	state.mission_name = data.mission_name
	Session.apply_remote_max_members(data.max_members)

	if data.started then
		state.phase = "started"
		state.countdown_end_time = nil
		state.finalizing = false
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

function Preparation.host_transition_started(mission_name)
	local revision = state.revision

	reset("host", "host_booting", mission_name)
	state.revision = revision
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
	if not state.mission_name then
		return
	end

	local connection = active_host_connection()

	if should_bypass_preparation(state.mission_name) then
		state.phase = "bypassed"
		state.revision = state.revision + 1

		if connection then
			broadcast_snapshot()
		end

		return
	end

	state.phase = "waiting"
	state.ready_by_peer[local_peer_id()] = false

	if connection then
		for _, peer_id in pairs(connection:connected_peers()) do
			state.ready_by_peer[normalize_peer_id(peer_id)] = false
		end
	end

	state.revision = state.revision + 1

	if connection then
		broadcast_snapshot()
	end
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
		return
	end

	state.ready_by_peer[peer_id] = false
	update_host_countdown()
	state.revision = state.revision + 1
	broadcast_snapshot()
end

function Preparation.remote_disconnected(channel_id, peer_id)
	peer_id = normalize_peer_id(peer_id)

	if state.role ~= "host" or state.phase ~= "waiting" then
		return
	end

	ProfileUpdates.remote_disconnected(peer_id)

	if state.ready_by_peer[peer_id] == nil then
		return
	end

	state.ready_by_peer[peer_id] = nil
	update_host_countdown()
	state.revision = state.revision + 1
	broadcast_snapshot()
end

function Preparation.server_settings_changed()
	if state.role ~= "host" or state.phase ~= "waiting" then
		return
	end

	state.revision = state.revision + 1
	broadcast_snapshot()
end

local function receive_hello(channel_id)
	if state.role ~= "host" or state.phase ~= "waiting" and state.phase ~= "started" then
		return true
	end

	return send_snapshot(channel_id)
end

local function receive_profile_cancel(channel_id, peer_id, data)
	if state.role ~= "host" or state.phase ~= "waiting" then
		return true
	end

	return ProfileUpdates.receive_cancel(channel_id, peer_id, data)
end

local function receive_profile_pending(channel_id, peer_id, data)
	if state.role ~= "host" or state.phase ~= "waiting" then
		return true
	end

	return ProfileUpdates.receive_pending(channel_id, peer_id, data)
end

local function receive_profile_update(channel_id, peer_id, data)
	if state.role ~= "host" or state.phase ~= "waiting" then
		return true
	end

	return ProfileUpdates.receive_update(channel_id, peer_id, data)
end

local function receive_ready(channel_id, peer_id, data)
	if state.role ~= "host" or state.phase ~= "waiting" then
		return true
	end

	set_host_ready(normalize_peer_id(peer_id), data.ready)

	return true
end

local function receive_snapshot(channel_id, peer_id, data)
	if state.role ~= "client" or state.phase ~= "waiting" and state.phase ~= "started" then
		return true
	end

	apply_snapshot(data)

	return true
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

function Preparation.install(session, profile_updates, session_control)
	Session = session
	ProfileUpdates = profile_updates
	SessionControl = session_control

	SessionControl.register_protocol(PreparationProtocol)
	SessionControl.register_host_handler(PreparationProtocol.NAME, "hello", receive_hello)
	SessionControl.register_host_handler(PreparationProtocol.NAME, "profile_cancel", receive_profile_cancel)
	SessionControl.register_host_handler(PreparationProtocol.NAME, "profile_pending", receive_profile_pending)
	SessionControl.register_host_handler(PreparationProtocol.NAME, "profile_update", receive_profile_update)
	SessionControl.register_host_handler(PreparationProtocol.NAME, "ready", receive_ready)
	SessionControl.register_client_handler(PreparationProtocol.NAME, "snapshot", receive_snapshot)
	SessionControl.register_connected_handler("preparation", function (channel_id, peer_id, role)
		if role == "host" then
			Preparation.remote_connected(channel_id, peer_id)
		end
	end)
	SessionControl.register_ready_handler("preparation", function (channel_id, peer_id, role)
		if role == "host" and state.role == "host" and (state.phase == "waiting" or state.phase == "started") then
			return send_snapshot(channel_id)
		end
		if role == "client" and state.role == "client" and state.phase == "waiting" then
			client_hello_sent = send_message(channel_id, "hello", {})

			return client_hello_sent
		end

		return true
	end)
	SessionControl.register_disconnect_handler("preparation", function (peer_id, channel_id)
		Preparation.remote_disconnected(channel_id, peer_id)
	end)
end

function Preparation.send_to_host(message_type, data)
	if state.role ~= "client" or state.phase ~= "waiting" then
		return false, "Preparation client channel is unavailable", true
	end

	if not SessionControl.is_available() then
		return false, "Preparation host channel is unavailable", true
	end

	return SessionControl.send_to_host(PreparationProtocol.NAME, message_type, data)
end

function Preparation.player_rows()
	return PreparationViewModel.player_rows(state.ready_by_peer)
end

function Preparation.update()
	if state.role == "host" then
		local connection = active_host_connection()

		if state.phase == "waiting" and connection then
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

		if connection and state.phase == "waiting" and not client_hello_sent and SessionControl.is_available() then
			client_hello_sent = SessionControl.send_to_host(PreparationProtocol.NAME, "hello", {})
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
