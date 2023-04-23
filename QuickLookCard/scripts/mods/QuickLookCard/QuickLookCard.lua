local mod = get_mod("QuickLookCard")
local WeaponTemplates = require("scripts/settings/equipment/weapon_templates/weapon_templates")
local WeaponStats = require("scripts/utilities/weapon_stats")

local function visibility_function_weapon(content, style)
	if not mod:is_enabled() then
		return false
	end
	if (not content) or (not content.element) or (not content.element.item) then
		return false
	end
	local item = content.element.item
	return item.item_type == "WEAPON_MELEE" or item.item_type == "WEAPON_RANGED"
end


local item_definitions = {
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
			size = { 120, 36 },
			text_color = {255, 250, 250, 250},
			font_type = "proxima_nova_bold",
			font_size = 16,
		},
		value = "",
		visibility_function = function (content, style)
			if not visibility_function_weapon(content, style) then
				return false
			end
			local item = content.element.item
			if item.rarity and item.rarity < 2 then
				return false
			end
			return true
		end,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_title_1",
		value_id = "qlc_stats_title_1",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 108, 60, 5 },
			size = { 120, 36 },
			text_color = {255, 250, 250, 250},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
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
			size = { 120, 36 },
			text_color = {255, 250, 189, 73},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
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
			size = { 120, 36 },
			text_color = {255, 250, 250, 250},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
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
			size = { 120, 36 },
			text_color = {255, 250, 189, 73},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_title_3",
		value_id = "qlc_stats_title_3",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 248, 80, 5 },
			size = { 120, 36 },
			text_color = {255, 250, 250, 250},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
	},
	{
		pass_type = "text",
		style_id = "qlc_stats_value_3",
		value_id = "qlc_stats_value_3",
		style = {
			vertical_alignment = "top",
			horizontal_alignment = "left",
			text_vertical_alignment = "center",
			offset = { 288, 80, 5 },
			size = { 120, 36 },
			text_color = {255, 250, 189, 73},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
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
			size = { 120, 36 },
			text_color = {255, 250, 250, 250},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
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
			size = { 120, 36 },
			text_color = {255, 250, 189, 73},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
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
			size = { 120, 36 },
			text_color = {255, 250, 250, 250},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
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
			size = { 120, 36 },
			text_color = {255, 250, 189, 73},
			font_type = "machine_medium",
			font_size = 18,
		},
		value = "",
		visibility_function = visibility_function_weapon,
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
		table.insert(instance.item, def)
	end
	return instance
end)

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
	if not item.base_stats then
		return widget, alignment_widget
	end
	local template = WeaponTemplates[item.weapon_template]
	if (not template) or (not template.base_stats) then
		return widget, alignment_widget
	end

	-- sort stats, copied from source code
	local weapon_stats = WeaponStats:new(item)
	local compairing_stats = weapon_stats:get_compairing_stats()
	local num_stats = table.size(compairing_stats)
	local compairing_stats_array = {}
	for _, stat in pairs(compairing_stats) do
		compairing_stats_array[#compairing_stats_array + 1] = stat
	end

	local weapon_stats_sort_order = {
		rate_of_fire = 2,
		attack_speed = 2,
		damage = 1,
		stamina_block_cost = 4,
		reload_speed = 4,
		stagger = 3
	}
	local function sort_function(a, b)
		local a_sort_order = weapon_stats_sort_order[a.type] or math.huge
		local b_sort_order = weapon_stats_sort_order[b.type] or math.huge

		return a_sort_order < b_sort_order
	end
	table.sort(compairing_stats_array, sort_function)

	-- fill values
	for i = 1, num_stats do
		local stat_data = compairing_stats_array[i]
		local title = mod:localize("stat_" .. stat_data.display_name)
		if title == "<" .. "stat_" .. stat_data.display_name .. ">" then
			title = "???"
		end
		local value = math.floor(stat_data.fraction * 100 + 0.5)
		content["qlc_stats_title_" .. tostring(i)] = title
		content["qlc_stats_value_" .. tostring(i)] = tostring(value)
	end
	content["qlc_baseLevel"] = tostring(item.baseItemLevel)

	return widget, alignment_widget
end)
