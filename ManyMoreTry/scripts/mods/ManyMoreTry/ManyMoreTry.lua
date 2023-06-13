local mod = get_mod("ManyMoreTry")
local MissionBoardViewDefinitions = require("scripts/ui/views/mission_board_view/mission_board_view_definitions")
local DefaultViewInputSettings = require("scripts/settings/input/default_view_input_settings")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local MissionObjectiveTemplates = require("scripts/settings/mission_objective/mission_objective_templates")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")

local locks = mod:persistent_table("locks")

mod.on_enabled = function(initial_call)
	DefaultViewInputSettings.aliases.mmt_save_mission = {
		"keyboard_r",
		"xbox_controller_left_shoulder",
		"ps4_controller_l1",
		description = "",
		bindable = false,
	}
	DefaultViewInputSettings.settings.mmt_save_mission = {
		key_alias = "mmt_save_mission",
		type = "pressed",
	}

	local exist = false
	for _, value in ipairs(MissionBoardViewDefinitions.legend_inputs) do
		if value.input_action == "mmt_save_mission" then
			exist = true
			break
		end
	end
	if not exist then
		table.insert(MissionBoardViewDefinitions.legend_inputs, {
			on_pressed_callback = "__mod_mmt_save_callback",
			input_action = "mmt_save_mission",
			display_name = "loc_mod_mmt_save",
			alignment = "right_alignment",
			visibility_function = function(mission_board_view)
				if mission_board_view._selected_mission then
					return true
				end
				return false
			end
		})
	end
end

mod.on_disabled = function(initial_call)
	table.array_remove_if(MissionBoardViewDefinitions.legend_inputs, function(v)
		return v.input_action == "mmt_save_mission"
	end)
end

local function in_hub()
	if not Managers.state or not Managers.state.game_mode then
		return false
	end
	local game_mode_name = Managers.state.game_mode:game_mode_name()
	return game_mode_name == "hub"
end

local function get_start(start)
	local start_str = tostring(start)
	start_str = string.sub(start_str, 1, string.len(start_str) - 3)
	return tonumber(start_str)
end

local function get_mission_name(mission, name_key, circumstance_key)
	local name_parts = {}
	if mission[name_key] then
		local mission_settings = MissionTemplates[mission[name_key]]
		if mission_settings then
			local localized_name = Localize(mission_settings.mission_name)
			table.insert(name_parts, localized_name)
		end
	end

	local danger_settings = DangerSettings.by_index[mission.challenge]
	table.insert(name_parts, Localize(danger_settings.display_name))

	local circumstance_name = nil
	if mission[circumstance_key] and mission[circumstance_key] ~= "default" then
		if CircumstanceTemplates[mission[circumstance_key]].ui then
			circumstance_name = Localize(CircumstanceTemplates[mission[circumstance_key]].ui.display_name)
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

local function get_start_line(now, mission)
	if mission.expired then
		return mod:localize("text_expired")
	end
	local start = mission.start
	if start then
		if start > now then
			start = now
		end
		local delta = (now - start) / 60 / 60
		local fmt = string.gsub(mod:localize("text_started"), "#", "%%g")
		local delta_str = string.format(fmt, string.format("%.1f", delta))
		return delta_str
	end
	return ""
end

local function get_mission_line(now, index, mission)
	local start_line = get_start_line(now, mission)
	if start_line then
		return "{#color(0,192,255)}" .. tostring(index) .. "{#reset()} " .. mission.display_name .. "\n   " .. start_line
	end
	return "{#color(0,192,255)}" .. tostring(index) .. "{#reset()} " .. mission.display_name
end

mod:hook_safe("MissionBoardView", "init", function(self, settings)
	self.__mod_mmt_save_callback = function(self)
		local saved_mission = mod:get("_saved_mission") or {}
		local name = get_mission_name(self._selected_mission, "map", "circumstance")
		local exist = false
		for _, mission in ipairs(saved_mission) do
			if mission.id == self._selected_mission.id then
				exist = true
				break
			end
		end
		if exist then
			mod:notify(mod:localize("msg_already_saved") .. "\n" .. name)
			return
		end
		table.insert(saved_mission, {
			id = self._selected_mission.id,
			display_name = name,
			start = get_start(self._selected_mission.start)
		})
		mod:set("_saved_mission", saved_mission, false)
		mod:notify(mod:localize("msg_saved") .. "\n" .. name)
	end
end)

local function go_match(mission)
	local private = true
	if mod:get("private_game") then
		local num_members = 0
		if GameParameters.prod_like_backend then
			num_members = Managers.party_immaterium:num_other_members()
		end
		if num_members < 1 then
			mod:echo(mod:localize("msg_not_in_party"))
			return
		end
	else
		private = false
	end
	mod:echo(mod:localize("msg_on_your_way_to") .. mission.display_name)
	Managers.party_immaterium:wanted_mission_selected(mission.id, private)
end

mod:command("mmt", mod:localize("cmd_main"), function(idx_str)
	local now = tonumber(os.time())
	local saved_mission = mod:get("_saved_mission") or {}
	if not idx_str then
		if #saved_mission < 1 then
			mod:echo(mod:localize("msg_no_saved_mission"))
			return
		end
		local mission_info = {}
		local mission_text = mod:localize("msg_saved_mission") .. "\n"
		for index, mission in ipairs(saved_mission) do
			table.insert(mission_info, get_mission_line(now, index, mission))
		end
		mission_text = mission_text .. table.concat(mission_info, "\n")
		mission_text = mission_text .. "\n" .. mod:localize("msg_help_queue")
		mission_text = mission_text .. "\n" .. mod:localize("msg_help_del")
		mission_text = mission_text .. "\n" .. mod:localize("msg_help_export")
		mod:echo(mission_text)
		return
	end
	local idx = tonumber(idx_str)
	if not idx or idx < 1 or #saved_mission < idx then
		mod:echo(mod:localize("msg_invalid_number"))
		return
	end
	local mission = saved_mission[idx]
	if mission.expired then
		mod:echo(mod:localize("msg_expired_safe_to_delete"))
		return
	end

	if locks.match then
		mod:echo(mod:localize("msg_command_busy"))
		return
	end
	locks.match = true
	Managers.data_service.mission_board:fetch_mission(mission.id):next(function(data)
		if not in_hub() then
			mod:echo(mod:localize("msg_not_in_hub"))
			locks.match = nil
			return
		end
		if not data.mission then
			mod:echo(mod:localize("msg_unknown_err"))
			locks.match = nil
			return
		end
		go_match(mission)
		locks.match = nil
	end):catch(function(e)
		mod:dump(e, "mmt_fetch_error", 3)
		if e and e.code and tonumber(e.code) == 404 then
			mod:echo(mod:localize("msg_expired_safe_to_delete"))
			mission.expired = true
		else
			mod:echo(mod:localize("msg_unknown_err"))
		end
		mod:set("_saved_mission", saved_mission, false)
		locks.match = nil
	end)
end)

mod:command("mmtdel", mod:localize("cmd_del"), function(idx_str)
	if not idx_str then
		mod:echo(mod:localize("msg_help_del"))
		return
	end
	local saved_mission = mod:get("_saved_mission") or {}
	local idx = tonumber(idx_str)
	if not idx or idx < 1 or #saved_mission < idx then
		mod:echo(mod:localize("msg_invalid_number"))
		return
	end
	local name = saved_mission[idx].display_name
	table.remove(saved_mission, idx)
	mod:set("_saved_mission", saved_mission, false)
	mod:echo(mod:localize("msg_removed") .. name)
end)

mod:command("mmtexport", mod:localize("cmd_export"), function()
	local now = tonumber(os.time())
	local saved_mission = mod:get("_saved_mission") or {}
	local text_parts = {}
	for _, mission in ipairs(saved_mission) do
		if not mission.expired then
			local start_line = get_start_line(now, mission)
			if start_line then
				table.insert(text_parts, mission.display_name .. " · " .. start_line)
			else
				table.insert(text_parts, mission.display_name)
			end
			table.insert(text_parts, "/mmtimport " .. mission.id)
		end
	end
	if #text_parts < 1 then
		mod:echo(mod:localize("msg_nothing_to_export"))
		return
	end
	local text = table.concat(text_parts, "\n")
	if not Clipboard.put(text) then
		mod:echo(mod:localize("msg_copy_err"))
	end
	mod:echo(mod:localize("msg_data_copied"))
end)

mod:command("mmtimport", mod:localize("cmd_import"), function(id)
	if not id then
		mod:echo(mod:localize("msg_help_import"))
		return
	end
	local saved_mission = mod:get("_saved_mission") or {}

	if locks.import then
		mod:echo(mod:localize("msg_command_busy"))
		return
	end
	locks.import = true
	Managers.data_service.mission_board:fetch_mission(id):next(function(data)
		if not data.mission then
			mod:echo(mod:localize("msg_import_invalid_mission"))
			locks.import = nil
			return
		end
		local name = get_mission_name(data.mission, "map", "circumstance")
		local exist = false
		for _, mission in ipairs(saved_mission) do
			if mission.id == id then
				exist = true
				break
			end
		end
		if exist then
			mod:echo(mod:localize("msg_already_saved") .. name)
			locks.import = nil
			return
		end
		table.insert(saved_mission, {
			id = id,
			display_name = name,
			start = get_start(data.mission.start)
		})
		mod:set("_saved_mission", saved_mission, false)
		mod:echo(mod:localize("msg_saved") .. name)
		locks.import = nil
	end):catch(function(e)
		mod:echo(mod:localize("msg_import_invalid_mission"))
		locks.import = nil
	end)
end)
