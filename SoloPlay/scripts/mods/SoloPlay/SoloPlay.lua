local mod = get_mod("SoloPlay")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local DifficultyManager = require("scripts/managers/difficulty/difficulty_manager")
local GameModeManager = require("scripts/managers/game_mode/game_mode_manager")
local PickupSystem = require("scripts/extension_systems/pickups/pickup_system")
local PickupSettings = require("scripts/settings/pickup/pickup_settings")
local SoloPlaySettings = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/SoloPlaySettings")
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

local function check_mission_giver(mission, check_giver)
	local mission_info = MissionTemplates[mission]
	if not mission_info then
		return nil
	end
	local mission_brief_vo = mission_info.mission_brief_vo
	if not mission_brief_vo then
		return nil
	end
	local mission_giver_packs = mission_brief_vo.mission_giver_packs
	if not mission_giver_packs then
		return nil
	end
	local valid = {}
	for giver, _ in pairs(mission_giver_packs) do
		table.insert(valid, giver)
	end
	table.sort(valid)
	table.insert(valid, 1, "default")
	if table.array_contains(valid, check_giver) then
		return nil
	end
	return valid
end

local function get_mission_context()
	local mission_name = mod:get("choose_mission")
	local resistance = DangerSettings.by_index[mod:get("choose_difficulty")].expected_resistance
	local mission_context = {
		mission_name = mission_name,
		challenge = mod:get("choose_difficulty"),
		resistance = resistance,
		circumstance_name = mod:get("choose_circumstance"),
		side_mission = mod:get("choose_side_mission"),
	}
	local mission_giver = mod:get("choose_mission_giver")
	if mission_giver ~= "default" then
		local giver_check_result = check_mission_giver(mission_name, mission_giver)
		if giver_check_result == nil then
			mission_context.mission_giver_vo_override = mission_giver
		end
	end
	for map_name, override in pairs(SoloPlaySettings.context_override) do
		if mission_context.mission_name == map_name then
			for key, settings in pairs(override) do
				if not settings.default or (settings.default and mission_context[key] == settings.default) then
					mission_context[key] = settings.value
				end
			end
		end
	end
	return mission_context
end

mod:hook_require("scripts/ui/views/system_view/system_view_content_list", function(instance)
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
				local can_show = is_onboarding or is_hub or is_training_grounds or host_type == HOST_TYPES.singleplay
				local is_leaving_game = game_mode_manager:game_mode_state() == "leaving_game"
				local is_in_matchmaking = Managers.data_service.social:is_in_matchmaking()
				local is_disabled = is_leaving_game or is_in_matchmaking

				return can_show, is_disabled
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

mod:hook(GameModeManager, "hotkey_settings", function(func, self)
	local ret = table.clone(func(self))
	if self:game_mode_name() == "coop_complete_objective" and mod.is_soloplay() then
		ret.hotkeys["hotkey_inventory"] = "inventory_background_view"
		ret.lookup["inventory_background_view"] = "hotkey_inventory"
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

local main_menu_want_solo_play = false

mod:hook(CLASS.StateMainMenu, "update", function(func, self, main_dt, main_t)
	if self._continue and not self:_waiting_for_profile_synchronization() then
		if main_menu_want_solo_play then
			main_menu_want_solo_play = false

			local mission_context = get_mission_context()
			local mission_settings = MissionTemplates[mission_context.mission_name]
			local mechanism_name = mission_settings.mechanism_name

			mod:echo(mod:localize("msg_starting_soloplay"))
			Managers.multiplayer_session:boot_singleplayer_session()
			Managers.mechanism:change_mechanism(mechanism_name, mission_context)
			Managers.mechanism:trigger_event("all_players_ready")

			local next_state, state_context = Managers.mechanism:wanted_transition()
			return next_state, state_context
		end
	elseif self._continue then
		self._continue = false
	end

	local next_state, next_state_params = func(self, main_dt, main_t)
	return next_state, next_state_params
end)

local function in_hub_or_psykhanium()
	if not Managers.state or not Managers.state.game_mode then
		return false
	end
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	return (game_mode_name == "hub" or game_mode_name == "prologue_hub" or game_mode_name == "shooting_range")
end

local function on_main_menu()
	if not Managers.ui then
		return false
	end
	return Managers.ui:view_active("main_menu_view")
end

mod:command("solo", mod:localize("solo_command_desc"), function()
	if not in_hub_or_psykhanium() and not mod.is_soloplay() and not on_main_menu() then
		mod:echo(mod:localize("msg_not_in_hub_or_mission"))
		return
	end
	local mission_giver = mod:get("choose_mission_giver")
	local giver_check_result = check_mission_giver(mod:get("choose_mission"), mission_giver)
	if giver_check_result then
		local valid_givers_localized = {}
		for idx, giver in ipairs(giver_check_result) do
			if giver == "default" then
				valid_givers_localized[idx] = mod:localize("default_text")
			else
				valid_givers_localized[idx] = mod:localize("loc_mission_giver_" .. giver)
			end
		end
		local valid_givers_text = table.concat(valid_givers_localized, ", ")
		mod:echo(mod:localize("msg_not_valid_mission_giver") .. valid_givers_text)
		return
	end

	if on_main_menu() then
		main_menu_want_solo_play = true
		Managers.event:trigger("event_state_main_menu_continue")
		return
	end

	local mission_context = get_mission_context()
	local mission_settings = MissionTemplates[mission_context.mission_name]
	local mechanism_name = mission_settings.mechanism_name

	Managers.multiplayer_session:reset("Hosting SoloPlay session")
	Managers.multiplayer_session:boot_singleplayer_session()

	mod:echo(mod:localize("msg_starting_soloplay"))
	Promise.until_true(function()
		return Managers.multiplayer_session._session_boot and Managers.multiplayer_session._session_boot.leaving_game_session
	end):next(function()
		Managers.mechanism:change_mechanism(mechanism_name, mission_context)
		Managers.mechanism:trigger_event("all_players_ready")
	end)
end)
