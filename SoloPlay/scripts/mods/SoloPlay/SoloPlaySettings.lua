local MissionTemplates = require("scripts/settings/mission/mission_templates")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local MissionObjectiveTemplates = require("scripts/settings/mission_objective/mission_objective_templates")
local MissionGiverVoSettings = require("scripts/settings/dialogue/mission_giver_vo_settings")
local DialogueSpeakerVoiceSettings = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")

local objectives_denylist = {
	"hub",
	"onboarding",
	"training_grounds",
}
local circumstance_denylist = {
	"ember",
	"dummy",
}
local circumstance_prefer_list = {
	loc_circumstance_hunting_grounds_title = "hunting_grounds_01",
	loc_circumstance_dummy_more_resistance_title = "more_resistance_01",
	loc_circumstance_dummy_less_resistance_title = "less_resistance_01",
	loc_circumstance_nurgle_manifestation_title = "heretical_disruption_01",
	loc_circumstance_waves_of_specials_more_resistance_title = "waves_of_specials_more_resistance_01",
}
local circumstance_format_group = {
	high_flash_mission = "format_auric"
}

local settings = {
	missions = {},
	side_missions = {},
	circumstances = {},
	mission_givers = {},
}
settings.context_override = {
	km_enforcer_twins = {
		circumstance_name = {
			default = "default", -- only replace default value
			value = "toxic_gas_twins_01",
		},
		pacing_control = {
			value = {
				activate_twins = true,
			},
		},
	},
}

for name, mission in pairs(MissionTemplates) do
	if (not mission.objectives) or (not table.array_contains(objectives_denylist, mission.objectives)) then
		local display = Localize(mission.mission_name)
		if string.starts_with(display, "<") then
			display = name
		end
		table.insert(settings.missions, {
			loc_key = "loc_mission_" .. name,
			loc_value = display,
			data = name,
		})
	end
end

for name, side_mission in pairs(MissionObjectiveTemplates.side_mission.objectives) do
	if side_mission.is_testable then
		table.insert(settings.side_missions, {
			loc_key = "loc_side_mission_" .. name,
			loc_value = Localize(side_mission.header),
			data = name,
		})
	end
end

local circumstance_array = {}
local circumstance_reverse_map = {}
for name, circumstance in pairs(CircumstanceTemplates) do
	if circumstance.ui then
		local deny = false
		for _, deny_entry in ipairs(circumstance_denylist) do
			if string.find(name, deny_entry, 1, true) ~= nil then
				deny = true
				break
			end
		end
		local format_key = nil
		for pattern, loc_key in pairs(circumstance_format_group) do
			if string.find(name, pattern, 1, true) ~= nil then
				format_key = loc_key
				break
			end
		end
		if not deny and not format_key then
			local display_name = circumstance.ui.display_name
			circumstance_reverse_map[display_name] = circumstance_reverse_map[display_name] or {}
			table.insert(circumstance_reverse_map[display_name], name)
		end
	end
end
for name, circumstance in pairs(CircumstanceTemplates) do
	if circumstance.ui then
		local deny = false
		for _, deny_entry in ipairs(circumstance_denylist) do
			if string.find(name, deny_entry, 1, true) ~= nil then
				deny = true
				break
			end
		end
		local format_key = nil
		for pattern, loc_key in pairs(circumstance_format_group) do
			if string.find(name, pattern, 1, true) ~= nil then
				format_key = loc_key
				break
			end
		end
		if not deny then
			local display_name = circumstance.ui.display_name
			local no_loc = false
			local names = circumstance_reverse_map[display_name] or {}
			if not format_key and #names > 1 then
				if circumstance_prefer_list[display_name] ~= name then
					no_loc = true
				end
			end
			local display = Localize(circumstance.ui.display_name)
			if no_loc or string.starts_with(display, "<") then
				display = name
			end
			table.insert(circumstance_array, {
				name = name,
				localized = display,
				format_key = format_key
			})
		end
	end
end
table.sort(circumstance_array, function (a, b)
	return a.localized < b.localized
end)
for _, entry in ipairs(circumstance_array) do
	table.insert(settings.circumstances, {
		loc_key = "loc_circumstance_" .. entry.name,
		loc_value = entry.localized,
		format_key = entry.format_key,
		data = entry.name,
	})
end

local mission_giver_reverse_map = {}
for name, _ in pairs(MissionGiverVoSettings.overrides) do
	if DialogueSpeakerVoiceSettings[name] and DialogueSpeakerVoiceSettings[name].full_name then
		local loc_value = Localize(DialogueSpeakerVoiceSettings[name].full_name)
		mission_giver_reverse_map[loc_value] = mission_giver_reverse_map[loc_value] or {}
		table.insert(mission_giver_reverse_map[loc_value], name)
	end
end
for loc_value, names in pairs(mission_giver_reverse_map) do
	if #names == 1 then
		table.insert(settings.mission_givers, {
			loc_key = "loc_mission_giver_" .. names[1],
			loc_value = loc_value,
			data = names[1],
		})
	else
		for _, name in ipairs(names) do
			local suffix = string.upper(string.sub(name, -1))
			table.insert(settings.mission_givers, {
				loc_key = "loc_mission_giver_" .. name,
				loc_value = loc_value .. " " .. suffix,
				data = name,
			})
		end
	end
end
table.sort(settings.mission_givers, function (a, b)
	return a.loc_value < b.loc_value
end)

return settings
