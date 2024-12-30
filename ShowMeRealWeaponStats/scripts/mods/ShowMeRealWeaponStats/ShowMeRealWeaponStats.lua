local mod = get_mod("ShowMeRealWeaponStats")
require("scripts/ui/view_content_blueprints/item_stats_blueprints")
local Items = require("scripts/utilities/items")
local Text = require("scripts/utilities/ui/text")
local WeaponStats = require("scripts/utilities/weapon_stats")
local InputDevice = require("scripts/managers/input/input_device")
local ViewElementWeaponInfo = require("scripts/ui/view_elements/view_element_weapon_info/view_element_weapon_info")

local bar_width = 150

local function fake_item(item)
	local clone = table.clone(item)
	setmetatable(clone, {
		__index = function (t, field_name)
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

local function _apply_stat_bar_values(widget, item, init)
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

	local bar_breakdown_full_array = content.__smrws_bar_breakdown_full
	local bar_breakdown_dump_array = content.__smrws_bar_breakdown_dump
	local bar_breakdown_potential_array = content.__smrws_bar_breakdown_potential
	local range_opt = mod:get("substats_range_display_mode")

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

		local bar_breakdown = content["bar_breakdown_" .. ii]
		local bar_breakdown_full = bar_breakdown_full_array[ii]
		local bar_breakdown_dump = bar_breakdown_dump_array[ii]
		local bar_breakdown_potential = bar_breakdown_potential_array[ii]
		local num_bar_breakdown = #bar_breakdown
		local num_bar_breakdown_full = #bar_breakdown_full
		local num_bar_breakdown_dump = #bar_breakdown_dump
		local num_bar_breakdown_potential = #bar_breakdown_potential

		if init then
			local new_bar_breakdown_full, new_bar_breakdown_dump, new_bar_breakdown_potential = {}, {}, {}
			for i = 1, num_bar_breakdown do
				for j = 1, num_bar_breakdown_full do
					if same_breakdown(bar_breakdown[i], bar_breakdown_full[j]) then
						new_bar_breakdown_full[i] = bar_breakdown_full[j]
						break
					end
				end
				for j = 1, num_bar_breakdown_dump do
					if same_breakdown(bar_breakdown[i], bar_breakdown_dump[j]) then
						new_bar_breakdown_dump[i] = bar_breakdown_dump[j]
						break
					end
				end
				for j = 1, num_bar_breakdown_potential do
					if same_breakdown(bar_breakdown[i], bar_breakdown_potential[j]) then
						new_bar_breakdown_potential[i] = bar_breakdown_potential[j]
						break
					end
				end
			end
			bar_breakdown_full_array[ii] = new_bar_breakdown_full
			bar_breakdown_dump_array[ii] = new_bar_breakdown_dump
			bar_breakdown_potential_array[ii] = new_bar_breakdown_potential
		end

		for idx, breakdown in ipairs(content["bar_breakdown_" .. ii]) do
			if range_opt == "0_80" or range_opt == "60_80" then
				breakdown.max = bar_breakdown_full_array[ii][idx].value
			end
			if range_opt == "60_80" then
				breakdown.min = bar_breakdown_dump_array[ii][idx].value
			end
			if mod:get("current_substats_display_mode") == "potential" then
				breakdown.potential = bar_breakdown_potential_array[ii][idx].value
			end
		end

		if mod:get("show_full_bar") then
			local multiplier = mod:get("max_modifier_score") > 0 and 100 / mod:get("max_modifier_score") or 100
			local value_bar_width_full = math.round(bar_width * stat.fraction * multiplier)
			local max_value_bar_width_full = math.round(bar_width * max_stat.fraction * multiplier)
			bar_style.size[1] = value_bar_width_full
			if bar_style.size[1] > bar_width then
				bar_style.size[1] = bar_width
			end
			bar_bg_style.size[1] = max_value_bar_width_full
			if bar_bg_style.size[1] > bar_width then
				bar_bg_style.size[1] = bar_width
			end
			divider_1_style.offset[1] = bar_bg_style.offset[1] + value_bar_width_full - 2
			divider_2_style.offset[1] = bar_bg_style.offset[1] + max_value_bar_width_full
		end
	end
end

mod:hook(package.loaded, "scripts/ui/view_content_blueprints/item_stats_blueprints", function (generate_blueprints_function, grid_size, optional_item)
	local blueprints = generate_blueprints_function(grid_size, optional_item)
	if not blueprints.weapon_stats or not blueprints.weapon_stats.init or not blueprints.weapon_stats.update then
		return blueprints
	end

	blueprints.weapon_stats.init = function (parent, widget, element, callback_name)
		local content = widget.content
		local style = widget.style

		content.element = element
		style.background.visible = not not element.add_background

		local item = element.item
		local weapon_stats = WeaponStats:new(item)
		local current_expertise = Items.expertise_level(item, true)

		content.start_expertise_value = tonumber(current_expertise)
		local comparing_stats = weapon_stats:get_comparing_stats()
		local max_preview_expertise = Items.max_expertise_level() - content.start_expertise_value
		local max_stats = Items.preview_stats_change(item, max_preview_expertise, comparing_stats)

		local item_full = fake_item(item)
		for _, stat in pairs(item_full.base_stats) do
			stat.value = mod:get("max_modifier_score") / 100
		end
		local weapon_stats_full = WeaponStats:new(item_full)
		content.__smrws_bar_breakdown_full = weapon_stats_full._weapon_statistics.bar_breakdown

		local item_dump = fake_item(item)
		for _, stat in pairs(item_dump.base_stats) do
			stat.value = mod:get("max_dump_modifier_score") / 100
		end
		local weapon_stats_dump = WeaponStats:new(item_dump)
		content.__smrws_bar_breakdown_dump = weapon_stats_dump._weapon_statistics.bar_breakdown

		local item_potential = fake_item(item)
		local stats_name_map = {}
		for _, stat in ipairs(comparing_stats) do
			stats_name_map[stat.name] = stat.display_name
		end
		for _, stat in pairs(item_potential.base_stats) do
			if stats_name_map[stat.name] and max_stats[stats_name_map[stat.name]] then
				stat.value = max_stats[stats_name_map[stat.name]].fraction
			end
		end
		local weapon_stats_potential = WeaponStats:new(item_potential)
		content.__smrws_bar_breakdown_potential = weapon_stats_potential._weapon_statistics.bar_breakdown

		_apply_stat_bar_values(widget, item, true)

		content.bar_breakdown_6 = {
			description = "loc_weapon_stats_display_base_rating_desc",
			display_name = "loc_weapon_stats_display_base_rating",
			name = "base_rating",
		}
		content.gamepad_bar_matrix = {
			{
				1,
				2,
				6,
			},
			{
				4,
				5,
				3,
			},
		}
		content.gamepad_selected_index = {}
		parent._weapon_advanced_stats = weapon_stats._weapon_statistics

		local show_base_stats = content.element.show_base_rating

		if show_base_stats then
			local base_stats_rating = Items.calculate_stats_rating(item)

			content.text_extra_value = " " .. base_stats_rating
			style.text_extra_value.text_color = Color.white(255, true)
			style.text_extra_value.font_size = 30
			style.text_extra_value.offset[2] = style.text_extra_value.offset[2] - 10
		end
	end

	blueprints.weapon_stats.update = function (parent, widget, input_service, dt, t, ui_renderer)
		local content = widget.content
		local style = widget.style
		local total_stats = content.element.show_base_rating and 6 or 5
		local item = content.element.item

		_apply_stat_bar_values(widget, item, false)

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

mod:hook(ViewElementWeaponInfo, "_get_stats_text", function (func, self, stat)
	local override_data = stat.override_data or {}
	local type_data = stat.type_data
	local display_type = override_data.display_type or type_data.display_type
	local is_signed = type_data.signed
	local value = self:_scale_value_by_type(stat.value, display_type)
	local value_text = self:_value_to_text(value, is_signed)
	local range = ""
	local min, max = stat.min, stat.max

	if min and max then
		min = self:_scale_value_by_type(min, display_type)
		max = self:_scale_value_by_type(max, display_type)
		range = string.format("{#color(150,150,150)}[%s | %s]", self:_value_to_text(min, is_signed), self:_value_to_text(max, is_signed))
	end

	local name = Localize(override_data.display_name or type_data.display_name)
	local group_type_data = stat.group_type_data
	local group_prefix = group_type_data and group_type_data.prefix and Localize(group_type_data.prefix) or ""
	local prefix = override_data.prefix or type_data.prefix

	prefix = prefix and Localize(prefix) .. " " or ""

	local postfix = group_type_data and group_type_data.postfix and Localize(group_type_data.postfix) .. " " or ""
	local display_units = override_data.display_units or type_data.display_units or ""
	local suffix = (override_data.suffix or type_data.suffix) and Localize(override_data.suffix or type_data.suffix) or ""
	local prefix_display_units = override_data.prefix_display_units or type_data.prefix_display_units or ""
	local stat_text = ""
	if mod:get("current_substats_display_mode") == "potential" then
		local potential = self:_scale_value_by_type(stat.potential or stat.value, display_type)
		local potential_text = self:_value_to_text(potential, is_signed)
		stat_text = string.format(
			"%s %s%s%s%s:  {#color(250,189,73)}%s%s%s / %s%s%s   %s",
			group_prefix, prefix, name, suffix, postfix,
			prefix_display_units, value_text, display_units,
			prefix_display_units, potential_text, display_units,
			range
		)
	else
		stat_text = string.format(
			"%s %s%s%s%s:  {#color(250,189,73)}%s%s%s   %s",
			group_prefix, prefix, name, suffix, postfix,
			prefix_display_units, value_text, display_units,
			range
		)
	end

	return stat_text
end)
