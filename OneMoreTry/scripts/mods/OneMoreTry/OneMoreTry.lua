local mod = get_mod("OneMoreTry")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local MissionObjectiveTemplates = require("scripts/settings/mission_objective/mission_objective_templates")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")
local BackendUtilities = require("scripts/foundation/managers/backend/utilities/backend_utilities")

local locks = mod:persistent_table("locks")

function mod.on_game_state_changed(status, state_name)
	if state_name ~= "StateGameplay" then
		return
	end
	if status ~= "enter" then
		return
	end
	if Managers.mechanism and Managers.mechanism._mechanism and Managers.mechanism._mechanism._mechanism_data then
		local mechanism_data = Managers.mechanism._mechanism._mechanism_data
		if mechanism_data.backend_mission_id then
			mod:set("_last_mission_id", mechanism_data.backend_mission_id, false)
		end
	end
end

local function in_hub()
	if not Managers.state or not Managers.state.game_mode then
		return false
	end
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	return game_mode_name == "hub"
end

local function clear_mission()
	mod:echo(mod:localize("msg_no_valid_mission"))
	mod:set("_last_mission_id", nil, false)
end

local function get_mission_name(mission)
	local name_parts = {}
	if mission.map then
		local mission_settings = MissionTemplates[mission.map]
		if mission_settings then
			local localized_name = Localize(mission_settings.mission_name)
			table.insert(name_parts, localized_name)
		end
	end

	local danger_settings = DangerSettings.by_index[mission.challenge]
	table.insert(name_parts, Localize(danger_settings.display_name))

	local circumstance_name = nil
	if mission.circumstance and mission.circumstance ~= "default" then
		if CircumstanceTemplates[mission.circumstance].ui then
			circumstance_name = Localize(CircumstanceTemplates[mission.circumstance].ui.display_name)
		end
	end
	if circumstance_name then
		table.insert(name_parts, circumstance_name)
	end

	local side_mission_name = nil
	if mission.sideMission and mission.sideMission ~= "default" then
		if MissionObjectiveTemplates.side_mission.objectives[mission.sideMission] then
			local loc_key = MissionObjectiveTemplates.side_mission.objectives[mission.sideMission].header
			if loc_key then
				side_mission_name = Localize(loc_key)
			end
		end
	end
	if side_mission_name then
		table.insert(name_parts, side_mission_name)
	end

	return table.concat(name_parts, " · ")
end

mod:command("lm", mod:localize("lm_command_desc"), function()
	local mission_id = mod:get("_last_mission_id")
	if not mission_id then
		mod:echo(mod:localize("msg_no_valid_mission"))
		return
	end

	if locks.match then
		mod:echo(mod:localize("msg_command_busy"))
		return
	end
	locks.match = true
	Managers.data_service.mission_board:fetch_mission(mission_id):next(function(data)
		if not data.mission then
			clear_mission()
			locks.match = nil
			return
		end

		if not in_hub() then
			mod:echo(mod:localize("msg_not_in_hub"))
			locks.match = nil
			return
		end

		local num_members = 0
		if GameParameters.prod_like_backend then
			num_members = Managers.party_immaterium:num_other_members()
		end
		if num_members < 1 then
			mod:echo(mod:localize("msg_not_in_party"))
			locks.match = nil
			return
		end

		mod:dump(data,"mission",3)
		mod:echo(mod:localize("msg_on_your_way_to") .. get_mission_name(data.mission))
		Managers.party_immaterium:wanted_mission_selected(mission_id, true, BackendUtilities.prefered_mission_region)
		locks.match = nil
	end):catch(function(e)
		mod:dump(e, "omt_fetch_error", 3)
		clear_mission()
		locks.match = nil
	end)
end)
