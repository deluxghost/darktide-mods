local mod = get_mod("ManyMoreTry")
local MissionBoardViewDefinitions = require("scripts/ui/views/mission_board_view_pj/mission_board_view_definitions")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local MissionObjectiveTemplates = require("scripts/settings/mission_objective/mission_objective_templates")
local DangerSettings = require("scripts/settings/difficulty/danger_settings")
local MissionTypes = require("scripts/settings/mission/mission_types")
local BackendUtilities = require("scripts/foundation/managers/backend/utilities/backend_utilities")

local locks = mod:persistent_table("locks")

local function update_input_alias()
	if Managers.input and Managers.input._aliases and Managers.input._aliases.View then
		Managers.input._aliases.View._aliases["mmt_save_mission"] = Managers.input._aliases.View._default_aliases["mmt_save_mission"]
	end
end

mod:hook_require("scripts/settings/input/default_view_input_settings", function (DefaultViewInputSettings)
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
	update_input_alias()
end)

mod.on_all_mods_loaded = function ()
	update_input_alias()
end

mod.on_enabled = function ()
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
			visibility_function = function (mission_board_view)
				if mission_board_view._selected_mission_id and mission_board_view._selected_mission_id ~= "qp_mission_widget" then
					return true
				end
				return false
			end
		})
	end
end

mod.on_disabled = function ()
	table.array_remove_if(MissionBoardViewDefinitions.legend_inputs, function (v)
		return v.input_action == "mmt_save_mission"
	end)
end

mod.on_game_state_changed = function (status, state_name)
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

local function get_start(start)
	local start_str = tostring(start)
	start_str = string.sub(start_str, 1, string.len(start_str) - 3)
	return tonumber(start_str)
end

local function get_mission_difficulty(mission)
	for _, difficulty in ipairs(DangerSettings) do
		if difficulty.challenge == mission.challenge and difficulty.resistance == mission.resistance then
			return difficulty
		end
	end
	return nil
end

local function get_mission_name(mission, name_key, circumstance_key)
	local name_parts = {}
	if mission[name_key] then
		local mission_settings = MissionTemplates[mission[name_key]]
		if mission_settings then
			local localized_name = Localize(mission_settings.mission_name)
			table.insert(name_parts, localized_name)
			if mission_settings.mission_type and MissionTypes[mission_settings.mission_type] and MissionTypes[mission_settings.mission_type].name then
				local localized_type = Localize(MissionTypes[mission_settings.mission_type].name)
				table.insert(name_parts, localized_type)
			end
		end
	end

	local category_name = nil
	if mission.category == "narrative" then
		category_name = Localize("loc_story_mission_menu_access_button_text")
	end
	if mission.category == "story" then
		category_name = Localize("loc_player_journey_campaign")
	end
	if mission.category == "event" then
		category_name = Localize("loc_event_category_label")
	end
	if category_name then
		table.insert(name_parts, category_name)
	end

	local danger_settings = get_mission_difficulty(mission)
	if danger_settings then
		table.insert(name_parts, Localize(danger_settings.display_name))
	end

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

mod:hook_safe("MissionBoardView", "init", function (self, settings)
	self.__mod_mmt_save_callback = function (self)
		local saved_mission = mod:get("_saved_mission") or {}
		if self._selected_mission_id == "qp_mission_widget" then
			return
		end
		local selected_mission = self:_mission(self._selected_mission_id)
		if not selected_mission then
			return
		end
		local name = get_mission_name(selected_mission, "map", "circumstance")
		local exist = false
		for _, mission in ipairs(saved_mission) do
			if mission.id == self._selected_mission_id then
				exist = true
				break
			end
		end
		if exist then
			mod:notify(mod:localize("msg_already_saved") .. "\n" .. name)
			return
		end
		table.insert(saved_mission, {
			id = self._selected_mission_id,
			display_name = name,
			start = get_start(selected_mission.start)
		})
		mod:set("_saved_mission", saved_mission, false)
		mod:notify(mod:localize("msg_saved") .. "\n" .. name)
	end
end)

local function all_member_ready()
	local psych_ward = get_mod("psych_ward")
	if psych_ward then
		local myself = Managers.party_immaterium:get_myself()
		if myself:presence_name() ~= "hub" and myself:presence_name() ~= "training_grounds" and myself:presence_name() ~= "main_menu" then
			return false
		end
		return true
	end

	return Managers.party_immaterium:are_all_members_in_hub()
end

local function go_match(mission_id, mission_name, required_level)
	local player = Managers.player:local_player(1)
	local profile = player:profile()
	local current_level = profile.current_level or 0
	if current_level < required_level then
		mod:echo(mod:localize("msg_level_required"))
		return
	end
	if not all_member_ready() then
		mod:echo(mod:localize("msg_team_not_available"))
		return
	end

	local save_data = Managers.save:account_data()
	local mission_board = save_data.mission_board or {}
	local private = mission_board.private_matchmaking or false
	if private then
		local num_members = 0
		if GameParameters.prod_like_backend then
			num_members = Managers.party_immaterium:num_other_members()
		end
		if num_members < 1 then
			mod:echo(mod:localize("msg_not_in_party"))
			return
		end
	end
	mod:echo(mod:localize("msg_on_your_way_to") .. mission_name)
	Managers.party_immaterium:wanted_mission_selected(mission_id, private, BackendUtilities.prefered_mission_region)
end

local function mmt_main_command(idx_str)
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

	local mission_id = "00000000-0000-0000-0000-000000000000"
	local mission = nil
	local loc_expire_msg = ""
	if idx_str == "last" then
		mission_id = mod:get("_last_mission_id") or mission_id
		loc_expire_msg = "msg_no_valid_last_mission"
	elseif #idx_str == 36 then
		mission_id = idx_str
		loc_expire_msg = "msg_import_invalid_mission"
	else
		local idx = tonumber(idx_str)
		if not idx or idx < 1 or #saved_mission < idx then
			mod:echo(mod:localize("msg_invalid_number"))
			return
		end
		mission = saved_mission[idx]
		if mission.expired then
			mod:echo(mod:localize("msg_expired_safe_to_delete"))
			return
		end
		mission_id = mission.id
		loc_expire_msg = "msg_expired_safe_to_delete"
	end

	if locks.match then
		mod:echo(mod:localize("msg_command_busy"))
		return
	end
	locks.match = true
	Managers.data_service.mission_board:fetch_mission(mission_id):next(function (data)
		if not data.mission then
			mod:echo(mod:localize("msg_unknown_err"))
			locks.match = nil
			return
		end
		local mission_name = get_mission_name(data.mission, "map", "circumstance")
		local required_level = data.mission.requiredLevel or 0
		go_match(mission_id, mission_name, required_level)
		locks.match = nil
	end):catch(function (e)
		mod:dump(e, "mmt_fetch_error", 3)
		if e and e.code and tonumber(e.code) == 404 then
			if mission then
				mission.expired = true
			end
			mod:echo(mod:localize(loc_expire_msg))
		else
			mod:echo(mod:localize("msg_unknown_err"))
		end
		mod:set("_saved_mission", saved_mission, false)
		locks.match = nil
	end)
end

mod:command("mmt", mod:localize("cmd_main"), mmt_main_command)
mod:command("lm", mod:localize("cmd_lm"), function ()
	mmt_main_command("last")
end)

mod:command("mmtdel", mod:localize("cmd_del"), function (idx_str)
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

mod:command("mmtexport", mod:localize("cmd_export"), function ()
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

mod:command("mmtimport", mod:localize("cmd_import"), function (id)
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
	Managers.data_service.mission_board:fetch_mission(id):next(function (data)
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
	end):catch(function (e)
		mod:echo(mod:localize("msg_import_invalid_mission"))
		locks.import = nil
	end)
end)

mod:command("mmtclear", mod:localize("cmd_clear"), function (hour_str)
	local hour = tonumber(hour_str)
	if not hour then
		mod:echo(mod:localize("msg_help_clear"))
		return
	end
	local now = tonumber(os.time())
	local saved_mission = mod:get("_saved_mission") or {}
	local saved_mission_new = {}
	for _, mission in ipairs(saved_mission) do
		if mission.start then
			local start = mission.start
			if start > now then
				start = now
			end
			local delta = (now - start) / 60 / 60
			if delta <= hour then
				table.insert(saved_mission_new, mission)
			end
		end
	end
	local num = #saved_mission - #saved_mission_new
	mod:echo(string.gsub(mod:localize("msg_cleared"), "#", num))
	mod:set("_saved_mission", saved_mission_new, false)
end)

mod:command("mmtget", mod:localize("cmd_get"), function ()
	local lang = Managers.localization and Managers.localization._language
	Application.open_url_in_browser("https://darktide-mission.otwako.dev/" .. lang)
end)
