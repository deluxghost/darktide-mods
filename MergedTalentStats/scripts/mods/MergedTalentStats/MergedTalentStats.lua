local mod = get_mod("MergedTalentStats")
local Archetypes = require("scripts/settings/archetype/archetypes")
local BuffTemplates = require("scripts/settings/buff/buff_templates")
local TalentBuilderViewSettings = require("scripts/ui/views/talent_builder_view/talent_builder_view_settings")
local TalentLayoutParser = require("scripts/ui/views/talent_builder_view/utilities/talent_layout_parser")
local UISoundEvents = require("scripts/settings/ui/ui_sound_events")
local CharacterSheet = require("scripts/utilities/character_sheet")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local TalentBuilderViewSummaryBlueprints = require("scripts/ui/views/talent_builder_view/talent_builder_view_summary_blueprints")
local TextUtilities = require("scripts/utilities/ui/text")
local BuffSettings = require("scripts/settings/buff/buff_settings")
local stat_buff_types = BuffSettings.stat_buff_types

mod.on_enabled = function ()
	TalentBuilderViewSettings.settings_by_node_type.stat.sort_order = mod:get("show_stats_on_top") and 0 or 10
end

mod.on_disabled = function ()
	TalentBuilderViewSettings.settings_by_node_type.stat.sort_order = 10
end

mod.on_setting_changed = function (setting_id)
	TalentBuilderViewSettings.settings_by_node_type.stat.sort_order = mod:get("show_stats_on_top") and 0 or 10
end

local function get_buff_name(config)
	if not config.find_value then
		return ""
	end
	local path = config.find_value.path
	local num_path = #path
	for i = 1, num_path - 1 do
		if path[i] == "stat_buffs" then
			return path[i+1]
		end
	end
	return ""
end

local function get_buff_type(config)
	local buff = get_buff_name(config)
	if not buff then
		return "value"
	end
	return stat_buff_types[buff] or "value"
end

local function get_talent_compare_key(talent)
	if not talent.format_values then
		return ""
	end
	local buffs = {}
	for key, config in pairs(talent.format_values) do
		local buff = get_buff_name(config)
		if buff then
			buffs[#buffs+1] = key .. "__" .. buff
		end
	end
	if #buffs > 0 then
		return table.concat(buffs, "____")
	end
	return ""
end

local function get_format_values_keys(first_talent)
	if not first_talent.format_values then
		return {}
	end
	return table.keys(first_talent.format_values)
end

-- related to scripts/ui/views/talent_builder_view/utilities/talent_layout_parser.lua

local function _num_decimals(value)
	local only_decimals = value - math.floor(value)
	local has_digit_10 = false
	local has_digit_100 = false
	local digit_10_v = only_decimals * 10

	if digit_10_v > 1 then
		has_digit_10 = true
	end

	only_decimals = digit_10_v - math.floor(digit_10_v)
	local digit_100_v = only_decimals * 10

	if digit_100_v > 1 then
		has_digit_100 = true
	end

	local num_decimals = nil

	if has_digit_100 then
		num_decimals = 2
	elseif has_digit_10 then
		num_decimals = 1
	else
		num_decimals = 0
	end

	return num_decimals
end

local FORMATING_FUNCTIONS = {
	percentage = function (value_list, config)
		local buff_type = get_buff_type(config)
		local value = 0
		if buff_type == "multiplicative_multiplier" then
			value = 1
			for _, v in ipairs(value_list) do
				value = value * v
			end
		else
			for _, v in ipairs(value_list) do
				value = value + v
			end
		end

		local value_manipulation = config.value_manipulation

		if value_manipulation then
			value = value_manipulation(value)
		else
			value = value * 100
		end

		local num_decimals = config.num_decimals
		num_decimals = num_decimals or _num_decimals(value)
		local formatter = nil

		if num_decimals > 0 then
			formatter = string.format("%%.%df", num_decimals)
		else
			formatter = "%d"
		end

		local value_string = string.format(formatter, value)

		return string.format("%s%%", value_string)
	end,
	number = function (value_list, config)
		local value = 0
		for _, v in ipairs(value_list) do
			value = value + v
		end

		local value_manipulation = config.value_manipulation

		if value_manipulation then
			value = value_manipulation(value)
		end

		local num_decimals = config.num_decimals
		num_decimals = num_decimals or _num_decimals(value)
		local formatter = nil

		if num_decimals > 0 then
			formatter = string.format("%%.%df", num_decimals)
		else
			formatter = "%d"
		end

		return string.format(formatter, value)
	end,
	default = function (value_list, config)
		return tostring(value_list[1])
	end
}

local function _value_from_path(base_table, path)
	local value_table = base_table
	local num_path = #path

	for i = 1, num_path - 1 do
		value_table = value_table[path[i]]
	end

	local key = path[num_path]
	local value = value_table[key]

	return value, key
end

local FIND_VALUE_FUNCTIONS = {
	buff_template = function (config, points_spent)
		local buff_template_name = config.buff_template_name
		local buff_template = BuffTemplates[buff_template_name]
		local base_table = nil

		if config.tier then
			local talent_overrides = buff_template.talent_overrides
			local use_tier = math.clamp(points_spent, 1, #talent_overrides)
			base_table = talent_overrides[use_tier]
		else
			base_table = buff_template
		end

		local value = _value_from_path(base_table, config.path)

		return value
	end,
	default = function (config, points_spent)
		return config.value
	end
}

local function get_stat_talent_desc(merge_data, value_color)
	local first_talent = nil
	for _, data in pairs(merge_data) do
		first_talent = data.talent
		break
	end
	local format_values_keys = get_format_values_keys(first_talent)
	local actual_format_values = nil

	if format_values_keys then
		actual_format_values = {}

		for _, key in ipairs(format_values_keys) do
			local first_config = first_talent.format_values[key]
			local value_list = {}
			for _, data in pairs(merge_data) do
				local talent = data.talent
				local config = talent.format_values[key]
				local value = nil
				local find_value_config = config.find_value

				if find_value_config then
					local find_value_function = FIND_VALUE_FUNCTIONS[find_value_config.find_value_type] or FIND_VALUE_FUNCTIONS.default
					value = find_value_function(find_value_config, 1)
				else
					value = config.value
				end
				for i = 1, data.count do
					value_list[#value_list+1] = value
				end

			end
			local format_type = first_config.format_type
			local format_function = FORMATING_FUNCTIONS[format_type] or FORMATING_FUNCTIONS.default
			local string_value = format_function(value_list, first_config)

			if first_config.prefix then
				string_value = first_config.prefix .. string_value
			end

			if first_config.suffix then
				string_value = string_value .. first_config.suffix
			end

			if value_color then
				actual_format_values[key] = TextUtilities.apply_color_to_text(tostring(string_value), value_color)
			else
				actual_format_values[key] = string.format("%s", string_value)
			end
		end
	end

	local talent_description = Managers.localization:localize(first_talent.description, true, actual_format_values)

	return talent_description
end

-- related to scripts/ui/views/talent_builder_view/talent_builder_view.lua

mod:hook(CLASS.TalentBuilderView, "_setup_talents_summary_grid", function (func, self)
	mod:pcall(function ()
		local definitions = self._definitions

		if not self._summary_grid then
			local grid_scenegraph_id = "summary_grid"
			local scenegraph_definition = definitions.scenegraph_definition
			local grid_scenegraph = scenegraph_definition[grid_scenegraph_id]
			local grid_size = grid_scenegraph.size
			local mask_padding_size = 0
			local grid_settings = {
				scrollbar_width = 7,
				hide_dividers = true,
				widget_icon_load_margin = 0,
				enable_gamepad_scrolling = true,
				title_height = 0,
				scrollbar_horizontal_offset = 18,
				hide_background = true,
				grid_spacing = {
					0,
					0
				},
				grid_size = grid_size,
				mask_size = {
					grid_size[1] + 20,
					grid_size[2] + mask_padding_size
				}
			}
			local layer = (self._draw_layer or 0) + 10
			self._summary_grid = self:_add_element(ViewElementGrid, "summary_grid", layer, grid_settings, grid_scenegraph_id)

			self:_update_element_position("summary_grid", self._summary_grid)
			self._summary_grid:set_empty_message("")
		end

		local grid = self._summary_grid
		local layout = {}
		local active_layout = self:get_active_layout()
		local archetype_name = active_layout.archetype_name
		local archetype = archetype_name and Archetypes[archetype_name]

		if archetype then
			layout[#layout + 1] = {
				widget_type = "dynamic_spacing",
				size = {
					500,
					25
				}
			}
			local points_spent_on_node_widgets = self._points_spent_on_node_widgets
			local nodes_to_present = {}
			local ability_added = false
			local blitz_added = false
			local aura_added = false

			local talent_stats_adder = {}
			for node_name, points_spent in pairs(points_spent_on_node_widgets) do
				if points_spent > 0 then
					local node = self:_node_by_name(node_name)

					if node then
						local talent_name = node.talent
						local talent = archetype.talents[talent_name]

						if talent then
							local node_type = node.type

							if node_type == "stat" then
								local adder_key = get_talent_compare_key(talent)
								talent_stats_adder[adder_key] = talent_stats_adder[adder_key] or {}
								local adder = talent_stats_adder[adder_key]

								-- placeholders
								adder.widget_name = adder.widget_name or node.widget_name
								adder.type = "stat"
								adder.talent = adder.talent or talent
								adder.icon = adder.icon or node.icon

								adder.merge_talents = adder.merge_talents or {}
								adder.merge_talents[talent_name] = adder.merge_talents[talent_name] or {}
								adder.merge_talents[talent_name].talent = talent
								adder.merge_talents[talent_name].count = adder.merge_talents[talent_name].count or 0
								adder.merge_talents[talent_name].count = adder.merge_talents[talent_name].count + 1
							else
								nodes_to_present[#nodes_to_present + 1] = {
									widget_name = node.widget_name,
									type = node_type,
									talent = talent,
									icon = node.icon
								}
							end

							if node_type == "ability" then
								ability_added = true
							elseif node_type == "tactical" then
								blitz_added = true
							elseif node_type == "aura" then
								aura_added = true
							end
						end
					end
				end
			end
			for _, talent_stat in pairs(talent_stats_adder) do
				nodes_to_present[#nodes_to_present + 1] = {
					widget_name = talent_stat.widget_name,
					type = talent_stat.type,
					talent = talent_stat.talent,
					icon = talent_stat.icon,
					merge_talents = talent_stat.merge_talents,
				}
			end

			local base_class_loadout = {
				ability = {},
				blitz = {},
				aura = {}
			}
			local player = self._preview_player
			local profile = player and player:profile()

			CharacterSheet.class_loadout(profile, base_class_loadout, true)

			if not ability_added then
				local talent = base_class_loadout.ability.talent
				nodes_to_present[#nodes_to_present + 1] = {
					points_spent = 1,
					type = "ability",
					talent = talent,
					icon = base_class_loadout.ability.icon
				}
			end

			if not blitz_added then
				local talent = base_class_loadout.blitz.talent
				nodes_to_present[#nodes_to_present + 1] = {
					points_spent = 1,
					type = "tactical",
					talent = talent,
					icon = base_class_loadout.blitz.icon
				}
			end

			if not aura_added then
				local talent = base_class_loadout.aura.talent
				nodes_to_present[#nodes_to_present + 1] = {
					points_spent = 1,
					type = "aura",
					talent = talent,
					icon = base_class_loadout.aura.icon
				}
			end

			table.sort(nodes_to_present, function (a, b)
				local a_type = a.type
				local b_type = b.type
				local a_type_settings = a_type and TalentBuilderViewSettings.settings_by_node_type[a_type]
				local b_type_settings = b_type and TalentBuilderViewSettings.settings_by_node_type[b_type]
				local has_same_sort_order = (a_type_settings and a_type_settings.sort_order or math.huge) == (b_type_settings and b_type_settings.sort_order or math.huge)
				local a_talent = a.talent
				local b_talent = b.talent

				if has_same_sort_order and a_talent and b_talent then
					return Localize(a_talent.display_name) < Localize(b_talent.display_name)
				end

				return (a_type_settings and a_type_settings.sort_order or math.huge) < (b_type_settings and b_type_settings.sort_order or math.huge)
			end)

			local presented_node_type_headers = {}

			for index, data in ipairs(nodes_to_present) do
				local widget_name = data.widget_name
				local points_spent = data.points_spent or points_spent_on_node_widgets[widget_name] or 0
				local talent = type(data.talent) == "table" and data.talent

				if not talent then
					local talent_name = data.talent
					talent = talent_name and archetype.talents[talent_name]
				end

				local description, display_name = nil
				local add = false

				if talent then
					display_name = talent.display_name
					if data.merge_talents then
						description = get_stat_talent_desc(data.merge_talents, Color.ui_terminal(255, true))
					else
						description = TalentLayoutParser.talent_description(talent, points_spent, Color.ui_terminal(255, true))
					end
					add = true
				elseif data.base_talent then
					description = data.description
					display_name = data.display_name
					add = true
				end

				if add then
					local node_type = data.type
					local icon = data.icon
					local gradient_map, frame, icon_mask = nil
					local settings_by_node_type = TalentBuilderViewSettings.settings_by_node_type[node_type]

					if settings_by_node_type then
						local node_gradient_color = data.gradient_color or "not_selected"

						if not node_gradient_color or node_gradient_color == "not_selected" then
							gradient_map = settings_by_node_type.gradient_map
						else
							gradient_map = node_gradient_color
						end

						frame = settings_by_node_type.frame
						icon_mask = settings_by_node_type.icon_mask
					end

					if not presented_node_type_headers[node_type] then
						layout[#layout + 1] = {
							widget_type = "header",
							text = Localize(settings_by_node_type.display_name)
						}
						layout[#layout + 1] = {
							widget_type = "dynamic_spacing",
							size = {
								500,
								10
							}
						}
						presented_node_type_headers[node_type] = true
					end

					layout[#layout + 1] = {
						widget_type = "talent_info",
						talent = talent,
						display_name = display_name,
						description = description,
						gradient_map = gradient_map,
						icon = icon,
						frame = frame,
						icon_mask = icon_mask,
						node_type = node_type
					}

					if node_type ~= "stat" then
						layout[#layout + 1] = {
							widget_type = "dynamic_spacing",
							size = {
								500,
								25
							}
						}
					end
				end
			end

			layout[#layout + 1] = {
				widget_type = "dynamic_spacing",
				size = {
					500,
					25
				}
			}
		end

		grid:present_grid_layout(layout, TalentBuilderViewSummaryBlueprints)
		grid:set_handle_grid_navigation(true)
		self:_play_sound(UISoundEvents.summary_popup_enter)
	end)
end)
