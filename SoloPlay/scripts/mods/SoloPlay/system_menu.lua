local mod = get_mod("SoloPlay")
local MatchmakingConstants = require("scripts/settings/network/matchmaking_constants")
local SystemView = require("scripts/ui/views/system_view/system_view")

local HOST_TYPES = MatchmakingConstants.HOST_TYPES
local REALMS_OWNER = "_realms_system_menu_owner"
local SOLOPLAY_OWNER = "_soloplay_system_menu_owner"

local function is_training_grounds()
	local game_mode_manager = Managers.state.game_mode

	if not game_mode_manager then
		return false
	end

	local game_mode_name = game_mode_manager:game_mode_name()

	return game_mode_name == "training_grounds" or game_mode_name == "shooting_range"
end

local function exit_to_main_menu_validation()
	local game_mode_manager = Managers.state.game_mode

	if not game_mode_manager then
		return false
	end

	local game_mode_name = game_mode_manager:game_mode_name()
	local is_onboarding = game_mode_name == "prologue" or game_mode_name == "prologue_hub"
	local is_hub = game_mode_name == "hub"
	local is_training = game_mode_name == "training_grounds" or game_mode_name == "shooting_range"
	local host_type = Managers.multiplayer_session:host_type()
	local can_show = is_onboarding or is_hub or is_training or host_type == HOST_TYPES.singleplay
	local is_leaving_game = game_mode_manager:game_mode_state() == "leaving_game"
	local is_in_matchmaking = Managers.data_service.social:is_in_matchmaking()

	return can_show, is_leaving_game or is_in_matchmaking
end

local function standard_leave_validation()
	if is_training_grounds() then
		return false
	end

	local host_type = Managers.multiplayer_session:host_type()
	local mechanism = Managers.mechanism:current_mechanism()
	local mechanism_data = mechanism and mechanism:mechanism_data()

	if host_type == HOST_TYPES.singleplay then
		return true
	end
	if host_type == HOST_TYPES.mission_server then
		return mechanism_data and not mechanism_data.havoc_data
	end

	return false
end

local function havoc_leave_validation()
	if is_training_grounds() then
		return false
	end

	local host_type = Managers.multiplayer_session:host_type()
	local mechanism = Managers.mechanism:current_mechanism()
	local mechanism_data = mechanism and mechanism:mechanism_data()

	if host_type == HOST_TYPES.singleplay then
		return false
	end
	if host_type == HOST_TYPES.mission_server then
		return mechanism_data and mechanism_data.havoc_data
	end

	return false
end

local function transform_default(source)
	local transformed = {}
	local leave_mission_occurrence = 0

	for i = 1, #source do
		local entry = source[i]

		if entry.text == "loc_exit_to_main_menu_display_name" and not entry[SOLOPLAY_OWNER] then
			entry = table.clone(entry)
			entry[SOLOPLAY_OWNER] = true
			entry.validation_function = exit_to_main_menu_validation
		elseif entry.text == "loc_leave_mission_display_name" then
			leave_mission_occurrence = leave_mission_occurrence + 1

			if not entry[REALMS_OWNER] and not entry[SOLOPLAY_OWNER] then
				entry = table.clone(entry)
				entry[SOLOPLAY_OWNER] = true
				entry.validation_function = leave_mission_occurrence == 1 and standard_leave_validation or havoc_leave_validation
			end
		end

		transformed[i] = entry
	end

	return transformed
end

mod:hook(SystemView, "_setup_content_widgets", function (func, self, content, scenegraph_id, callback_name)
	if not content or not content.default then
		return func(self, content, scenegraph_id, callback_name)
	end

	local transformed_content = table.clone(content)

	transformed_content.default = transform_default(content.default)

	return func(self, transformed_content, scenegraph_id, callback_name)
end)
