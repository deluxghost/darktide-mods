local mod = get_mod("Realms")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local MultiplayerSession = require("scripts/managers/multiplayer/multiplayer_session")
local StateLoading = require("scripts/game_states/game/state_loading")
local ClientSessionBoot = mod:io_dofile("Realms/scripts/mods/Realms/session/client_session_boot")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local HostSessionBoot = mod:io_dofile("Realms/scripts/mods/Realms/session/host_session_boot")
local MechanismContext = mod:io_dofile("Realms/scripts/mods/Realms/protocol/mechanism_context")
local Native = mod:io_dofile("Realms/scripts/mods/Realms/runtime/native")
local Preparation = mod._preparation
local GameplayControl = mod._gameplay_control
local SessionControl = mod._session_control
local PreparationState = mod:io_dofile("Realms/scripts/mods/Realms/game_states/realms_preparation_state")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local Session = {}
local state = mod:persistent_table("session_state")
local applying_deferred_mechanism_change = false

local function current_connection()
	local connection_manager = Managers.connection

	return connection_manager and (connection_manager._connection_host or connection_manager._connection_client)
end

local function client_boot_in_progress()
	local multiplayer_session_manager = Managers.multiplayer_session
	local session_boot = multiplayer_session_manager and multiplayer_session_manager._session_boot

	return session_boot and session_boot.__class_name == "RealmsClientSessionBoot" or false
end

local function set_client_native_support(enabled)
	if state.client_native_support == enabled then
		return true
	end

	local changed, change_error = Native.set_client_ipv6_member_address_support(enabled)

	if not changed then
		return false, change_error
	end

	state.client_native_support = enabled

	return true
end

local function update_client_native_support()
	local needed = client_boot_in_progress() or Session.is_active_client()
	local changed, change_error = set_client_native_support(needed)

	if not changed then
		mod:error("Failed updating native client support: %s", change_error)
	end
end

local function clear_client_join()
	state.client_join_in_progress = false
	state.client_gameplay_transition = false
	state.client_mechanism_context = nil
	state.client_context_activated = false
end

local function clear_transition_state()
	state.deferred_mission_transition = nil
	state.deferred_host_mechanism_change = nil
	state.main_menu_transition = nil
	state.preparation_loading_requested = false
	state.host_preparation_loading = false
	state.host_preparation_no_level_ready = false
end

local function begin_client_boot(options)
	local multiplayer_session_manager = Managers.multiplayer_session
	local connection_manager = Managers.connection

	if not multiplayer_session_manager or not connection_manager or not connection_manager:client() then
		return false, mod:localize("error_multiplayer_unavailable")
	end
	if multiplayer_session_manager:is_booting_session() then
		return false, mod:localize("error_join_already_pending")
	end
	if not options.transition_from_gameplay and (current_connection() or multiplayer_session_manager:has_session()) then
		multiplayer_session_manager:reset("realms_switch_session")
	end

	clear_transition_state()
	state.client_join_in_progress = true
	state.client_gameplay_transition = options.transition_from_gameplay or false
	state.client_context_activated = false

	local new_session = MultiplayerSession:new()

	multiplayer_session_manager._session_boot = ClientSessionBoot:new(new_session, {
		password = options.password,
		server_addresses = options.server_addresses,
		server_port = options.server_port,
		on_failed = function ()
			clear_client_join()
		end,
		on_cancelled = function ()
			clear_client_join()
		end,
	})
	state.client_mechanism_context = nil
	state.main_menu_transition = options.transition_to_loading and "realms_client" or nil

	return true
end

local function update_client_join()
	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_client
	local context = state.client_mechanism_context

	if connection
		and connection._realms_protocol == SessionTicket.PROTOCOL_VERSION
		and context
		and context.channel_id == connection:host_channel()
		and not state.client_context_activated
	then
		Preparation.client_boot_started()

		if not Preparation.client_context_received(context.mission_name, context.preparation_phase) then
			mod:error("Failed activating accepted preparation context")
			clear_client_join()
			Managers.multiplayer_session:leave("realms_invalid_preparation_context")

			return
		end

		state.client_context_activated = true
	end

	local multiplayer_session_manager = Managers.multiplayer_session
	local multiplayer_session = multiplayer_session_manager and multiplayer_session_manager._session

	if not state.client_join_in_progress
		or not state.client_context_activated
		or not multiplayer_session
		or multiplayer_session._realms_protocol ~= SessionTicket.PROTOCOL_VERSION
		or not multiplayer_session:has_joined_host()
	then
		return
	end

	state.client_join_in_progress = false
	state.client_gameplay_transition = false
end

function Session.is_active()
	local connection = current_connection()

	return connection and connection._realms_protocol == SessionTicket.PROTOCOL_VERSION or false
end

function Session.is_active_host()
	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_host

	return connection and connection._realms_protocol == SessionTicket.PROTOCOL_VERSION or false
end

function Session.is_active_client()
	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_client

	return connection and connection._realms_protocol == SessionTicket.PROTOCOL_VERSION or false
end

function Session.max_members()
	local connection = current_connection()

	if Session.is_active_client() and state.remote_max_members then
		return state.remote_max_members
	end

	return connection and connection:max_members() or nil
end

function Session.apply_remote_max_members(max_members)
	if not Session.is_active_client() or type(max_members) ~= "number" or max_members % 1 ~= 0 or max_members < 2 or max_members > 8 then
		return false, "Realms server sent an invalid player limit"
	end

	state.remote_max_members = max_members

	return true
end

function Session.is_host_channel(channel_id)
	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_host

	return connection and connection._realms_protocol == SessionTicket.PROTOCOL_VERSION and connection:is_realms_channel(channel_id) or false
end

local function clear_host_party_tracking()
	state.pending_official_party_id = nil
	state.official_party_session = nil
end

local function reset_host_party_tracking()
	clear_host_party_tracking()
end

local function update_official_party_transition()
	if not Session.is_active_host() then
		clear_host_party_tracking()

		return
	end

	if state.official_party_session then
		if state.official_party_session:is_dead() then
			state.official_party_session = nil
			mod:error(mod:localize("official_session_transition_failed"))
		end

		return
	end

	local session_manager = Managers.multiplayer_session

	if not session_manager or session_manager:is_leaving() or session_manager:is_booting_session() then
		return
	end

	local party_manager = Managers.party_immaterium
	local pending_party_id = state.pending_official_party_id

	if not pending_party_id or not party_manager or not party_manager:have_recieved_game_state() then
		return
	end

	local party_id = party_manager:party_id()

	if party_id ~= pending_party_id then
		return
	end

	state.pending_official_party_id = nil

	if not Managers.state.game_session then
		mod:info("Host is joining official party %s from preparation", party_id)
		local next_state = session_manager:find_available_session()

		if next_state ~= StateLoading then
			mod:error(mod:localize("official_session_transition_failed"))
		end

		return
	end

	if party_manager:game_session_in_progress() then
		mod:info("Host is joining the official game session for party %s", party_id)
		state.official_party_session = party_manager:join_game_session()
	else
		mod:info("Host is leaving for official party %s", party_id)
		session_manager:leave("leave_mission_stay_in_party")
	end
end

function Session.official_party_join_started(party_manager, join_parameter, is_reconnect)
	if not Session.is_active_host() or is_reconnect then
		return
	end

	if type(join_parameter) == "string" then
		join_parameter = party_manager:_parse_join_parameter_string(join_parameter)
	end

	local party_id = join_parameter and join_parameter.party_id

	if type(party_id) ~= "string" or party_id == "" or party_id == party_manager:party_id() then
		return
	end

	state.pending_official_party_id = party_id
	mod:info("Host requested official party %s", party_id)
end

function Session.replace_singleplayer_boot(manager, original_boot)
	local new_session = original_boot(manager)
	local mission_name = state.pending_host_mission_name

	state.pending_host_mission_name = nil

	reset_host_party_tracking()
	clear_transition_state()

	Preparation.host_boot_started(mission_name)
	manager._session_boot:delete()
	manager._session_boot = HostSessionBoot:new(new_session, {
		accept_new_connections = not mod:get("private_mode"),
		max_members = mod:get("max_players"),
		mission_name = mission_name,
		on_installed = Session.host_mechanism_changed,
		on_remote_connected = SessionControl.remote_connected,
		on_remote_disconnected = SessionControl.remote_disconnected,
		password = mod:get("server_password") or "",
	})

	return new_session
end

function Session.prepare_local_mission(mission_name)
	state.pending_host_mission_name = mission_name
end

function Session.intercept_host_mechanism_change(mechanism_name, context)
	if applying_deferred_mechanism_change or Preparation.role() ~= "host" or not Managers.state or not Managers.state.game_session then
		return false
	end

	state.deferred_host_mechanism_change = {
		context = context,
		mechanism_name = mechanism_name,
	}
	mod:info("Deferred the host mechanism change until the current gameplay session exits")

	return true
end

function Session.intercept_host_all_players_ready()
	local deferred_change = state.deferred_host_mechanism_change

	if not deferred_change then
		return false
	end

	deferred_change.all_players_ready = true

	return true
end

local function apply_deferred_host_mechanism_change()
	local deferred_change = state.deferred_host_mechanism_change

	if not deferred_change then
		return false
	end

	state.deferred_host_mechanism_change = nil
	applying_deferred_mechanism_change = true
	Managers.mechanism:change_mechanism(deferred_change.mechanism_name, deferred_change.context)
	applying_deferred_mechanism_change = false

	if deferred_change.all_players_ready then
		Managers.mechanism:trigger_event("all_players_ready")
	end

	return true
end

local function host_preparation_loading_transition()
	state.preparation_loading_requested = true
	state.host_preparation_loading = true
	state.host_preparation_no_level_ready = false

	return StateLoading, {
		next_state = PreparationState,
	}
end

function Session.start_client(server_address, server_port_text, password)
	if state.client_gameplay_transition or client_boot_in_progress() then
		return false, mod:localize("error_join_already_pending")
	end

	if type(server_address) ~= "string" or server_address == "" then
		return false, mod:localize("error_server_address_required")
	end

	local server_port = tonumber(server_port_text)

	if not server_port or server_port % 1 ~= 0 or server_port < 1 or server_port > 65535 then
		return false, mod:localize("error_server_port_invalid")
	end

	local valid_password, password_error = SessionTicket.validate_password(password)

	if not valid_password then
		return false, mod:localize(password_error)
	end

	local multiplayer_session_manager = Managers.multiplayer_session
	local connection_manager = Managers.connection

	if not multiplayer_session_manager or not connection_manager then
		return false, mod:localize("error_multiplayer_unavailable")
	end
	if not connection_manager:client() then
		return false, mod:localize("error_connection_client_unavailable")
	end

	local resolved_addresses, resolve_error = Native.resolve_addresses(server_address)

	if not resolved_addresses then
		mod:info("Failed resolving server address %q: %s", server_address, resolve_error)

		return false, mod:localize("error_server_address_unresolved")
	end

	local game_session_active = Managers.state and Managers.state.game_session ~= nil

	local options = {
		password = password,
		server_addresses = resolved_addresses,
		server_port = server_port,
		transition_from_gameplay = game_session_active,
		transition_to_loading = not game_session_active,
	}
	state.remote_max_members = nil
	local native_ready, native_error = set_client_native_support(true)

	if not native_ready then
		mod:error("Failed enabling native client support: %s", native_error)

		return false, mod:localize("client_boot_failed")
	end

	local started, start_error = begin_client_boot(options)

	if not started then
		set_client_native_support(false)

		return false, start_error
	end

	return true, nil, resolved_addresses[1]
end

function Session.update()
	Preparation.update()

	update_official_party_transition()
	update_client_join()
	update_client_native_support()
end

function Session.client_mechanism_context(channel_id, mechanism_name)
	if not Session.is_active_client() and not client_boot_in_progress() then
		return nil
	end

	local saved = state.client_mechanism_context

	if saved and saved.channel_id ~= channel_id then
		return nil
	end
	if not saved then
		if mechanism_name == "onboarding" then
			return false, "Realms host did not provide onboarding mission context"
		end

		return nil
	end

	if saved.mechanism_name ~= mechanism_name then
		return false, "Realms host mechanism context does not match rpc_set_mechanism"
	end

	local mission_name = saved.mission_name
	local mission_settings = MissionTemplates[mission_name]

	if not mission_settings or mission_settings.mechanism_name ~= mechanism_name then
		return false, "Realms mission does not match the host mechanism"
	end

	if mechanism_name ~= "onboarding" then
		return nil
	end

	return {
		mission_name = mission_name,
		server_channel = channel_id,
	}
end

function Session.capture_mechanism_reply(channel_id, mechanism_matched, reply_data)
	if not Session.is_active_client() and not client_boot_in_progress() then
		return true
	end

	local multiplayer_session_manager = Managers.multiplayer_session
	local session_boot = multiplayer_session_manager and multiplayer_session_manager._session_boot

	if not session_boot or session_boot.__class_name ~= "RealmsClientSessionBoot" then
		return false, "Realms client received session context outside client boot"
	end

	local context, context_error = MechanismContext.decode_reply(mechanism_matched, reply_data)

	if context == false then
		session_boot:admission_rejected(context_error, DisconnectReason.SERVER_CONTEXT_INVALID)

		return false, context_error
	end

	context.channel_id = channel_id
	state.client_mechanism_context = context

	session_boot:admission_accepted()

	return true
end

function Session.route_mechanism_transition(next_state, state_context)
	local game_session = Managers.state and Managers.state.game_session

	if state.deferred_host_mechanism_change then
		if game_session then
			return next_state or StateLoading, state_context or {}
		end

		apply_deferred_host_mechanism_change()

		if state.main_menu_transition == "realms_host" then
			state.main_menu_transition = nil

			return host_preparation_loading_transition()
		end
	end

	if not next_state or not Preparation.is_waiting() or state.preparation_loading_requested then
		return next_state, state_context
	end
	if next_state ~= StateLoading then
		mod:error("Expected the prepared mission transition to enter StateLoading, got %s", tostring(next_state))
		Managers.multiplayer_session:leave("realms_invalid_preparation_transition")

		return nil
	end
	-- Leaving existing gameplay emits an empty StateLoading before the new mission transition.
	if type(state_context) ~= "table" or not state_context.mission_name then
		return next_state, state_context
	end

	if state.main_menu_transition == "realms_host" then
		state.main_menu_transition = nil
	end

	state.deferred_mission_transition = {
		next_state = next_state,
		state_context = state_context,
	}
	state.preparation_loading_requested = true

	state.host_preparation_loading = Preparation.role() == "host"
	state.host_preparation_no_level_ready = false
	mod:info("Routing the prepared mission through RealmsPreparationState")

	return StateLoading, {
		next_state = PreparationState,
	}
end

function Session.official_session_boot_started()
	if not Preparation.is_waiting() or Managers.state.game_session then
		return
	end

	state.main_menu_transition = "official"
end

function Session.poll_main_menu_transition()
	apply_deferred_host_mechanism_change()

	if not state.main_menu_transition then
		return nil
	end

	local transition = state.main_menu_transition

	state.main_menu_transition = nil
	mod:info("%s is entering StateLoading", transition == "realms_client" and "Client" or transition == "realms_host" and "Host" or "Official session")

	if transition == "realms_host" then
		return host_preparation_loading_transition()
	end

	return StateLoading, {}
end

function Session.preparation_no_level_started()
	if not state.host_preparation_loading or not Managers.loading:is_host() then
		return false
	end

	state.host_preparation_no_level_ready = true

	return true
end

function Session.preparation_load_finished()
	return state.host_preparation_loading and state.host_preparation_no_level_ready
end

function Session.preparation_state_entered()
	state.host_preparation_loading = false
	state.host_preparation_no_level_ready = false
end

function Session.poll_preparation_transition()
	if state.main_menu_transition then
		return Session.poll_main_menu_transition()
	end

	if Preparation.phase() == "waiting" then
		return nil
	end

	local next_state, state_context = Managers.mechanism:wanted_transition()

	if next_state then
		state.deferred_mission_transition = nil

		return next_state, state_context
	end
	if Preparation.is_started() and state.deferred_mission_transition then
		local transition = state.deferred_mission_transition

		state.deferred_mission_transition = nil

		return transition.next_state, transition.state_context
	end

	return nil
end

local function host_mechanism_data()
	local mechanism_manager = Managers.mechanism

	if not mechanism_manager or type(mechanism_manager:mechanism_name()) ~= "string" then
		return nil
	end

	return mechanism_manager:mechanism_data()
end

function Session.host_mechanism_changed()
	if state.deferred_host_mechanism_change then
		return
	end

	local mechanism_data = host_mechanism_data()

	Preparation.host_mechanism_configured(mechanism_data and mechanism_data.mission_name)

	if not Session.is_active_host() then
		return
	end

	local connection = Managers.connection._connection_host
	local payload, payload_error = MechanismContext.host_payload()

	if payload == nil then
		mod:info("%s", payload_error)

		return
	end

	connection:set_mission_name(mechanism_data and mechanism_data.mission_name)
	if Preparation.host_installed() and not state.preparation_loading_requested then
		state.main_menu_transition = "realms_host"
	end

end

function Session.apply_settings()
	local password = mod:get("server_password") or ""
	local valid_password, password_error = SessionTicket.validate_password(password)

	if not valid_password then
		return false, mod:localize(password_error)
	end

	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_host

	if not connection or connection._realms_protocol ~= SessionTicket.PROTOCOL_VERSION then
		return true
	end

	local applied, apply_error = connection:set_admission_policy(not mod:get("private_mode"), mod:get("max_players"), password)

	if not applied then
		return false, apply_error
	end

	Preparation.server_settings_changed()
	GameplayControl.broadcast_server_settings()

	return true
end

function Session.leave()
	if not Session.is_active() then
		return false
	end

	local connection = current_connection()

	if Session.is_active_host() and connection and connection.close_all_channels then
		connection:close_all_channels(DisconnectReason.SERVER_CLOSED)
	end

	clear_client_join()
	clear_transition_state()
	state.remote_max_members = nil
	Managers.multiplayer_session:leave("realms_disconnect")

	return true
end

function Session.status_lines()
	local lines = {
		"Session status",
		"  active=" .. tostring(Session.is_active()),
		"  role=" .. (Session.is_active_host() and "host" or Session.is_active_client() and "client" or "none"),
	}
	local connection = current_connection()

	if connection and connection._realms_protocol == SessionTicket.PROTOCOL_VERSION then
		lines[#lines + 1] = "  protocol=" .. tostring(connection._realms_protocol)
		lines[#lines + 1] = "  lobby=" .. tostring(connection:engine_lobby_id())

		if Session.is_active_host() then
			lines[#lines + 1] = string.format("  endpoint=udp:%d players:%d/%d private:%s mission:%s", connection:local_port(), connection:num_connections() + 1, connection:max_members(), tostring(mod:get("private_mode")), connection:mission_name() or "none")

			local remote_lines = connection:status_lines()

			for i = 1, #remote_lines do
				lines[#lines + 1] = remote_lines[i]
			end
		else
			lines[#lines + 1] = "  host_channel=" .. tostring(connection:host_channel())
		end
	end

	return lines
end

return Session
