local mod = get_mod("SoloPlay")
local HavocSettings = require("scripts/settings/havoc_settings")
local HavocModifierConfig = require("scripts/settings/havoc/havoc_modifier_config")
local BuffTemplates = require("scripts/settings/buff/buff_templates")
local BuffSettings = require("scripts/settings/buff/buff_settings")
local buff_stat_buffs = BuffSettings.stat_buffs

mod.sort_function_localized = function (a, b)
	return a.localized < b.localized
end

local single_params_template = {
	buff_elites = {
		percent = true,
	},
	buff_specials = {
		percent = true,
	},
	more_elites = {
		percent = true,
	},
	more_ogryns = {
		percent = true,
	},
	melee_minion_attack_speed = {
		percent = true,
	},
	melee_minion_permanent_damage = {
		percent = true,
	},
	ammo_pickup_modifier = {
		base = 1,
		negative_value = true,
		percent = true,
	},
	horde_spawn_rate_increase = {
		percent = true,
	},
	terror_event_point_increase = {
		percent = true,
	},
	melee_minion_power_level_buff = {
		percent = true,
	},
	reduce_toughness = {
		negative_value = true,
	},
	reduce_toughness_regen = {
		negative_value = true,
		percent = true,
	},
	reduce_health_and_wounds = {
		negative_value = true,
		percent = true,
	},
	havoc_vent_speed_reduction = {
		base = 1,
		percent = true,
	},
	positive_weakspot_damage_bonus = {
		percent = true,
	},
	positive_knocked_down_health_modifier = {
		percent = true,
	},
	positive_reload_speed = {
		percent = true,
	},
	positive_crit_chance = {
		percent = true,
	},
	positive_movement_speed = {
		percent = true,
	},
}
local multi_params_template = {
	buff_monsters = {
		{
			field = "add_num_monsters",
		},
		{
			field = "modify_monster_health",
			percent = true,
		},
	},
	buff_horde = {
		{
			field = "modify_horde_hit_mass",
			percent = true,
		},
		{
			field = "modify_horde_health",
			percent = true,
		},
	},
	ranged_minion_attack_speed = {
		{
			field = buff_stat_buffs.ranged_attack_speed,
			percent = true,
		},
		{
			field = buff_stat_buffs.minion_num_shots_modifier,
			base = 1,
			percent = true,
		},
	},
	positive_grenade_buff = {
		{
			field = buff_stat_buffs.extra_max_amount_of_grenades,
		},
		{
			field = buff_stat_buffs.warp_charge_amount_smite,
			base = 1,
			negative_value = true,
			percent = true,
		},
	},
	positive_attack_speed = {
		{
			field = buff_stat_buffs.melee_attack_speed,
			percent = true,
		},
		{
			field = buff_stat_buffs.ranged_attack_speed,
			percent = true,
		},
	},
}

local function get_table_any_field_name(t)
	for name in pairs(t) do
		return name
	end
	return nil
end

local function template_is_buff_type(template)
	local test_data = template[get_table_any_field_name(template)]
	return type(test_data) == "string"
end

local function get_param_table(template)
	if template_is_buff_type(template) then
		local buff_name = template[get_table_any_field_name(template)]
		return BuffTemplates[buff_name].stat_buffs
	end
	return template
end

local havoc_modifier_template = {
	loc = {},
	order = {},
	max_level = {},
}

-- order pre-process
local modifier_used = {}
for _, rank_modifier_template in ipairs(HavocModifierConfig) do
	for name in pairs(rank_modifier_template) do
		modifier_used[name] = true
	end
end

-- loc
local all_modifiers = table.merge_recursive(table.clone(HavocSettings.modifier_templates), HavocSettings.positive_modifier_templates)
local modifiers_loc_array, positive_modifiers_loc_array = {}, {}

for modifier_name, templates in pairs(all_modifiers) do
	havoc_modifier_template.max_level[modifier_name] = #templates
	havoc_modifier_template.loc[modifier_name] = {}

	local single_data = single_params_template[modifier_name]
	local multi_data = multi_params_template[modifier_name]
	local loc_key = "havoc_modifier_" .. modifier_name

	local params_for_0 = {}
	if multi_data then
		for i = 1, #multi_data do
			params_for_0[i] = 0
		end
	else
		params_for_0[1] = 0
	end
	havoc_modifier_template.loc[modifier_name][0] = mod:localize(loc_key, unpack(params_for_0))
	for level, template in ipairs(templates) do
		local param_table = get_param_table(template)
		local params = {}
		if multi_data then
			for _, param_data in ipairs(multi_data) do
				local value = param_table[param_data.field]
				if param_data.base then
					value = value - param_data.base
				end
				if param_data.percent then
					value = value * 100
				end
				value = math.floor(value + 0.5)
				if param_data.negative_value then
					value = -value
				end
				params[#params+1] = value
			end
		else
			single_data = single_data or {}
			local value = param_table[get_table_any_field_name(param_table)]
			if single_data.base then
				value = value - single_data.base
			end
			if single_data.percent then
				value = value * 100
			end
			value = math.floor(value + 0.5)
			if single_data.negative_value then
				value = -value
			end
			params[#params+1] = value
		end
		havoc_modifier_template.loc[modifier_name][level] = mod:localize(loc_key, unpack(params))
	end

	if HavocSettings.modifier_templates[modifier_name] and not modifier_used[modifier_name] then
		modifiers_loc_array[#modifiers_loc_array+1] = {
			data = modifier_name,
			localized = havoc_modifier_template.loc[modifier_name][1],
		}
	elseif HavocSettings.positive_modifier_templates[modifier_name] then
		positive_modifiers_loc_array[#positive_modifiers_loc_array+1] = {
			data = modifier_name,
			localized = havoc_modifier_template.loc[modifier_name][1],
		}
	end
end

-- order
local modifier_processed_map = {}
for _, rank_modifier_template in ipairs(HavocModifierConfig) do
	local modifiers_loc = {}
	for name in pairs(rank_modifier_template) do
		if not modifier_processed_map[name] then
			modifier_processed_map[name] = true
			modifiers_loc[#modifiers_loc+1] = {
				data = name,
				localized = havoc_modifier_template.loc[name][1],
			}
		end
	end
	table.sort(modifiers_loc, mod.sort_function_localized)
	for _, modifier_data in ipairs(modifiers_loc) do
		havoc_modifier_template.order[#havoc_modifier_template.order+1] = modifier_data.data
	end
end

table.sort(modifiers_loc_array, mod.sort_function_localized)
table.sort(positive_modifiers_loc_array, mod.sort_function_localized)
for _, modifier_loc in ipairs(modifiers_loc_array) do
	havoc_modifier_template.order[#havoc_modifier_template.order+1] = modifier_loc.data
end
for _, modifier_loc in ipairs(positive_modifiers_loc_array) do
	havoc_modifier_template.order[#havoc_modifier_template.order+1] = modifier_loc.data
end

return havoc_modifier_template
