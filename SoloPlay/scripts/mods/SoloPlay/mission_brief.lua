local mod = get_mod("SoloPlay")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local GameModeSettings = require("scripts/settings/game_mode/game_mode_settings")
local ProfileUtils = require("scripts/utilities/profile_utils")
local BotSpawning = require("scripts/managers/bot/bot_spawning")
local PlayerUnitSpawnManager = require("scripts/managers/player/player_unit_spawn_manager")
local MissionIntroView = require("scripts/ui/views/mission_intro_view/mission_intro_view")
local ConstantElementLoading = require("scripts/ui/constant_elements/elements/loading/constant_element_loading")
local HOST_TYPES = MatchmakingConstants.HOST_TYPES

mod:hook(ConstantElementLoading, "_update_state_views", function (func, self, state_view_settings)
	for i = 1, #state_view_settings do
		local settings = state_view_settings[i]
		if settings.view_name == "mission_intro_view" and not settings.__soloplay_modified then
			local orig_validation_func = settings.validation_func
			-- scripts/ui/constant_elements/elements/loading/constant_element_loading.lua
			settings.validation_func = function ()
				local host_type = Managers.multiplayer_session:host_type()
				if not mod:get("mission_brief_enabled") or host_type ~= HOST_TYPES.singleplay then
					return orig_validation_func()
				end

				if Managers.ui:view_active("lobby_view") then
					return false
				end
				if host_type ~= HOST_TYPES.singleplay then
					return false
				end

				local mechanism_state = Managers.mechanism:mechanism_state()
				if mechanism_state == "adventure_selected" then
					return false
				end
				if mechanism_state == "expedition_selected" then
					return false
				end

				if mechanism_state == "adventure" or mechanism_state == "expedition" then
					local unit_spawner_manager = Managers.state.unit_spawner
					local fully_hot_join_synced = unit_spawner_manager and unit_spawner_manager:fully_hot_join_synced()
					if not fully_hot_join_synced then
						return true, {
							loading_icon = true,
							loading_icon_delay = 3,
						}
					end
				end

				local mechanism_data = Managers.mechanism:mechanism_data()
				local mission_name = mechanism_data and mechanism_data.mission_name
				if mission_name == nil then
					return false
				end

				local mission = MissionTemplates[mission_name]
				local mission_brief_vo = mission and mission.mission_brief_vo
				if not mission_brief_vo or not mission_brief_vo.vo_events then
					return false
				end

				return true
			end
			settings.__soloplay_modified = true
			break
		end
	end

	return func(self, state_view_settings)
end)

local function _get_initial_bot_seed(mechanism_data)
	if not mechanism_data then
		return
	end
	mechanism_data.__soloplay_initial_bot_seed = mechanism_data.__soloplay_initial_bot_seed or math.random(1, 2147483646)
	return mechanism_data.__soloplay_initial_bot_seed
end

local function _get_bot_config_identifier(challenge)
	if challenge == nil then
		return
	end

	if challenge >= 5 then
		return "high"
	elseif challenge == 3 or challenge == 4 then
		return "medium"
	else
		return "low"
	end
end

local function _initial_bot_profile_names(mechanism_data)
	local initial_bot_seed = _get_initial_bot_seed(mechanism_data)
	if not initial_bot_seed then
		return
	end

	local mission = MissionTemplates[mechanism_data.mission_name]
	local game_mode_name = mission and mission.game_mode_name
	local settings = game_mode_name and GameModeSettings[game_mode_name]
	if not settings or not settings.bot_backfilling_allowed then
		return
	end

	local max_players = GameParameters.max_players
	local num_players = table.size(Managers.player:players())
	local max_bots = settings.max_bots or 0
	local desired_bot_count = math.clamp(max_players - num_players, 0, max_bots)
	if desired_bot_count <= 0 then
		return
	end

	local bot_ids = {
		1,
		2,
		3,
		4,
		5,
		6,
	}

	table.shuffle(bot_ids, initial_bot_seed)

	local bot_config_identifier = _get_bot_config_identifier(mechanism_data.challenge)
	if not bot_config_identifier then
		return
	end

	local profile_names = {}
	for i = 1, desired_bot_count do
		profile_names[i] = bot_config_identifier .. "_bot_" .. bot_ids[i]
	end

	return profile_names
end

local function _fake_bot_player(profile, index)
	return {
		breed_name = function ()
			return profile.archetype.breed
		end,
		is_human_controlled = function ()
			return false
		end,
		profile = function ()
			return profile
		end,
		slot = function ()
			return index + 1
		end,
		unique_id = function ()
			return "soloplay_mission_brief_bot_" .. index
		end,
	}
end

mod:hook_safe(MissionIntroView, "_assign_player_slots", function (self)
	local mechanism_data = Managers.mechanism:mechanism_data()
	local profile_names = _initial_bot_profile_names(mechanism_data)
	if not mod:get("mission_brief_enabled") or not profile_names then
		return
	end

	for i = 1, #profile_names do
		local profile_name = profile_names[i]
		local profile = ProfileUtils.get_bot_profile(profile_name)
		profile.identifier = profile_name

		local player = _fake_bot_player(profile, i)
		local unique_id = player:unique_id()
		local slot_id = self:_player_slot_id(unique_id)
		if not slot_id then
			slot_id = self:_get_free_slot_id(player)
			local slot = self._spawn_slots[slot_id]
			if slot then
				self:_assign_player_to_slot(player, slot)
			end
		end
	end
end)

mod:hook(PlayerUnitSpawnManager, "_handle_initial_bot_spawning", function (func, self)
	local mechanism_data = Managers.mechanism:mechanism_data()
	local initial_bot_seed = _get_initial_bot_seed(mechanism_data)
	if not initial_bot_seed then
		return func(self)
	end

	local initial_bot_id_table = {
		1,
		2,
		3,
		4,
		5,
		6,
	}

	table.shuffle(initial_bot_id_table, initial_bot_seed)

	while self._queued_bots_n > 0 do
		local bot_id = initial_bot_id_table[1]
		local bot_config_identifier = BotSpawning.get_bot_config_identifier()
		local profile_name = bot_config_identifier .. "_bot_" .. bot_id

		BotSpawning.spawn_bot_character(profile_name)
		table.remove(initial_bot_id_table, 1)

		self._queued_bots_n = self._queued_bots_n - 1
	end
end)
