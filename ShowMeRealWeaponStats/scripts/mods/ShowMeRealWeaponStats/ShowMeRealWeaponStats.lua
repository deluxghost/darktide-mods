local mod = get_mod("ShowMeRealWeaponStats")
require("scripts/ui/view_content_blueprints/item_stats_blueprints")
local Items = require("scripts/utilities/items")
local Text = require("scripts/utilities/ui/text")
local WeaponStats = require("scripts/utilities/weapon_stats")
local InputDevice = require("scripts/managers/input/input_device")

local bar_width = 150

local function fake_item(item)
	local clone = table.clone(item)
	setmetatable(clone, {
		__index = function(t, field_name)
			if field_name == "gear_id" then
				return rawget(clone, "__gear_id")
			end
			if field_name == "gear" then
				return rawget(clone, "__gear")
			end

			local master_item = rawget(clone, "__master_item")
			if not master_item then
				return nil
			end

			local field_value = master_item[field_name]
			if field_name == "rarity" and field_value == -1 then
				return nil
			end
			return field_value
		end,
	})
	return clone
end

local function get_breakdown_compare_string(breakdown)
	local type_data = breakdown.type_data
	local group_type_data = breakdown.group_type_data
	local override_data = breakdown.override_data or {}

	local name = ""
	if type_data.display_name then
		name = name .. type_data.display_name
	end
	if override_data.display_name then
		name = name .. override_data.display_name
	end
	local group_prefix = group_type_data and group_type_data.prefix and group_type_data.prefix or ""
	local prefix = override_data.prefix or type_data.prefix
	prefix = prefix and prefix .. " " or ""
	local postfix = group_type_data and group_type_data.postfix and group_type_data.postfix .. " " or ""
	local suffix = (override_data.suffix or type_data.suffix) and (override_data.suffix or type_data.suffix) or ""
	return string.format("%s %s%s%s%s", group_prefix, prefix, name, suffix, postfix)
end

local function same_breakdown(a, b)
	return get_breakdown_compare_string(a) == get_breakdown_compare_string(b)
end

local function _apply_stat_bar_values(widget, item)
	local content = widget.content
	local style = widget.style
	local weapon_stats = WeaponStats:new(item)
	local comparing_stats = weapon_stats:get_comparing_stats()
	local advanced_weapon_stats = weapon_stats._weapon_statistics
	local bar_breakdown = table.clone(advanced_weapon_stats.bar_breakdown)
	local start_preview_expertise = content.start_expertise_value
	local current_preview_expertise = content.preview_expertise_value and math.max(content.preview_expertise_value - start_preview_expertise, 0) or 0
	local max_preview_expertise = Items.max_expertise_level() - start_preview_expertise
	local current_expertise = Items.expertise_level(item, true)
	local is_preview = current_preview_expertise > 0

	content.show_glow = is_preview

	local added_stats = Items.preview_stats_change(item, current_preview_expertise, comparing_stats)
	local max_stats = Items.preview_stats_change(item, max_preview_expertise, comparing_stats)
	local num_stats = #comparing_stats

	for ii = 1, num_stats do
		local stat_data = comparing_stats[ii]
		local stat = added_stats[stat_data.display_name]
		local max_stat = max_stats[stat_data.display_name]
		local text_id = "text_" .. ii
		local bar_id = "bar_" .. ii
		local bar_bg_id = "bar_bg_" .. ii
		local divider_1_id = "divider_1_" .. ii
		local divider_2_id = "divider_2_" .. ii
		local percentage_id = "percentage_" .. ii

		widget.content.text = Localize(stat_data.display_name)

		local value_bar_width = math.round(bar_width * stat.fraction)
		local bar_style = style[bar_id]

		bar_style.size[1] = value_bar_width
		bar_style.color = is_preview and bar_style.preview_color or bar_style.default_color

		local display_name = Localize(stat_data.display_name)

		content[text_id] = display_name

		local stat_value_string = stat.value

		if is_preview then
			stat_value_string = Text.apply_color_to_text(stat_value_string, Color.ui_blue_light(255, true))
		end

		content[percentage_id] = string.format("[%s/%d]%%", stat_value_string, max_stat.value)

		local bar_bg_style = style[bar_bg_id]
		local max_value_bar_width = math.round(bar_width * max_stat.fraction)

		bar_bg_style.size[1] = max_value_bar_width

		local divider_1_style = style[divider_1_id]

		divider_1_style.offset[1] = bar_bg_style.offset[1] + value_bar_width - 2

		local divider_2_style = style[divider_2_id]

		divider_2_style.offset[1] = bar_bg_style.offset[1] + max_value_bar_width
		content["bar_breakdown_" .. ii] = bar_breakdown[ii]
	end
end

local function get_item_stats(content, item)
	local weapon_stats = WeaponStats:new(item)
	local comparing_stats = weapon_stats:get_comparing_stats()
	local advanced_weapon_stats = weapon_stats._weapon_statistics
	local bar_breakdown = table.clone(advanced_weapon_stats.bar_breakdown)
	local start_preview_expertise = content.start_expertise_value
	local current_preview_expertise = content.preview_expertise_value and math.max(content.preview_expertise_value - start_preview_expertise, 0) or 0
	local max_preview_expertise = Items.max_expertise_level() - start_preview_expertise
	local current_expertise = Items.expertise_level(item, true)

	local added_stats = Items.preview_stats_change(item, current_preview_expertise, comparing_stats)
	local max_stats = Items.preview_stats_change(item, max_preview_expertise, comparing_stats)

	local item_full = fake_item(item)
	for _, stat in pairs(item_full.base_stats) do
		stat.value = mod:get("max_modifier_score") / 100
	end
	local weapon_stats_full = WeaponStats:new(item_full)
	local advanced_weapon_stats_full = weapon_stats_full._weapon_statistics
	local bar_breakdown_full = table.clone(advanced_weapon_stats_full.bar_breakdown)

	return comparing_stats, added_stats, max_stats, bar_breakdown, bar_breakdown_full
end

local function update_stats_styles(content, style, item)
	local comparing_stats, added_stats, max_stats, bar_breakdown, bar_breakdown_full = get_item_stats(content, item)
	local num_stats = #comparing_stats

	for ii = 1, num_stats do
		local stat_data = comparing_stats[ii]
		local stat = added_stats[stat_data.display_name]
		local max_stat = max_stats[stat_data.display_name]
		local bar_id = "bar_" .. ii
		local bar_bg_id = "bar_bg_" .. ii
		local divider_1_id = "divider_1_" .. ii
		local divider_2_id = "divider_2_" .. ii

		local bar_style = style[bar_id]
		local bar_bg_style = style[bar_bg_id]
		local divider_1_style = style[divider_1_id]
		local divider_2_style = style[divider_2_id]

		if mod:get("show_real_max_breakdown") then
			for _, breakdown in ipairs(content["bar_breakdown_" .. ii]) do
				for _, breakdown_full in ipairs(bar_breakdown_full[ii]) do
					if same_breakdown(breakdown, breakdown_full) then
						breakdown.max = breakdown_full.value
					end
				end
			end
		end

		if mod:get("show_full_bar") then
			local multiplier = mod:get("max_modifier_score") > 0 and 100 / mod:get("max_modifier_score") or 100
			local value_bar_width = math.round(bar_width * stat.fraction * multiplier)
			local max_value_bar_width = math.round(bar_width * max_stat.fraction * multiplier)
			bar_style.size[1] = value_bar_width
			if bar_style.size[1] > bar_width then
				bar_style.size[1] = bar_width
			end
			bar_bg_style.size[1] = max_value_bar_width
			if bar_bg_style.size[1] > bar_width then
				bar_bg_style.size[1] = bar_width
			end
			divider_1_style.offset[1] = bar_bg_style.offset[1] + value_bar_width - 2
			divider_2_style.offset[1] = bar_bg_style.offset[1] + max_value_bar_width
		end
	end
end

mod:hook(package.loaded, "scripts/ui/view_content_blueprints/item_stats_blueprints", function(generate_blueprints_function, grid_size, optional_item)
	local blueprints = generate_blueprints_function(grid_size, optional_item)
	if not blueprints.weapon_stats or not blueprints.weapon_stats.init or not blueprints.weapon_stats.update then
		return blueprints
	end

	local old_init = blueprints.weapon_stats.init
	blueprints.weapon_stats.init = function(parent, widget, element, callback_name)
		local ret = old_init(parent, widget, element, callback_name)

		local content = widget.content
		local style = widget.style
		local item = element.item

		update_stats_styles(content, style, item)
		return ret
	end

	blueprints.weapon_stats.update = function(parent, widget, input_service, dt, t, ui_renderer)
		local content = widget.content
		local style = widget.style
		local total_stats = content.element.show_base_rating and 6 or 5
		local item = content.element.item

		_apply_stat_bar_values(widget, item)
		update_stats_styles(content, style, item)

		if not content.element.interactive then
			return
		end

		local parent_active = true

		if type(parent.is_active) == "function" then
			parent_active = parent:is_active()
		end

		local stat_data

		if InputDevice.gamepad_active then
			local gamepad_selected_index_x = content.gamepad_selected_index[1]
			local gamepad_selected_index_y = content.gamepad_selected_index[2]
			local index_x = gamepad_selected_index_x or 1
			local index_y = gamepad_selected_index_y or 1
			local gamepad_bar_matrix = content.gamepad_bar_matrix

			if input_service:get("navigate_up_continuous") then
				index_y = math.max(index_y - 1, 1)
			elseif input_service:get("navigate_down_continuous") then
				index_y = math.min(index_y + 1, #gamepad_bar_matrix)
			elseif input_service:get("navigate_left_continuous") then
				index_x = math.max(index_x - 1, 1)
			elseif input_service:get("navigate_right_continuous") then
				index_x = math.min(index_x + 1, #gamepad_bar_matrix[index_y])
			end

			content.gamepad_selected_index[1] = index_x
			content.gamepad_selected_index[2] = index_y

			local selected_index = gamepad_bar_matrix[index_y][index_x]

			for ii = 1, total_stats do
				local is_hover = parent_active and ii == selected_index

				style["hover_frame_" .. ii].color[1] = is_hover and 128 or 0
				style["hover_frame_border_" .. ii].color[1] = is_hover and 128 or 0
				style["hover_frame_corner_" .. ii].color[1] = is_hover and 128 or 0
				stat_data = is_hover and content["bar_breakdown_" .. ii] or stat_data
			end
		else
			for ii = 1, total_stats do
				local hotspot = content["hotspot_" .. ii]
				local is_hover = parent_active and hotspot.is_hover

				style["hover_frame_" .. ii].color[1] = is_hover and 128 or 0
				style["hover_frame_border_" .. ii].color[1] = is_hover and 128 or 0
				style["hover_frame_corner_" .. ii].color[1] = is_hover and 128 or 0
				stat_data = is_hover and content["bar_breakdown_" .. ii] or stat_data
			end
		end

		if parent.update_bar_breakdown_data then
			parent:update_bar_breakdown_data(stat_data)
		end
	end
	return blueprints
end)
