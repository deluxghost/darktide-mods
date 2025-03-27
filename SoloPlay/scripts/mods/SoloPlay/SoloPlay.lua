local mod = get_mod("SoloPlay")
local Promise = require("scripts/foundation/utilities/promise")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local DifficultyManager = require("scripts/managers/difficulty/difficulty_manager")
local GameModeManager = require("scripts/managers/game_mode/game_mode_manager")
local PacingManager = require("scripts/managers/pacing/pacing_manager")
local PacingTemplates = require("scripts/managers/pacing/pacing_templates")
local RoamerPacing = require("scripts/managers/pacing/roamer_pacing/roamer_pacing")
local PickupSystem = require("scripts/extension_systems/pickups/pickup_system")
local PickupSettings = require("scripts/settings/pickup/pickup_settings")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local WwiseGameSyncSettings = require("scripts/settings/wwise_game_sync/wwise_game_sync_settings")
local HavocManager = require("scripts/managers/havoc/havoc_manager")
local SoloPlaySettings = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/SoloPlaySettings")
mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/havoc")

local HOST_TYPES = MatchmakingConstants.HOST_TYPES
local DISTRIBUTION_TYPES = PickupSettings.distribution_types

mod.on_all_mods_loaded = function ()
	mod.load_package("packages/ui/views/end_player_view/end_player_view")
end

mod.is_soloplay = function ()
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

mod.load_package = function (package_name)
	if not Managers.package:is_loading(package_name) and not Managers.package:has_loaded(package_name) then
		Managers.package:load(package_name, "solo_play", nil, true)
	end
end

mod.gen_normal_mission_context = function ()
	local mission_name = mod:get("choose_mission")
	local resistance = DangerSettings[mod:get("choose_difficulty")].expected_resistance
	local mission_context = {
		mission_name = mission_name,
		challenge = mod:get("choose_difficulty"),
		resistance = resistance,
		circumstance_name = mod:get("choose_circumstance"),
		side_mission = mod:get("choose_side_mission"),
	}
	local mission_giver = mod:get("choose_mission_giver")
	if mission_giver ~= "default" then
		mission_context.mission_giver_vo_override = mission_giver
	end
	for map_name, override in pairs(SoloPlaySettings.context_override) do
		if mission_context.mission_name == map_name then
			for key, settings in pairs(override) do
				mission_context[key] = settings.value
			end
		end
	end
	return mission_context
end

mod.gen_havoc_mission_context = function ()
	local rank = mod:get("havoc_difficulty")
	local challenge, resistance
	if rank <= 10 then
		challenge = 3
		resistance = 3
	elseif rank >= 11 and rank <= 20 then
		challenge = 4
		resistance = 4
	elseif rank >= 21 and rank <= 30 then
		challenge = 5
		resistance = 4
	else
		challenge = 5
		resistance = 5
	end

	local mission = mod:get("havoc_mission")
	local faction = mod:get("havoc_faction")
	local circumstance1 = mod:get("havoc_circumstance1")
	local circumstance2 = mod:get("havoc_circumstance2")
	local theme_circumstance = mod:get("havoc_theme_circumstance")
	local difficulty_circumstance = mod:get("havoc_difficulty_circumstance")
	local theme = SoloPlaySettings.lookup.theme_of_circumstances[theme_circumstance]

	local chosen_circumstances_table = {}
	if circumstance1 ~= "default" then
		chosen_circumstances_table[#chosen_circumstances_table+1] = circumstance1
	end
	if circumstance2 ~= "default" and circumstance2 ~= circumstance1 then
		chosen_circumstances_table[#chosen_circumstances_table+1] = circumstance2
	end
	if theme_circumstance ~= "default" then
		chosen_circumstances_table[#chosen_circumstances_table+1] = theme_circumstance
	end
	if difficulty_circumstance ~= "default" then
		chosen_circumstances_table[#chosen_circumstances_table+1] = difficulty_circumstance
	end
	local chosen_circumstances = table.concat(chosen_circumstances_table, ":")

	local chosen_modifiers_table = {}
	for modifier_name in pairs(SoloPlaySettings.lookup.havoc_modifiers_max_level) do
		local modifier_id = NetworkLookup.havoc_modifiers[modifier_name]
		local level = mod:get("havoc_modifier_" .. modifier_name) or 0
		if level > 0 then
			chosen_modifiers_table[#chosen_modifiers_table+1] = string.format("%d.%d", modifier_id, level)
		end
	end
	local chosen_modifiers = table.concat(chosen_modifiers_table, ":")

	local data = string.format("%s;%d;%s;%s;%s;%s;%s;%s", mission, rank, theme, faction, chosen_circumstances, chosen_modifiers, challenge, resistance)

	local mission_context = {
		mission_name = mission,
		challenge = challenge,
		resistance = resistance,
		havoc_data = data,
	}
	local mission_giver = mod:get("havoc_mission_giver")
	if mission_giver ~= "default" then
		mission_context.mission_giver_vo_override = mission_giver
	end
	return mission_context
end

mod:hook_require("scripts/ui/views/system_view/system_view_content_list", function (instance)
	local leave_mission_occur = 1
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
		elseif item.text == "loc_leave_mission_display_name" and leave_mission_occur == 1 then
			item.validation_function = function ()
				local game_mode_manager = Managers.state.game_mode
				local is_training_grounds = false
				if game_mode_manager then
					local game_mode_name = game_mode_manager:game_mode_name()
					is_training_grounds = game_mode_name == "training_grounds" or game_mode_name == "shooting_range"
				end

				local host_type = Managers.multiplayer_session:host_type()
				local mechanism = Managers.mechanism:current_mechanism()
				local mechanism_data = mechanism and mechanism:mechanism_data()

				if is_training_grounds then
					return false
				end
				if host_type == HOST_TYPES.singleplay then
					return true
				end
				if host_type == HOST_TYPES.mission_server then
					return mechanism_data and not mechanism_data.havoc_data
				end
				return false
			end
			leave_mission_occur = leave_mission_occur + 1
		elseif item.text == "loc_leave_mission_display_name" and leave_mission_occur == 2 then
			item.validation_function = function ()
				local game_mode_manager = Managers.state.game_mode
				local is_training_grounds = false
				if game_mode_manager then
					local game_mode_name = game_mode_manager:game_mode_name()
					is_training_grounds = game_mode_name == "training_grounds" or game_mode_name == "shooting_range"
				end

				local host_type = Managers.multiplayer_session:host_type()
				local mechanism = Managers.mechanism:current_mechanism()
				local mechanism_data = mechanism and mechanism:mechanism_data()

				if is_training_grounds then
					return false
				end
				if host_type == HOST_TYPES.singleplay then
					return false
				end
				if host_type == HOST_TYPES.mission_server then
					return mechanism_data and mechanism_data.havoc_data
				end
				return false
			end
			leave_mission_occur = leave_mission_occur + 1
		end
	end
end)

-- HACK: allow starting game without modifiers
mod:hook(HavocManager, "_initialize_modifiers", function (func, self, havoc_data)
	local havoc_modifiers = havoc_data.modifiers
	if not havoc_modifiers or #havoc_modifiers < 1 or havoc_modifiers[1].level == nil then
		Log.info("HavocManager", "No modifiers found")
		return
	end
	return func(self, havoc_data)
end)

mod:hook(DifficultyManager, "friendly_fire_enabled", function (func, self, target_is_player, target_is_minion)
	local ret = func(self, target_is_player, target_is_minion)
	if mod.is_soloplay() and mod:get("friendly_fire_enabled") then
		return true
	end
	return ret
end)

mod:hook(GameModeManager, "hotkey_settings", function (func, self)
	local ret = table.clone(func(self))
	local game_mode_name = self:game_mode_name()
	if (game_mode_name == "coop_complete_objective" or game_mode_name == "survival") and mod.is_soloplay() then
		ret.hotkeys["hotkey_inventory"] = "inventory_background_view"
		ret.lookup["inventory_background_view"] = "hotkey_inventory"
	end
	return ret
end)

mod:hook(PacingManager, "init", function (func, self, world, nav_world, level_seed, pacing_control)
	func(self, world, nav_world, level_seed, pacing_control)
	local is_havoc = Managers.state.difficulty:get_parsed_havoc_data()
	if not is_havoc then
		if Managers.mechanism and Managers.mechanism._mechanism and Managers.mechanism._mechanism._mechanism_data then
			local mechanism_data = Managers.mechanism._mechanism._mechanism_data
			local pacing_override = SoloPlaySettings.pacing_override[mechanism_data.mission_name]
			if pacing_override and PacingTemplates[pacing_override] then
				local template = PacingTemplates[pacing_override]
				local game_mode_settings = Managers.state.game_mode:settings()
				local side_sub_faction_types = game_mode_settings.side_sub_faction_types
				local sub_faction_types = side_sub_faction_types[self._side_name]
				self._template = template
				self._roamer_pacing = RoamerPacing:new(nav_world, template.roamer_pacing_template, level_seed, sub_faction_types)
			end
		end
	end
end)

mod:hook(PickupSystem, "_spawn_spread_pickups", function (func, self, distribution_type, pickup_pool, seed)
	if distribution_type == DISTRIBUTION_TYPES.side_mission and mod:get("random_side_mission_seed") then
		self._seed = func(self, distribution_type, pickup_pool, self._seed)
		return self._seed
	end
	return func(self, distribution_type, pickup_pool, seed)
end)

local main_menu_want_solo_play = nil

mod:hook(CLASS.StateMainMenu, "update", function (func, self, main_dt, main_t)
	if self._continue and not self:_waiting_for_profile_synchronization() then
		if main_menu_want_solo_play then
			local mode = main_menu_want_solo_play
			main_menu_want_solo_play = nil

			local mission_context = {}
			if mode == "havoc" then
				mission_context = mod.gen_havoc_mission_context()
			else
				mission_context = mod.gen_normal_mission_context()
			end
			local mission_settings = MissionTemplates[mission_context.mission_name]
			local mechanism_name = mission_settings.mechanism_name

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

mod.can_start_game = function ()
	if in_hub_or_psykhanium() or mod.is_soloplay() or on_main_menu() then
		return true
	end
	return false
end

mod.start_game = function (mode)
	if not mod.can_start_game() then
		mod:notify(mod:localize("msg_not_in_hub_or_mission"))
		return
	end

	if on_main_menu() then
		main_menu_want_solo_play = mode
		Managers.event:trigger("event_state_main_menu_continue")
		return
	end

	local mission_context
	if mode == "havoc" then
		mission_context = mod.gen_havoc_mission_context()
	else
		mission_context = mod.gen_normal_mission_context()
	end
	local mission_settings = MissionTemplates[mission_context.mission_name]
	local mechanism_name = mission_settings.mechanism_name

	Managers.multiplayer_session:reset("Hosting SoloPlay session")
	Managers.multiplayer_session:boot_singleplayer_session()

	Promise.until_true(function ()
		if not Managers.multiplayer_session._session_boot or not Managers.multiplayer_session._session_boot.leaving_game_session then
			return false
		end
		return true
	end):next(function ()
		Managers.mechanism:change_mechanism(mechanism_name, mission_context)
		Managers.mechanism:trigger_event("all_players_ready")
	end)
end

mod:add_require_path("SoloPlay/scripts/mods/SoloPlay/soloplay_mod_view/soloplay_mod_view")
mod:register_view({
	view_name = "soloplay_mod_view",
	view_settings = {
		init_view_function = function (ingame_ui_context)
			return true
		end,
		state_bound = true,
		path = "SoloPlay/scripts/mods/SoloPlay/soloplay_mod_view/soloplay_mod_view",
		class = "SoloPlayModView",
		disable_game_world = false,
		load_always = true,
		load_in_hub = true,
		game_world_blur = 1.1,
		enter_sound_events = {
			UISoundEvents.system_menu_enter,
		},
		exit_sound_events = {
			UISoundEvents.system_menu_exit,
		},
		wwise_states = {
			options = WwiseGameSyncSettings.state_groups.options.ingame_menu,
		},
		context = {
			use_item_categories = false,
		},
	},
	view_transitions = {},
	view_options = {
		close_all = false,
		close_previous = false,
		close_transition_time = nil,
		transition_time = nil,
	},
})

mod.open_solo_view = function ()
	if not Managers.ui:view_instance("soloplay_mod_view") then
		Managers.ui:open_view("soloplay_mod_view", nil, nil, nil, nil, {})
	end
end

mod.keybind_open_solo_view = function ()
	if not Managers.ui:chat_using_input() then
		mod.open_solo_view()
	end
end

mod:command("solo", mod:localize("solo_command_desc"), function ()
	mod.open_solo_view()
end)
