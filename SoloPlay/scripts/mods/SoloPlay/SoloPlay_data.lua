local mod = get_mod("SoloPlay")
local SoloPlaySettings = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/SoloPlaySettings")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local MissionObjectiveTemplates = require("scripts/settings/mission_objective/mission_objective_templates")

local mission_options = {}
for name, mission in pairs(MissionTemplates) do
	if (not mission.objectives) or (not table.array_contains(SoloPlaySettings.objectives_denylist, mission.objectives)) then
		table.insert(mission_options, {
			text = "loc_mission_" .. name,
			value = name,
		})
	end
end

local circumstance_options = {
	{ text = "default_text", value = "default" },
}
local circumstance_array = {}
local circumstance_reverse_map = {}
for name, circumstance in pairs(CircumstanceTemplates) do
	if circumstance.ui then
		local display_name = circumstance.ui.display_name
		circumstance_reverse_map[display_name] = circumstance_reverse_map[display_name] or {}
		table.insert(circumstance_reverse_map[display_name], name)
	end
end
for name, circumstance in pairs(CircumstanceTemplates) do
	if circumstance.ui then
		local deny = false
		for _, deny_entry in ipairs(SoloPlaySettings.circumstance_denylist) do
			if string.find(name, deny_entry, 1, true) ~= nil then
				deny = true
				break
			end
		end
		if not deny then
			local display_name = circumstance.ui.display_name
			local use_name = false
			local names = circumstance_reverse_map[display_name] or {}
			if #names > 1 then
				if SoloPlaySettings.circumstance_prefer_list[display_name] ~= name then
					use_name = true
				end
			end
			local display = Localize(circumstance.ui.display_name)
			if use_name or string.starts_with(display, "<") then
				display = name
			end
			table.insert(circumstance_array, {
				name = name,
				localized = display,
			})
		end
	end
end
table.sort(circumstance_array, function (a, b)
	return a.localized < b.localized
end)
for _, entry in ipairs(circumstance_array) do
	table.insert(circumstance_options, {
		text = "loc_circumstance_" .. entry.name,
		value = entry.name,
	})
end

local side_mission_options = {
	{ text = "default_text", value = "default" },
}
for name, side_mission in pairs(MissionObjectiveTemplates.side_mission.objectives) do
	if side_mission.is_testable then
		table.insert(side_mission_options, {
			text = "loc_side_mission_" .. name,
			value = name,
		})
	end
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "choose_mission",
				type = "dropdown",
				default_value = "prologue",
				options = mission_options,
			},
			{
				setting_id = "choose_difficulty",
				type = "numeric",
				default_value = 3,
				range = { 1, 5 },
			},
			{
				setting_id = "choose_side_mission",
				type = "dropdown",
				default_value = "default",
				options = side_mission_options,
			},
			{
				setting_id = "choose_circumstance",
				type = "dropdown",
				default_value = "default",
				options = circumstance_options,
			},
		}
	}
}

