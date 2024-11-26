local mod = get_mod("QuickLookCard")
local Items = require("scripts/utilities/items")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local WeaponStats = require("scripts/utilities/weapon_stats")
local BuffTemplates = require("scripts/settings/buff/buff_templates")
local MasterItems = require("scripts/backend/master_items")

local QLColor = {
	default = { 255, 250, 250, 250 },
	modifier = { 255, 250, 189, 73 },
	modifier_dark = { 255, 250, 160, 73 },
	highlight = { 255, 255, 94, 132 },
	new_trait = { 255, 90, 255, 0 },
	low_trait = { 255, 255, 180, 0 },
}

local GadgetTraitBuffNames = {
	gadget_innate_health_increase = "max_health_modifier",
	gadget_innate_toughness_increase = "toughness_bonus",
	gadget_stamina_increase = "stamina_modifier",
	gadget_innate_max_wounds_increase = "extra_max_amount_of_wounds",
}

local compatibility_field_names = {
	"offset",
	"size",
	"font_size",
	"vertical_alignment",
	"horizontal_alignment",
	"text_vertical_alignment",
	"text_horizontal_alignment",
}

local function _get_lerp_stepped_value(range, lerp_value)
	local min = 1
	local max = #range
	local lerped_value = math.lerp(min, max, lerp_value)
	local index = math.round(lerped_value)
	local value = range[index]
	return value
end

local function get_gadget_trait_data(id, value)
	local master = MasterItems.get_item(id)
	local trait = master.trait
	local display_name = mod:localize("trait_" .. trait)
	if display_name == "<trait_" .. trait .. ">" then
		display_name = "???"
	end
	local output = "??"
	local template = BuffTemplates[trait]
	if not template then
		return display_name, output
	end

	local localization_info = template.localization_info
	if not localization_info then
		return display_name, output
	end

	local buff_name = GadgetTraitBuffNames[trait]
	local template_stat_buffs = template.stat_buffs or template.lerped_stat_buffs
	if template_stat_buffs then
		local buff = template_stat_buffs[buff_name]
		if template.lerped_stat_buffs then
			local lerp_value_func = buff.lerp_value_func or math.lerp
			output = lerp_value_func(buff.min, buff.max, value)
		elseif template.class_name == "stepped_range_buff" then
			output = _get_lerp_stepped_value(buff, value)
		else
			output = buff
		end
		local show_as = localization_info[buff_name]
		if show_as and show_as == "percentage" then
			output = math.round(output * 100)
		end
	end
	output = tostring(output)
	return display_name, output
end

local function visibility_function_min_width(content, style, width)
	if content and content.size and content.size[1] < width then
		return false
	end
	return true
end

local function visibility_function_item(content, style)
	if not mod:is_enabled() then
		return false
	end
	if (not content) or (not content.element) or (not content.element.item) then
		return false
	end
	local item = content.element.item
	return item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED" or item.item_type == "GADGET"
end

local function visibility_function_weapon(content, style)
	if not visibility_function_item(content, style) then
		return false
	end
	local item = content.element.item
	return item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED"
end

local function visibility_function_gadget(content, style)
	if not visibility_function_item(content, style) then
		return false
	end
	local item = content.element.item
	return item.item_type == "GADGET"
end

local function visibility_function_perk(content, style, index)
	local gadget = visibility_function_gadget(content, style)
	if (not mod:get("opt_perk") and not gadget) or (not mod:get("opt_curio_perk") and gadget) then
		return nil
	end
	if not visibility_function_item(content, style) then
		return false
	end
	local item = content.element.item
	if (not item.perks) or #item.perks < index then
		return false
	end
	return true
end

local function visibility_function_trait(content, style, index)
	if not mod:get("opt_blessing") then
		return nil
	end
	if not visibility_function_weapon(content, style) then
		return nil
	end
	local item = content.element.item
	if (not item.traits) or #item.traits < index then
		return false
	end
	if not item.traits[index].rarity then
		return false
	end
	return true
end

local function visibility_function_modifier(content, style)
	if not mod:get("opt_modifier") then
		return false
	end
	if not visibility_function_min_width(content, style, 120) then
		return false
	end
	return visibility_function_weapon(content, style)
end

local function visibility_function_gadget_trait(content, style)
	if not mod:get("opt_curio_blessing") then
		return false
	end
	return visibility_function_gadget(content, style)
end

local item_definitions = {
	-- ########################
	-- ###### Base Level ######
	-- ########################
	{
		pass_type = "text",
		style_id = "qlc_baseLevel",
		value_id = "qlc_baseLevel",
		style = {
			material = "content/ui/materials/font_gradients/slug_font_gradient_item_level",
			vertical_alignment = "top",
			horizontal_alignment = "right",
			text_vertical_alignment = "top",
			text_horizontal_alignment = "right",
			offset = { -20, 92, 5 },
			offset_i2d = { -10, 97, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "proxima_nova_bold",
			font_size = 16,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = function (content, style)
			if not mod:get("opt_base_level") then
				return false
			end
			if not visibility_function_weapon(content, style) then
				return false
			end
			local item = content.element.item
			if not item.rarity then
				return false
			end
			return true
		end,
	},
	-- #######################
	-- ###### Blessings ######
	-- #######################
	{
		pass_type = "texture",
		style_id = "qlc_trait_icon_1",
		value_id = "qlc_trait_icon_1",
		value = "content/ui/materials/icons/perks/perk_level_05",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			offset = { 288, 90, 10 },
			offset_i2d = { 105, 60, 5 },
			size = { 16, 16 },
			size_i2d = { 10, 10 },
			color = QLColor.default,
		},
		visibility_function = function (content, style)
			if not visibility_function_trait(content, style, 1) then
				return false
			end
			return true
		end,
	},
	{
		pass_type = "text",
		style_id = "qlc_trait_level_1",
		value_id = "qlc_trait_level_1",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 308, 80, 10 },
			offset_i2d = { 117, 47, 10 },
			size = { 36, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 17,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = function (content, style)
			if not visibility_function_trait(content, style, 1) then
				return false
			end
			local item = content.element.item
			content.qlc_trait_level_1 = tostring(item.traits[1].rarity)
			return true
		end,
	},
	{
		pass_type = "texture",
		style_id = "qlc_trait_icon_2",
		value_id = "qlc_trait_icon_2",
		value = "content/ui/materials/icons/perks/perk_level_05",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			offset = { 323, 90, 10 },
			offset_i2d = { 125, 60, 5 },
			size = { 16, 16 },
			size_i2d = { 10, 10 },
			color = QLColor.default,
		},
		visibility_function = function (content, style)
			if not visibility_function_trait(content, style, 2) then
				return false
			end
			return true
		end,
	},
	{
		pass_type = "text",
		style_id = "qlc_trait_level_2",
		value_id = "qlc_trait_level_2",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 343, 80, 10 },
			offset_i2d = { 137, 47, 10 },
			size = { 36, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 17,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = function (content, style)
			if not visibility_function_trait(content, style, 2) then
				return false
			end
			local item = content.element.item
			content.qlc_trait_level_2 = tostring(item.traits[2].rarity)
			return true
		end,
	},
	-- ############################
	-- ###### Modifier Stats ######
	-- ############################
	{
		pass_type = "text",
		style_id = "qlc_stats_title_1",
		value_id = "qlc_stats_title_1",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 148, 60, 5 },
			offset_i2d = { 15, 34, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_value_1",
		value_id = "qlc_stats_value_1",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 188, 60, 5 },
			offset_i2d = { 42, 34, 5 },
			size = { 120, 36 },
			text_color = QLColor.modifier,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_title_2",
		value_id = "qlc_stats_title_2",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 218, 60, 5 },
			offset_i2d = { 60, 34, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_value_2",
		value_id = "qlc_stats_value_2",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 258, 60, 5 },
			offset_i2d = { 87, 34, 5 },
			size = { 120, 36 },
			text_color = QLColor.modifier,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_title_3",
		value_id = "qlc_stats_title_3",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 288, 60, 5 },
			offset_i2d = { 105, 34, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_value_3",
		value_id = "qlc_stats_value_3",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 328, 60, 5 },
			offset_i2d = { 132, 34, 5 },
			size = { 120, 36 },
			text_color = QLColor.modifier,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_title_4",
		value_id = "qlc_stats_title_4",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 148, 80, 5 },
			offset_i2d = { 15, 47, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_value_4",
		value_id = "qlc_stats_value_4",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 188, 80, 5 },
			offset_i2d = { 42, 47, 5 },
			size = { 120, 36 },
			text_color = QLColor.modifier,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_title_5",
		value_id = "qlc_stats_title_5",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 218, 80, 5 },
			offset_i2d = { 60, 47, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_value_5",
		value_id = "qlc_stats_value_5",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 258, 80, 5 },
			offset_i2d = { 87, 47, 5 },
			size = { 120, 36 },
			text_color = QLColor.modifier,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_modifier,
	},
	-- ##########################
	-- ###### Weapon Perks ######
	-- ##########################
	{
		pass_type = "text",
		style_id = "qlc_weapon_perk_title_1",
		value_id = "qlc_weapon_perk_title_1",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 368, 60, 5 },
			offset_i2d = { 86, 65, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 13,
		},
		value = "",
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 1) then
				return false
			end
			if not visibility_function_weapon(content, style) then
				return false
			end
			if not visibility_function_min_width(content, style, 170) then
				return false
			end
			return true
		end,
	},
	{
		pass_type = "texture",
		style_id = "qlc_weapon_perk_icon_1",
		value_id = "qlc_weapon_perk_icon_1",
		value = "content/ui/materials/icons/perks/perk_level_05",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			offset = { 408, 70, 10 },
			offset_i2d = { 113, 77, 5 },
			size = { 16, 16 },
			size_i2d = { 13, 13 },
			color = QLColor.default,
		},
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 1) then
				return false
			end
			if not visibility_function_weapon(content, style) then
				return false
			end
			if not visibility_function_min_width(content, style, 170) then
				return false
			end
			local item = content.element.item
			local mat = "content/ui/materials/icons/perks/perk_level_" .. string.format("%02d", item.perks[1].rarity)
			content.qlc_weapon_perk_icon_1 = mat
			return true
		end,
	},
	{
		pass_type = "text",
		style_id = "qlc_weapon_perk_title_2",
		value_id = "qlc_weapon_perk_title_2",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 368, 80, 5 },
			offset_i2d = { 86, 80, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 13,
		},
		value = "",
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 1) then
				return false
			end
			if not visibility_function_weapon(content, style) then
				return false
			end
			if not visibility_function_min_width(content, style, 170) then
				return false
			end
			return true
		end,
	},
	{
		pass_type = "texture",
		style_id = "qlc_weapon_perk_icon_2",
		value_id = "qlc_weapon_perk_icon_2",
		value = "content/ui/materials/icons/perks/perk_level_05",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			offset = { 408, 90, 10 },
			offset_i2d = { 113, 92, 5 },
			size = { 16, 16 },
			size_i2d = { 13, 13 },
			color = QLColor.default,
		},
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 2) then
				return false
			end
			if not visibility_function_weapon(content, style) then
				return false
			end
			if not visibility_function_min_width(content, style, 170) then
				return false
			end
			local item = content.element.item
			local mat = "content/ui/materials/icons/perks/perk_level_" .. string.format("%02d", item.perks[2].rarity)
			content.qlc_weapon_perk_icon_2 = mat
			return true
		end,
	},
	-- #########################
	-- ###### Curio Perks ######
	-- #########################
	{
		pass_type = "text",
		style_id = "qlc_gadget_perk_title_1",
		value_id = "qlc_gadget_perk_title_1",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 148, 80, 5 },
			offset_i2d = { 15, 47, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 1) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			return true
		end,
	},
	{
		pass_type = "texture",
		style_id = "qlc_gadget_perk_icon_1",
		value_id = "qlc_gadget_perk_icon_1",
		value = "content/ui/materials/icons/perks/perk_level_05",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			offset = { 188, 90, 5 },
			offset_i2d = { 42, 59, 5 },
			size = { 16, 16 },
			size_i2d = { 12, 12 },
			color = QLColor.default,
		},
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 1) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			local item = content.element.item
			local mat = "content/ui/materials/icons/perks/perk_level_" .. string.format("%02d", item.perks[1].rarity)
			content.qlc_gadget_perk_icon_1 = mat
			return true
		end,
	},
	{
		pass_type = "text",
		style_id = "qlc_gadget_perk_title_2",
		value_id = "qlc_gadget_perk_title_2",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 218, 80, 5 },
			offset_i2d = { 60, 47, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 1) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			return true
		end,
	},
	{
		pass_type = "texture",
		style_id = "qlc_gadget_perk_icon_2",
		value_id = "qlc_gadget_perk_icon_2",
		value = "content/ui/materials/icons/perks/perk_level_05",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			offset = { 258, 90, 10 },
			offset_i2d = { 87, 59, 5 },
			size = { 16, 16 },
			size_i2d = { 12, 12 },
			color = QLColor.default,
		},
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 2) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			local item = content.element.item
			local mat = "content/ui/materials/icons/perks/perk_level_" .. string.format("%02d", item.perks[2].rarity)
			content.qlc_gadget_perk_icon_2 = mat
			return true
		end,
	},
	{
		pass_type = "text",
		style_id = "qlc_gadget_perk_title_3",
		value_id = "qlc_gadget_perk_title_3",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 288, 80, 5 },
			offset_i2d = { 105, 47, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 3) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			return true
		end,
	},
	{
		pass_type = "texture",
		style_id = "qlc_gadget_perk_icon_3",
		value_id = "qlc_gadget_perk_icon_3",
		value = "content/ui/materials/icons/perks/perk_level_05",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			offset = { 328, 90, 10 },
			offset_i2d = { 132, 59, 5 },
			size = { 16, 16 },
			size_i2d = { 12, 12 },
			color = QLColor.default,
		},
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 3) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			local item = content.element.item
			local mat = "content/ui/materials/icons/perks/perk_level_" .. string.format("%02d", item.perks[3].rarity)
			content.qlc_gadget_perk_icon_3 = mat
			return true
		end,
	},
	-- ############################
	-- ###### Curio Blessing ######
	-- ############################
	{
		pass_type = "text",
		style_id = "qlc_gadget_blessing_title",
		value_id = "qlc_gadget_blessing_title",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 148, 60, 5 },
			offset_i2d = { 15, 34, 5 },
			size = { 120, 36 },
			text_color = QLColor.default,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_gadget_trait,
	},
	{
		pass_type = "text",
		style_id = "qlc_gadget_blessing_value",
		value_id = "qlc_gadget_blessing_value",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 188, 60, 5 },
			offset_i2d = { 42, 34, 5 },
			size = { 120, 36 },
			text_color = QLColor.modifier,
			font_type = "machine_medium",
			font_size = 18,
			font_size_i2d = 12,
		},
		value = "",
		visibility_function = visibility_function_gadget_trait,
	},
}

mod:hook_require("scripts/ui/pass_templates/item_pass_templates", function(instance)
	for _, def in ipairs(item_definitions) do
		local idx = nil
		for i, v in ipairs(instance.item) do
			if v.style_id == def.style_id then
				idx = i
				break
			end
		end
		if idx then
			table.remove(instance.item, idx)
		end
		local item = table.clone(def)
		table.insert(instance.item, item)
	end
end)

local base_stats_position_map = { 1, 5, 3, 4, 2 }

local function fill_weapon_base_stats(content, style, item)
	if not item.base_stats then
		return
	end
	local template = WeaponTemplates[item.weapon_template]
	if (not template) or (not template.base_stats) then
		return
	end

	local potential_mode = mod:get("opt_modifier_mode") == "potential"

	local weapon_stats = WeaponStats:new(item)
	local comparing_stats = table.clone(weapon_stats:get_comparing_stats())
	local num_stats = table.size(comparing_stats)
	local start_preview_expertise = Items.expertise_level(item, true)
	local max_preview_expertise = Items.max_expertise_level() - start_preview_expertise
	local max_stats = Items.preview_stats_change(item, max_preview_expertise, comparing_stats)
	for _, stat in ipairs(comparing_stats) do
		if stat.display_name then
			local max_stat = max_stats[stat.display_name]
			if max_stat then
				stat.qlc_max_reached = math.floor(stat.fraction * 100 + 0.5) >= math.floor(max_stat.fraction * 100 + 0.5)
				if potential_mode then
					stat.fraction = max_stat.fraction
				end
			end
		end
	end
	content["qlc_baseLevel"] = tostring(item.baseItemLevel)

	-- fill values
	if num_stats > 0 then
		local min_value = math.floor(comparing_stats[1].fraction * 100 + 0.5)
		local min_idx = 1
		local all_same = false
		for i = 1, num_stats do
			local stat_data = comparing_stats[i]
			local ii = base_stats_position_map[i]
			local title = mod:localize("stat_" .. stat_data.display_name)
			if title == "<" .. "stat_" .. stat_data.display_name .. ">" then
				title = "???"
			end
			local value = math.floor(stat_data.fraction * 100 + 0.5)

			if value < min_value then
				min_value = value
				min_idx = ii
				all_same = false
			elseif value ~= min_value then
				all_same = false
			end

			content["qlc_stats_title_" .. tostring(ii)] = title
			local max_sign = ""
			if not stat_data.qlc_max_reached then
				max_sign = potential_mode and "-" or "+"
			end
			content["qlc_stats_value_" .. tostring(ii)] = tostring(value) .. max_sign
			if style and style["qlc_stats_value_" .. tostring(ii)] then
				if stat_data.qlc_max_reached then
					style["qlc_stats_value_" .. tostring(ii)].text_color = QLColor.modifier
				else
					style["qlc_stats_value_" .. tostring(ii)].text_color = QLColor.modifier_dark
				end
			end
		end
		if mod:get("opt_highlight_dump_stat") and  not all_same then
			style["qlc_stats_title_" .. tostring(min_idx)].text_color = QLColor.highlight
		end
	end
end

local function fill_gadget_trait(content, item)
	if (not item.traits) or #item.traits < 1 then
		return
	end
	local trait = item.traits[1]
	local diaplay_name, output = get_gadget_trait_data(trait.id, trait.value)
	content["qlc_gadget_blessing_title"] = diaplay_name
	content["qlc_gadget_blessing_value"] = output
end

local function fill_perk(content, item)
	if (not item.perks) or #item.perks < 1 then
		return
	end
	for i, perk in ipairs(item.perks) do
		if item.item_type == "GADGET" and i > 3 then
			break
		elseif (item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED") and i > 2 then
			break
		end
		local master = MasterItems.get_item(perk.id)
		local trait = master.trait
		local display_name = mod:localize("trait_" .. trait)
		if display_name == "<trait_" .. trait .. ">" then
			display_name = "???"
		end
		if item.item_type == "GADGET" then
			content["qlc_gadget_perk_title_" .. tostring(i)] = display_name
		else
			content["qlc_weapon_perk_title_" .. tostring(i)] = display_name
		end
	end
end

local function update_compatibility_fields(widget, item)
	if widget.type == "store_item" then
		return
	end
	local i2d = get_mod("Inventory2D")
	local styles = widget.style
	if not styles or not i2d or not i2d:is_enabled() then
		return
	end
	if widget.content and widget.content.size and widget.content.size[1] > 300 then
		return
	end

	for _, pass in ipairs(item_definitions) do
		if pass.style_id then
			local style = styles[pass.style_id]
			for _, field in ipairs(compatibility_field_names) do
				if style[field .. "_i2d"] then
					style[field] = style[field .. "_i2d"]
				end
			end
		end
	end
end

mod:hook("ViewElementGrid", "_create_entry_widget_from_config", function(func, self, config, suffix, callback_name, secondary_callback_name, double_click_callback_name)
	local widget, alignment_widget = func(
		self, config, suffix, callback_name, secondary_callback_name, double_click_callback_name
	)

	-- early checks
	if (not widget) or (widget.type ~= "item" and widget.type ~= "store_item") then
		return widget, alignment_widget
	end
	local content = widget.content
	if (not content) or (not content.element) or (not content.element.item) then
		return widget, alignment_widget
	end
	local item = content.element.item
	if widget.type == "store_item" then
		local offer = content.element.offer
		if not offer then
			return widget, alignment_widget
		end
		if offer.description and offer.description.type ~= "weapon" and offer.description.type ~= "gadget" then
			return widget, alignment_widget
		end
	end
	update_compatibility_fields(widget, item)

	if item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED" then
		fill_weapon_base_stats(content, widget.style, item)
	elseif item.item_type == "GADGET" then
		fill_gadget_trait(content, item)
	end
	fill_perk(content, item)
	return widget, alignment_widget
end)
