local mod = get_mod("SoloPlay")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local HavocCircumstanceTemplate = require("scripts/settings/circumstance/templates/havoc_circumstance_template")
local MissionObjectiveTemplates = require("scripts/settings/mission_objective/mission_objective_templates")
local MissionGiverVoSettings = require("scripts/settings/dialogue/mission_giver_vo_settings")
local DialogueSpeakerVoiceSettings = require("scripts/settings/dialogue/dialogue_speaker_voice_settings")
local HavocSettings = require("scripts/settings/havoc_settings")
local havoc_modifier_template = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/havoc_modifier_template")

local TRAINING_GROUND = "tg_shooting_range"

local objectives_denylist = {
	"hub",
	"onboarding",
	"training_grounds",
}
local circumstance_denylist = {
	"dummy",
}
local circumstance_prefer_list = {
	loc_circumstance_hunting_grounds_title = "hunting_grounds_01",
	loc_circumstance_dummy_more_resistance_title = "more_resistance_01",
	loc_circumstance_dummy_less_resistance_title = "less_resistance_01",
	loc_circumstance_nurgle_manifestation_title = "heretical_disruption_01",
	loc_circumstance_waves_of_specials_more_resistance_title = "waves_of_specials_more_resistance_01",
	loc_havoc_enemies_corrupted_name = "mutator_havoc_enemies_corrupted",
}
local circumstance_format_group = {
	high_flash_mission = "format_auric"
}

local settings = {
	context_override = {
		km_enforcer_twins = {
			circumstance_name = {
				value = "toxic_gas_twins_01",
			},
			pacing_control = {
				value = {
					activate_twins = true,
				},
			},
		},
	},
	pacing_override = {},
	loc = {
		missions = {},
		side_missions = {},
		circumstances = {},
		mission_givers = {},
		havoc_modifiers = havoc_modifier_template.loc,
	},
	order = {
		missions = {},
		side_missions = {},
		circumstances = {},
		mission_givers = {},
		havoc_factions = {},
		havoc_circumstances = {},
		havoc_theme_circumstances = {},
		havoc_difficulty_circumstances = {
			"mutator_increased_difficulty",
			"mutator_highest_difficulty",
		},
		havoc_modifiers = havoc_modifier_template.order,
	},
	lookup = {
		-- use all circumstances if nil
		circumstances_of_missions = {
			km_enforcer_twins = {},
		},
		-- use all mission givers if nil
		mission_givers_of_missions = {},
		theme_of_circumstances = {},
		theme_circumstances_of_havoc_missions = {},
		havoc_modifiers_max_level = havoc_modifier_template.max_level,
	},
}

-- missions
local missions_loc_array = {}
for name, mission in pairs(MissionTemplates) do
	if (not mission.objectives) or (not table.array_contains(objectives_denylist, mission.objectives)) or name == TRAINING_GROUND then
		local display = Localize(mission.mission_name)
		if string.starts_with(display, "<") then
			display = name
		end
		if name == TRAINING_GROUND then
			display = " " .. Localize("loc_training_grounds_view_display_name") .. " - " .. Localize("loc_training_grounds_view_shooting_range_text")
		end
		missions_loc_array[#missions_loc_array+1] = {
			data = name,
			localized = display,
		}

		local mission_brief_vo = mission.mission_brief_vo
		if mission_brief_vo and mission_brief_vo.mission_giver_packs then
			settings.lookup.mission_givers_of_missions[name] = {}
			for mission_giver, _ in pairs(mission_brief_vo.mission_giver_packs) do
				settings.lookup.mission_givers_of_missions[name][mission_giver] = true
			end
		end

		if mission.pacing_template then
			settings.pacing_override[name] = mission.pacing_template
		end
	end
end
local mission_sort_function = function (a, b)
	if a.data == TRAINING_GROUND and b.data ~= TRAINING_GROUND then
		return true
	elseif a.data ~= TRAINING_GROUND and b.data == TRAINING_GROUND then
		return false
	end
	return mod.sort_function_localized(a, b)
end
table.sort(missions_loc_array, mission_sort_function)
for index, mission_loc in ipairs(missions_loc_array) do
	settings.loc.missions[mission_loc.data] = mission_loc.localized
	settings.order.missions[index] = mission_loc.data
end

-- side_missions
local side_missions_loc_array = {}
for name, side_mission in pairs(MissionObjectiveTemplates.side_mission.objectives) do
	if side_mission.is_testable then
		local display = Localize(side_mission.header)
		if string.starts_with(display, "<") then
			display = name
		end
		side_missions_loc_array[#side_missions_loc_array+1] = {
			data = name,
			localized = display,
		}
	end
end
table.sort(side_missions_loc_array, mod.sort_function_localized)
for index, side_mission_loc in ipairs(side_missions_loc_array) do
	settings.loc.side_missions[side_mission_loc.data] = side_mission_loc.localized
	settings.order.side_missions[index] = side_mission_loc.data
end

-- pre-process havoc circumstances
local havoc_circumstances_loc = {}
for circumstance_name in pairs(HavocCircumstanceTemplate) do
	local loc_data = HavocSettings.ui_settings.circumstances[circumstance_name]
	if loc_data then
		havoc_circumstances_loc[circumstance_name] = loc_data.title
	end
end

-- circumstances
local circumstance_property_map = {}
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
		local display_name = circumstance.ui.display_name
		if havoc_circumstances_loc[name] then
			display_name = havoc_circumstances_loc[name]
		end
		if not deny and not format_key then
			circumstance_reverse_map[display_name] = circumstance_reverse_map[display_name] or {}
			table.insert(circumstance_reverse_map[display_name], name)
		end
		circumstance_property_map[name] = {
			deny = deny,
			format_key = format_key,
			display_name = display_name,
		}
	end
end
local circumstances_loc_array = {}
for name, circumstance in pairs(CircumstanceTemplates) do
	local property = circumstance_property_map[name]
	if property then
		if not property.deny then
			local display_name = property.display_name
			local format_key = property.format_key
			local no_loc = false
			local names = circumstance_reverse_map[display_name] or {}
			if not format_key and #names > 1 then
				if circumstance_prefer_list[display_name] ~= name then
					no_loc = true
				end
			end
			local display = display_name
			if string.starts_with(display, "loc_") then
				display = Localize(display_name)
				if no_loc or string.starts_with(display, "<") then
					display = name
				end
			end
			if format_key then
				display = mod:localize(format_key, display)
			end
			circumstances_loc_array[#circumstances_loc_array+1] = {
				data = name,
				localized = display,
			}
		end
	end
end
table.sort(circumstances_loc_array, mod.sort_function_localized)
for index, circumstance_loc in ipairs(circumstances_loc_array) do
	settings.loc.circumstances[circumstance_loc.data] = circumstance_loc.localized
	settings.order.circumstances[index] = circumstance_loc.data
end

-- mission_givers
local mission_giver_reverse_map = {}
for name, _ in pairs(MissionGiverVoSettings.overrides) do
	if DialogueSpeakerVoiceSettings[name] and DialogueSpeakerVoiceSettings[name].full_name then
		local loc_value = Localize(DialogueSpeakerVoiceSettings[name].full_name)
		mission_giver_reverse_map[loc_value] = mission_giver_reverse_map[loc_value] or {}
		table.insert(mission_giver_reverse_map[loc_value], name)
	end
end
local mission_givers_array = {}
for loc_value, names in pairs(mission_giver_reverse_map) do
	if #names == 1 then
		mission_givers_array[#mission_givers_array+1] = {
			data = names[1],
			localized = loc_value,
		}
	else
		for _, name in ipairs(names) do
			local suffix = string.upper(string.sub(name, -1))
			mission_givers_array[#mission_givers_array+1] = {
				data = name,
				localized = loc_value .. " " .. suffix,
			}
		end
	end
end
table.sort(mission_givers_array, mod.sort_function_localized)
for index, mission_giver_loc in ipairs(mission_givers_array) do
	settings.loc.mission_givers[mission_giver_loc.data] = mission_giver_loc.localized
	settings.order.mission_givers[index] = mission_giver_loc.data
end

-- havoc_factions
settings.order.havoc_factions = table.clone(HavocSettings.factions)

-- havoc_circumstances
local havoc_circumstances_array = {}
for _, circumstance_name in ipairs(HavocSettings.circumstances) do
	havoc_circumstances_array[#havoc_circumstances_array+1] = {
		data = circumstance_name,
		localized = settings.loc.circumstances[circumstance_name],
	}
end
table.sort(havoc_circumstances_array, mod.sort_function_localized)
for index, circumstance_loc in ipairs(havoc_circumstances_array) do
	settings.order.havoc_circumstances[index] = circumstance_loc.data
end

-- havoc_theme_circumstances
for _, circumstances in pairs(HavocSettings.circumstances_per_theme) do
	for _, circumstance_name in ipairs(circumstances) do
		settings.order.havoc_theme_circumstances[#settings.order.havoc_theme_circumstances+1] = circumstance_name
	end
end

-- theme_circumstances_of_havoc_missions
settings.lookup.theme_circumstances_of_havoc_missions[TRAINING_GROUND] = {}
for theme in pairs(HavocSettings.missions) do
	if theme ~= "default" then
		for _, theme_circumstance in ipairs(HavocSettings.circumstances_per_theme[theme]) do
			settings.lookup.theme_circumstances_of_havoc_missions[TRAINING_GROUND][theme_circumstance] = true
		end
	end
end
for theme, missions in pairs(HavocSettings.missions) do
	for _, mission_name in ipairs(missions) do
		settings.lookup.theme_circumstances_of_havoc_missions[mission_name] = settings.lookup.theme_circumstances_of_havoc_missions[mission_name] or {}
		if theme ~= "default" then
			for _, theme_circumstance in ipairs(HavocSettings.circumstances_per_theme[theme]) do
				settings.lookup.theme_circumstances_of_havoc_missions[mission_name][theme_circumstance] = true
			end
		end
	end
end

-- theme_of_circumstances
for theme, theme_circumstances in pairs(HavocSettings.circumstances_per_theme) do
	for _, theme_circumstance in ipairs(theme_circumstances) do
		settings.lookup.theme_of_circumstances[theme_circumstance] = theme
	end
end

-- unused havoc circumstances
local used_havoc_circumstances = {}
for _, circumstance in ipairs(settings.order.havoc_circumstances) do
	used_havoc_circumstances[circumstance] = true
end
for _, circumstance in ipairs(settings.order.havoc_theme_circumstances) do
	used_havoc_circumstances[circumstance] = true
end
for _, circumstance in ipairs(settings.order.havoc_difficulty_circumstances) do
	used_havoc_circumstances[circumstance] = true
end
local unused_havoc_circumstances_array = {}
for circumstance_name in pairs(HavocCircumstanceTemplate) do
	if not used_havoc_circumstances[circumstance_name] then
		local loc = settings.loc.circumstances[circumstance_name]
		if loc then
			unused_havoc_circumstances_array[#unused_havoc_circumstances_array+1] = {
				data = circumstance_name,
				localized = loc,
			}
		end
	end
end
table.sort(unused_havoc_circumstances_array, mod.sort_function_localized)
for _, circumstance_loc in ipairs(unused_havoc_circumstances_array) do
	settings.order.havoc_circumstances[#settings.order.havoc_circumstances+1] = circumstance_loc.data
end

return settings
