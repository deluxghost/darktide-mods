local mod = get_mod("QuickLookCard")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local WeaponStats = require("scripts/utilities/weapon_stats")
local BuffTemplates = require("scripts/settings/buff/buff_templates")
local MasterItems = require("scripts/backend/master_items")
local ItemUtils = require("scripts/utilities/items")

local QLColor = {
	default = { 255, 250, 250, 250 },
	modifier = {255, 250, 189, 73},
	locked = { 255, 255, 66, 50 },
	modified = { 255, 48, 229, 207 },
	new_trait = { 255, 90, 255, 0 },
	low_trait = { 255, 255, 180, 0 },
}

local GadgetTraitBuffNames = {
	gadget_inate_health_increase = "max_health_modifier",
	gadget_inate_toughness_increase = "toughness_bonus",
	gadget_stamina_increase = "stamina_modifier",
	gadget_inate_max_wounds_increase = "extra_max_amount_of_wounds",
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

local function perk_trait_lock(item, data, index)
	local num_modifications, max_modifications = ItemUtils.modifications_by_rarity(item)
	local item_locked = num_modifications == max_modifications

	local entry = data[index]
	if entry then
		if entry.modified then
			return "modified"
		elseif item_locked then
			return "locked"
		end
	end
	return "open"
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
		return nil
	end
	if not item.traits[index].rarity then
		return nil
	end
	local cache = Managers.data_service.crafting._trait_sticker_book_cache
	if not cache then
		return nil
	end
	local category = cache:cached_data_by_key(item.trait_category)
	if not category then
		return nil
	end
	local trait = item.traits[index]
	local book = category[trait.id]
	if not book then
		return nil
	end
	if book[trait.rarity] == "seen" then
		return "own"
	end
	local i = trait.rarity + 1
	while book[i] and book[i] ~= "invalid" do
		if book[i] == "seen" then
			return "low"
		end
		i = i + 1
	end
	return "new"
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
			if not item.rarity or item.rarity < 2 then
				return false
			end
			return true
		end,
	},
	-- #######################
	-- ###### Blessings ######
	-- #######################
	{
		pass_type = "text",
		style_id = "qlc_trait_level_1",
		value_id = "qlc_trait_level_1",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 18, 80, 10 },
			offset_i2d = { 14, 84, 10 },
			size = { 36, 36 },
			text_color = QLColor.default,
			font_type = "proxima_nova_bold",
			font_size = 17,
			font_size_i2d = 15,
		},
		value = "",
		visibility_function = function (content, style)
			local vis = visibility_function_trait(content, style, 1)
			if not vis then
				return false
			end
			if vis == "new" then
				style.text_color = QLColor.new_trait
			elseif vis == "low" then
				style.text_color = QLColor.low_trait
			else
				style.text_color = QLColor.default
			end
			local item = content.element.item
			content.qlc_trait_level_1 = tostring(item.traits[1].rarity)
			return true
		end,
	},
	{
		pass_type = "text",
		style_id = "qlc_trait_lock_1",
		value_id = "qlc_trait_lock_1",
		value = "",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			text_horizontal_alignment = "center",
			offset = { 42, 60, 10 },
			offset_i2d = { 34, 68, 10 },
			size = { 18, 18 },
			text_color = QLColor.locked,
			font_type = "proxima_nova_bold",
			font_size = 17,
			font_size_i2d = 15,
		},
		visibility_function = function (content, style)
			if not visibility_function_trait(content, style, 1) then
				return false
			end
			local item = content.element.item
			local locked = perk_trait_lock(item, item.traits, 1)
			if locked == "open" then
				return false
			elseif locked == "locked" then
				content.qlc_trait_lock_1 = ""
				style.text_color = QLColor.locked
			elseif locked == "modified" then
				content.qlc_trait_lock_1 = ""
				style.text_color = QLColor.modified
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
			offset = { 60, 80, 10 },
			offset_i2d = { 52, 84, 10 },
			size = { 36, 36 },
			text_color = QLColor.default,
			font_type = "proxima_nova_bold",
			font_size = 17,
			font_size_i2d = 15,
		},
		value = "",
		visibility_function = function (content, style)
			local vis = visibility_function_trait(content, style, 2)
			if not vis then
				return false
			end
			if vis == "new" then
				style.text_color = QLColor.new_trait
			elseif vis == "low" then
				style.text_color = QLColor.low_trait
			else
				style.text_color = QLColor.default
			end
			local item = content.element.item
			content.qlc_trait_level_2 = tostring(item.traits[2].rarity)
			return true
		end,
	},
	{
		pass_type = "text",
		style_id = "qlc_trait_lock_2",
		value_id = "qlc_trait_lock_2",
		value = "",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			text_horizontal_alignment = "center",
			offset = { 84, 60, 10 },
			offset_i2d = { 70, 68, 10 },
			size = { 18, 18 },
			text_color = QLColor.locked,
			font_type = "proxima_nova_bold",
			font_size = 17,
			font_size_i2d = 15,
		},
		visibility_function = function (content, style)
			if not visibility_function_trait(content, style, 2) then
				return false
			end
			local item = content.element.item
			local locked = perk_trait_lock(item, item.traits, 2)
			if locked == "open" then
				return false
			elseif locked == "locked" then
				content.qlc_trait_lock_2 = ""
				style.text_color = QLColor.locked
			elseif locked == "modified" then
				content.qlc_trait_lock_2 = ""
				style.text_color = QLColor.modified
			end
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
			offset = { 108, 60, 5 },
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
			offset = { 148, 60, 5 },
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
			offset = { 178, 60, 5 },
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
			offset = { 218, 60, 5 },
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
			offset = { 248, 60, 5 },
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
			offset = { 288, 60, 5 },
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
			offset = { 108, 80, 5 },
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
			offset = { 148, 80, 5 },
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
			offset = { 178, 80, 5 },
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
			offset = { 218, 80, 5 },
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
			offset = { 328, 60, 5 },
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
			offset = { 368, 70, 10 },
			offset_i2d = { 113, 77, 5 },
			size = { 16, 16 },
			size_i2d = { 13, 13 },
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
			local locked = perk_trait_lock(item, item.perks, 1)
			if locked == "locked" then
				style.color = QLColor.locked
			elseif locked == "modified" then
				style.color = QLColor.modified
			else
				style.color = QLColor.default
			end
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
			offset = { 328, 80, 5 },
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
			offset = { 368, 90, 10 },
			offset_i2d = { 113, 92, 5 },
			size = { 16, 16 },
			size_i2d = { 13, 13 },
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
			local locked = perk_trait_lock(item, item.perks, 2)
			if locked == "locked" then
				style.color = QLColor.locked
			elseif locked == "modified" then
				style.color = QLColor.modified
			else
				style.color = QLColor.default
			end
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
			offset = { 108, 80, 5 },
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
			offset = { 148, 90, 5 },
			offset_i2d = { 42, 59, 5 },
			size = { 16, 16 },
			size_i2d = { 12, 12 },
		},
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 1) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			local item = content.element.item
			local locked = perk_trait_lock(item, item.perks, 1)
			if locked == "locked" then
				style.color = QLColor.locked
			elseif locked == "modified" then
				style.color = QLColor.modified
			else
				style.color = QLColor.default
			end
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
			offset = { 178, 80, 5 },
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
			offset = { 218, 90, 10 },
			offset_i2d = { 87, 59, 5 },
			size = { 16, 16 },
			size_i2d = { 12, 12 },
		},
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 2) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			local item = content.element.item
			local locked = perk_trait_lock(item, item.perks, 2)
			if locked == "locked" then
				style.color = QLColor.locked
			elseif locked == "modified" then
				style.color = QLColor.modified
			else
				style.color = QLColor.default
			end
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
			offset = { 248, 80, 5 },
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
			offset = { 288, 90, 10 },
			offset_i2d = { 132, 59, 5 },
			size = { 16, 16 },
			size_i2d = { 12, 12 },
		},
		visibility_function = function (content, style)
			if not visibility_function_perk(content, style, 3) then
				return false
			end
			if not visibility_function_gadget(content, style) then
				return false
			end
			local item = content.element.item
			local locked = perk_trait_lock(item, item.perks, 3)
			if locked == "locked" then
				style.color = QLColor.locked
			elseif locked == "modified" then
				style.color = QLColor.modified
			else
				style.color = QLColor.default
			end
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
			offset = { 108, 60, 5 },
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
			offset = { 148, 60, 5 },
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

local function fill_weapon_base_stats(content, item)
	if not item.base_stats then
		return
	end
	local template = WeaponTemplates[item.weapon_template]
	if (not template) or (not template.base_stats) then
		return
	end

	-- sort stats, copied from source code
	local weapon_stats = WeaponStats:new(item)
	local comparing_stats = weapon_stats:get_comparing_stats()
	local num_stats = table.size(comparing_stats)
	local comparing_stats_array = {}
	for _, stat in pairs(comparing_stats) do
		comparing_stats_array[#comparing_stats_array + 1] = stat
	end

	-- fill values
	for i = 1, num_stats do
		local stat_data = comparing_stats_array[i]
		local ii = base_stats_position_map[i]
		local title = mod:localize("stat_" .. stat_data.display_name)
		if title == "<" .. "stat_" .. stat_data.display_name .. ">" then
			title = "???"
		end
		local value = math.floor(stat_data.fraction * 100 + 0.5)
		content["qlc_stats_title_" .. tostring(ii)] = title
		content["qlc_stats_value_" .. tostring(ii)] = tostring(value)
	end
	content["qlc_baseLevel"] = tostring(item.baseItemLevel)
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
		fill_weapon_base_stats(content, item)
	elseif item.item_type == "GADGET" then
		fill_gadget_trait(content, item)
	end
	fill_perk(content, item)
	return widget, alignment_widget
end)
