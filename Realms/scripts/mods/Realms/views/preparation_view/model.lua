local mod = get_mod("Realms")
local CircumstanceTemplates = require("scripts/settings/circumstance/circumstance_templates")
local MissionObjectiveTemplates = require("scripts/settings/mission_objective/mission_objective_templates")
local MissionTemplates = require("scripts/settings/mission/mission_templates")
local UISettings = require("scripts/settings/ui/ui_settings")
local Zones = require("scripts/settings/zones/zones")
local Havoc = require("scripts/utilities/havoc")
local Loadout = mod:io_dofile("Realms/scripts/mods/Realms/views/preparation_view/loadout")

local PreparationViewModel = {}

local function localize_if_present(key)
	return key and Managers.localization:exists(key) and Localize(key) or nil
end

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function archetype_presentation(profile)
	local archetype = profile and profile.archetype

	if not archetype then
		return ""
	end

	local name = localize_if_present(archetype.archetype_name) or ""
	local symbol = UISettings.archetype_font_icon[archetype.name]

	return symbol and symbol .. " " .. name or name
end

local function mission_context(fallback_mission_name)
	local mechanism_manager = Managers.mechanism
	local mechanism = mechanism_manager and mechanism_manager:current_mechanism()
	local mechanism_data = mechanism and mechanism_manager:mechanism_data() or {}
	local mission_name = mechanism_data.mission_name or fallback_mission_name

	return mechanism_data, mission_name, mission_name and MissionTemplates[mission_name]
end

function PreparationViewModel.mission_header(fallback_mission_name)
	local _, mission_name, mission_settings = mission_context(fallback_mission_name)
	local zone = mission_settings and Zones[mission_settings.zone_id]
	local zone_name = zone and localize_if_present(zone.name)

	return {
		subtitle = zone_name or "",
		title = mission_settings and Localize(mission_settings.mission_name) or tostring(mission_name or "-"),
	}
end

local function append_circumstance(details, circumstance)
	local circumstance_settings = circumstance and CircumstanceTemplates[circumstance]

	if circumstance == "default" or not circumstance_settings or not circumstance_settings.ui then
		return
	end

	details[#details + 1] = {
		key = "circumstance:" .. circumstance,
		widget_data = {
			circumstance = circumstance,
		},
		widget_type = "circumstance",
	}
end

local function append_havoc_circumstances(details, havoc_data)
	if type(havoc_data) ~= "string" then
		return
	end

	local parsed_data = Havoc.parse_data(havoc_data)
	local circumstances = parsed_data.circumstances

	for i = 1, #circumstances do
		append_circumstance(details, circumstances[i])
	end
end

function PreparationViewModel.mission_details(fallback_mission_name)
	local mechanism_data = mission_context(fallback_mission_name)
	local details = {}
	local side_mission = mechanism_data.side_mission
	local side_missions = MissionObjectiveTemplates.side_mission.objectives

	if side_mission and side_mission ~= "default" and side_missions[side_mission] then
		details[#details + 1] = {
			key = "side_mission:" .. side_mission,
			widget_data = {
				side_mission = side_mission,
			},
			widget_type = "side_mission",
		}
	end

	append_circumstance(details, mechanism_data.circumstance_name)
	append_havoc_circumstances(details, mechanism_data.havoc_data)

	return details
end

function PreparationViewModel.player_rows(ready_by_peer)
	local rows = {}
	local player_manager = Managers.player

	if not player_manager then
		return rows
	end

	for _, player in pairs(player_manager:human_players()) do
		local profile = player:profile()
		local peer_id = normalize_peer_id(player:peer_id())
		local loadout = Loadout.presentation(profile)
		local class_name = archetype_presentation(profile)

		rows[#rows + 1] = {
			class_name = class_name,
			loadout_key = loadout.loadout_key,
			peer_id = peer_id,
			name = player:name(),
			profile = profile,
			ready = ready_by_peer[peer_id] or false,
			skills = loadout.skills,
			weapons = loadout.weapons,
		}
	end

	table.sort(rows, function (a, b)
		return a.name == b.name and a.peer_id < b.peer_id or a.name < b.name
	end)

	return rows
end

return PreparationViewModel
