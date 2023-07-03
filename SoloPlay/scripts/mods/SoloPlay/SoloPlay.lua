local mod = get_mod("SoloPlay")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local DifficultyManager = require("scripts/managers/difficulty/difficulty_manager")
local PickupSystem = require("scripts/extension_systems/pickups/pickup_system")
local PickupSettings = require("scripts/settings/pickup/pickup_settings")
local HOST_TYPES = MatchmakingConstants.HOST_TYPES
local DISTRIBUTION_TYPES = PickupSettings.distribution_types

mod.is_soloplay = function()
	if not Managers.state.game_mode then
		return false
	end
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	if game_mode_name == "training_grounds" or game_mode_name == "shooting_range" then
		return false
	end
	if not Managers.multiplayer_session then
		return false
	end
	local host_type = Managers.multiplayer_session:host_type()
	return host_type == HOST_TYPES.singleplay
end

mod.open_inventory = function()
	if Managers.ui:chat_using_input() then
		return
	end
	if not mod.is_soloplay() then
		return
	end
	local active = false
	local active_views = Managers.ui:active_views()
	for _, active_view in pairs(active_views) do
		if active_view == "inventory_background_view" then
			active = true
		end
	end
	if active then
		return
	end
	Managers.ui:open_view("inventory_background_view", nil, nil, nil, nil, nil)
end

mod:hook_require("scripts/ui/views/system_view/system_view_content_list", function(instance)
	if not mod:is_enabled() then
		return
	end
	for _, item in ipairs(instance.default) do
		if item.text == "loc_exit_to_main_menu_display_name" then
			item.validation_function = function ()
				local game_mode_manager = Managers.state.game_mode
				if not game_mode_manager then
					return false
				end

				local game_mode_name = game_mode_manager:game_mode_name()
				local is_onboarding = game_mode_name == "prologue" or game_mode_name == "prologue_hub"
				local is_hub = game_mode_name == "hub"
				local is_training_grounds = game_mode_name == "training_grounds" or game_mode_name == "shooting_range"
				local host_type = Managers.multiplayer_session:host_type()
				local can_exit = is_onboarding or is_hub or is_training_grounds or host_type == HOST_TYPES.singleplay
				local is_in_matchmaking = Managers.data_service.social:is_in_matchmaking()

				return can_exit, is_in_matchmaking
			end
		elseif item.text == "loc_leave_mission_display_name" then
			item.validation_function = function ()
				local game_mode_manager = Managers.state.game_mode
				local is_training_grounds = false
				if game_mode_manager then
					local game_mode_name = game_mode_manager:game_mode_name()
					is_training_grounds = game_mode_name == "training_grounds" or game_mode_name == "shooting_range"
				end
				local host_type = Managers.multiplayer_session:host_type()
				local in_mission = host_type == HOST_TYPES.mission_server or host_type == HOST_TYPES.singleplay
				return not is_training_grounds and in_mission
			end
		end
	end
end)

mod:hook(DifficultyManager, "friendly_fire_enabled", function(func, self, target_is_player, target_is_minion)
	local ret = func(self, target_is_player, target_is_minion)
	if mod.is_soloplay() and mod:get("friendly_fire_enabled") then
		return true
	end
	return ret
end)

mod:hook(PickupSystem, "_spawn_spread_pickups", function(func, self, distribution_type, pickup_pool, seed)
	if distribution_type == DISTRIBUTION_TYPES.side_mission and mod:get("random_side_mission_seed") then
		self._seed = func(self, distribution_type, pickup_pool, self._seed)
		return self._seed
	end
	return func(self, distribution_type, pickup_pool, seed)
end)

local function in_hub_or_psykhanium()
	if not Managers.state or not Managers.state.game_mode then
		return false
	end
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	return (game_mode_name == "hub" or game_mode_name == "prologue_hub" or game_mode_name == "shooting_range")
end

mod:command("solo", mod:localize("solo_command_desc"), function()
	if not in_hub_or_psykhanium() and not mod.is_soloplay() then
		mod:echo(mod:localize("msg_not_in_hub_or_mission"))
		return
	end

	local multiplayer_session_manager = Managers.multiplayer_session
	local mechanism_manager = Managers.mechanism
	local resistance = DangerSettings.by_index[mod:get("choose_difficulty")].expected_resistance
	local mission_context = {
		mission_name = mod:get("choose_mission"),
		challenge = mod:get("choose_difficulty"),
		resistance = resistance,
		circumstance_name = mod:get("choose_circumstance"),
		side_mission = mod:get("choose_side_mission"),
	}
	local mission_settings = MissionTemplates[mission_context.mission_name]
	local mechanism_name = mission_settings.mechanism_name

	multiplayer_session_manager:reset("Hosting SoloPlay session")
	multiplayer_session_manager:boot_singleplayer_session()

	mod:echo(mod:localize("msg_starting_soloplay"))
	Promise.until_true(function()
		return multiplayer_session_manager._session_boot and multiplayer_session_manager._session_boot.leaving_game_session
	end):next(function()
		mechanism_manager:change_mechanism(mechanism_name, mission_context)
		mechanism_manager:trigger_event("all_players_ready")
	end)
end)
