local mod = get_mod("Realms")
local LocalMechanismVerificationState = require("scripts/multiplayer/connection/local_states/local_mechanism_verification_state")
local LoadingManager = require("scripts/managers/loading/loading_manager")
local MechanismManager = require("scripts/managers/mechanism/mechanism_manager")
local ConnectionManager = require("scripts/managers/multiplayer/connection_manager")
local MultiplayerSessionManager = require("scripts/managers/multiplayer/multiplayer_session_manager")
local PartyImmateriumManager = require("scripts/managers/party_immaterium/party_immaterium_manager")
local ProfileSynchronizerHost = require("scripts/loading/profile_synchronizer_host")
local BotBackfill = mod:io_dofile("Realms/scripts/mods/Realms/core/bot_backfill")
local DisconnectErrors = mod:io_dofile("Realms/scripts/mods/Realms/core/disconnect_errors")
local LoadingClients = mod:io_dofile("Realms/scripts/mods/Realms/core/loading_clients")
local MissionSeed = mod:io_dofile("Realms/scripts/mods/Realms/core/mission_seed")
local Preparation = mod:io_dofile("Realms/scripts/mods/Realms/core/preparation")
mod._preparation = Preparation
local GameplayControl = mod:io_dofile("Realms/scripts/mods/Realms/core/gameplay_control")
mod._gameplay_control = GameplayControl
local SessionControl = mod:io_dofile("Realms/scripts/mods/Realms/core/session_control")
mod._session_control = SessionControl
local ModNetwork = mod:io_dofile("Realms/scripts/mods/Realms/core/mod_network")
local Chat = mod:io_dofile("Realms/scripts/mods/Realms/core/chat")

mod.network_register = function (owner_mod, rpc_name, callback)
	return ModNetwork.register(owner_mod, rpc_name, callback)
end

mod.network_on_peer_joined = function (owner_mod, callback)
	return ModNetwork.on_peer_joined(owner_mod, callback)
end

mod.network_on_peer_left = function (owner_mod, callback)
	return ModNetwork.on_peer_left(owner_mod, callback)
end

mod.network_is_available = function ()
	return ModNetwork.is_available()
end

mod.network_send = function (owner_mod, rpc_name, recipient, ...)
	return ModNetwork.send(owner_mod, rpc_name, recipient, ...)
end

local Session = mod:io_dofile("Realms/scripts/mods/Realms/core/session")
mod._session = Session
mod.queue_mission_transition = function (owner_mod, mission_context)
	return Session.queue_mission_transition(owner_mod, mission_context)
end
local ProfileUpdates = mod:io_dofile("Realms/scripts/mods/Realms/core/profile_updates")
local LoadoutChanges = mod:io_dofile("Realms/scripts/mods/Realms/core/loadout_changes")
local Presence = mod:io_dofile("Realms/scripts/mods/Realms/core/presence")
local UnitRpcLifetime = mod:io_dofile("Realms/scripts/mods/Realms/core/unit_rpc_lifetime")
local Workarounds = mod:io_dofile("Realms/scripts/mods/Realms/workarounds/workarounds")
local Loading = mod:io_dofile("Realms/scripts/mods/Realms/views/loading")
local EndViewPatch = mod:io_dofile("Realms/scripts/mods/Realms/views/end_view")
local ChatView = mod:io_dofile("Realms/scripts/mods/Realms/views/chat")
local PreparationChat = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/chat")
mod._preparation_chat = PreparationChat
local SocialMenu = mod:io_dofile("Realms/scripts/mods/Realms/views/social_menu")
local SystemMenu = mod:io_dofile("Realms/scripts/mods/Realms/views/system_menu")
local ViewPackages = mod:io_dofile("Realms/scripts/mods/Realms/views/view_packages")

mod:io_dofile("Realms/scripts/mods/Realms/views/join_view/register")
mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/register")

LoadingClients.install(Session, Preparation)
MissionSeed.install(Session)
SessionControl.install(Session)
Preparation.install(Session, ProfileUpdates, SessionControl)
BotBackfill.install(Session)
DisconnectErrors.install()
GameplayControl.install(Session, Preparation, SessionControl)
ProfileUpdates.install(Session, Preparation, GameplayControl)
LoadoutChanges.install(Session, Preparation)
Presence.install(Session)
ModNetwork.install(SessionControl)
Chat.install(Session, SessionControl)
UnitRpcLifetime.install(Session)
Workarounds.install(Session, GameplayControl)
SystemMenu.install(Preparation, Session)
Loading.install(Session)
EndViewPatch.install(Session)
ChatView.install(Chat)
PreparationChat.install()
SocialMenu.install(Session)

mod.load_package = function (package_name)
	if not Managers.package:is_loading(package_name) and not Managers.package:has_loaded(package_name) then
		Managers.package:load(package_name, "realms", nil, true)
	end
end

mod.on_all_mods_loaded = function ()
	local packages = ViewPackages.all()

	for i = 1, #packages do
		mod.load_package(packages[i])
	end
end

mod:hook(PartyImmateriumManager, "join_party", function (func, self, join_parameter, is_reconnect)
	local promise = func(self, join_parameter, is_reconnect)

	Session.official_party_join_started(self, join_parameter, is_reconnect)

	return promise
end)

mod:hook(MultiplayerSessionManager, "start_singleplayer_session", function (func, self, mission_name, singleplay_type)
	Session.prepare_local_mission(mission_name)

	return func(self, mission_name, singleplay_type)
end)

mod:hook(MultiplayerSessionManager, "reset", function (func, self, reason)
	local reset_session = function (manager, reset_reason)
		return BotBackfill.reset_session(Session, func, manager, reset_reason)
	end

	if Session.intercept_host_reset(self, reset_session, reason) then
		return
	end

	return reset_session(self, reason)
end)

mod:hook(MultiplayerSessionManager, "boot_singleplayer_session", function (func, self)
	return Session.replace_singleplayer_boot(self, func)
end)

mod:hook(MultiplayerSessionManager, "party_immaterium_join_server", function (func, self, ...)
	local session = func(self, ...)

	Session.official_session_boot_started()

	return session
end)

mod:hook(MultiplayerSessionManager, "party_immaterium_hot_join_hub_server", function (func, self, ...)
	local session = func(self, ...)

	Session.official_session_boot_started()

	return session
end)

mod:hook(MechanismManager, "rpc_set_mechanism", function (func, self, channel_id, lookup_id)
	local mechanism_name = self.LOOKUP[lookup_id]
	local context, context_error = Session.client_mechanism_context(channel_id, mechanism_name)

	if context == nil then
		return func(self, channel_id, lookup_id)
	end
	if context == false then
		mod:error(context_error)
		Managers.multiplayer_session:leave("realms_invalid_mechanism_context")

		return
	end

	self:change_mechanism(mechanism_name, context)
end)

mod:hook(MechanismManager, "change_mechanism", function (func, self, mechanism_name, context)
	DisconnectErrors.normalize_left_session_reason(mechanism_name, context)

	if Session.intercept_host_mechanism_change(mechanism_name, context) then
		return
	end

	local result = func(self, mechanism_name, context)

	Session.host_mechanism_changed()

	return result
end)

mod:hook(MechanismManager, "leave_mechanism", function (func, self, ...)
	Session.flush_host_reset()

	return func(self, ...)
end)

mod:hook(MechanismManager, "wanted_transition", function (func, self)
	local next_state, state_context = func(self)

	return Session.route_mechanism_transition(next_state, state_context)
end)

mod:hook(LoadingManager, "no_level_needed", function (func, self)
	local result = func(self)

	Session.preparation_no_level_started()

	return result
end)

mod:hook(LoadingManager, "load_finished", function (func, self)
	if Session.preparation_load_finished() then
		return true
	end

	return func(self)
end)

mod:hook(MechanismManager, "trigger_event", function (func, self, event, ...)
	if event == "all_players_ready" then
		if Session.intercept_host_all_players_ready() or Preparation.intercept_all_players_ready() then
			return
		end
	end

	return func(self, event, ...)
end)

mod:hook(MechanismManager, "profile_changes_are_allowed", function (func, self)
	if Preparation.allows_profile_changes() or Session.loadout_changes_allowed() then
		return true
	end

	return func(self)
end)

mod:hook(ConnectionManager, "send_rpc_server", function (func, self, rpc_name, ...)
	if rpc_name == "rpc_notify_profile_changed" and ProfileUpdates.intercept_client_notification(...) then
		return
	end

	return func(self, rpc_name, ...)
end)

mod:hook(ProfileSynchronizerHost, "profile_changed", function (func, self, peer_id, local_player_id)
	if ProfileUpdates.intercept_host_profile_change(self, peer_id, local_player_id) then
		return
	end

	return func(self, peer_id, local_player_id)
end)

mod:hook(LocalMechanismVerificationState, "rpc_check_mechanism_reply", function (func, self, channel_id, mechanism_matched, reply_data)
	local captured = Session.capture_mechanism_reply(channel_id, mechanism_matched, reply_data)

	if not captured then
		mechanism_matched = false
		reply_data = "invalid_realms_context"
	end

	return func(self, channel_id, mechanism_matched, reply_data)
end)

mod:hook(CLASS.StateMainMenu, "update", function (func, self, main_dt, main_t)
	local next_state, state_context = Session.poll_main_menu_transition()

	if next_state then
		return next_state, state_context
	end

	return func(self, main_dt, main_t)
end)

mod.update = function ()
	SessionControl.update()
	Session.update()
	GameplayControl.update()
	Chat.update()
	ProfileUpdates.update()
	LoadoutChanges.update()
	Workarounds.update()
end

mod:command("realms_status", mod:localize("command_status_description"), function ()
	local lines = Session.status_lines()

	for i = 1, #lines do
		mod:echo(lines[i])
	end
end)

mod.on_setting_changed = function (setting_id)
	if setting_id == "bot_fill_target" then
		BotBackfill.apply_settings(Session)

		return
	end
	if setting_id == "allow_in_mission_loadout_changes" then
		Preparation.server_settings_changed()
		GameplayControl.broadcast_server_settings()

		return
	end

	if setting_id ~= "private_mode" and setting_id ~= "max_players" and setting_id ~= "server_password" then
		return
	end

	local applied, apply_error = Session.apply_settings()

	if not applied then
		mod:error("%s %s", mod:localize("settings_apply_failed"), apply_error)
	end
end
