local mod = get_mod("Realms")
local CharacterSheet = require("scripts/utilities/character_sheet")
local MasterItems = require("scripts/backend/master_items")
local TalentBuilderViewSettings = require("scripts/ui/views/talent_builder_view/talent_builder_view_settings")

local Loadout = {}
local LOADOUT_ORDER = {
	"ability",
	"blitz",
	"aura",
}
local LOADOUT_NODE_TYPES = {
	ability = "ability",
	aura = "aura",
	blitz = "tactical",
}

local function append_selected_keystones(profile, skills)
	local archetype = profile.archetype
	local layout_path = archetype and archetype.talent_layout_file_path
	local selected_talents = profile.talents

	if not layout_path or not selected_talents then
		return
	end

	local nodes = require(layout_path).nodes

	for i = 1, #nodes do
		local node = nodes[i]

		if node.type == "keystone" and (selected_talents[node.talent] or 0) > 0 then
			skills[#skills + 1] = {
				icon = node.icon,
				loadout_id = "keystone",
				node_type = "keystone",
				talent = archetype.talents[node.talent],
			}
		end
	end
end

local function selected_skills(profile)
	local class_loadout = {
		ability = {},
		aura = {},
		blitz = {},
		pocketable = {},
	}

	CharacterSheet.class_loadout(profile, class_loadout, nil, profile.talents, true)

	local skills = {}

	for i = 1, #LOADOUT_ORDER do
		local loadout_id = LOADOUT_ORDER[i]
		local loadout = class_loadout[loadout_id]

		if loadout and loadout.talent and loadout.icon then
			skills[#skills + 1] = {
				icon = loadout.icon,
				loadout_id = loadout_id,
				node_type = LOADOUT_NODE_TYPES[loadout_id],
				talent = loadout.talent,
			}
		end
	end

	append_selected_keystones(profile, skills)

	return skills
end

local function weapon_icon(item)
	if not item then
		return nil
	end

	local master_item = item.name and MasterItems.get_item(item.name)

	return master_item and master_item.hud_icon or item.hud_icon
end

function Loadout.presentation(profile)
	local loadout = profile and profile.loadout or {}
	local primary = loadout.slot_primary
	local secondary = loadout.slot_secondary
	local talent_names = profile and table.keys(profile.talents or {}) or {}
	local talent_signature = {}

	table.sort(talent_names)

	for i = 1, #talent_names do
		local talent_name = talent_names[i]

		talent_signature[i] = talent_name .. "=" .. tostring(profile.talents[talent_name])
	end

	return {
		loadout_key = table.concat({
			primary and (primary.gear_id or primary.name) or "",
			secondary and (secondary.gear_id or secondary.name) or "",
			table.concat(talent_signature, ","),
		}, "\31"),
		skills = profile and selected_skills(profile) or {},
		weapons = {
			{
				icon = weapon_icon(primary),
				item = primary,
				slot = "slot_primary",
			},
			{
				icon = weapon_icon(secondary),
				item = secondary,
				slot = "slot_secondary",
			},
		},
	}
end

function Loadout.node_settings(node_type)
	return TalentBuilderViewSettings.settings_by_node_type[node_type]
end

return Loadout
