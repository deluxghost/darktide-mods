local mod = get_mod("SoloPlay")
local SliderPassTemplates = require("scripts/ui/pass_templates/slider_pass_templates")
local view_settings = mod:io_dofile("SoloPlay/scripts/mods/SoloPlay/soloplay_mod_view/soloplay_mod_view_settings")

local SLIDER_ENDPLATE_WIDTH = 4
local SLIDER_THUMB_SIZE = 38

local modifier_slider_template = table.clone(
	SliderPassTemplates.settings_value_slider(view_settings.slider_size[1], view_settings.slider_size[2], view_settings.slider_setting_width, true)
)
for _, pass in ipairs(modifier_slider_template) do
	if pass.value_id == "text" then
		pass.style.font_size = 18
		pass.style.offset[1] = 15
		pass.style.size[1] = view_settings.slider_size[1] - view_settings.slider_setting_width
	end
end
modifier_slider_template[#modifier_slider_template+1] = {
	style_id = "setting_indicator",
	pass_type = "rect",
	style = {
		vertical_alignment = "center",
		color = Color.terminal_corner_hover(255, true),
		size = { 2, 45 },
		offset = { 8, 0, 0 },
	},
}

local slider_init_function = function (parent, widget, entry, callback_name)
	local view = parent
	if parent.__class_name == "ViewElementGrid" then
		view = parent._parent
	end
	local content = widget.content

	content.entry = entry
	content.entry.value_width = entry.value_width
	content.area_length = content.entry.value_width
	content.step_size = entry.normalized_step_size

	if not entry.normalized_step_size and entry.step_size_value then
		local value_range = entry.max_value - entry.min_value
		content.step_size = entry.step_size_value / value_range
	end

	content.apply_on_drag = entry.apply_on_drag and true

	local get_function = entry.get_function
	local value = get_function(entry)

	content.text = entry.display_name or "n/a"
	if entry.modifier_name then
		content.text = view:_get_modifier_display_name(entry.modifier_name, value)
	end

	content.previous_slider_value = value
	content.slider_value = value

	entry.pressed_callback = function ()
		local is_disabled = entry.is_disabled
		if is_disabled then
			return
		end
		callback(view, "cb_on_slider_pressed", widget, entry)()
	end
end

local slider_update_function = function (parent, widget, input_service, dt, t)
	local view = parent
	if parent.__class_name == "ViewElementGrid" then
		view = parent._parent
	end
	local content = widget.content
	local entry = content.entry
	local pass_input = true
	local is_disabled = entry.disabled or false
	content.disabled = is_disabled

	if content.entry.modifier_name then
		local slider_area_width = view_settings.slider_setting_width - (SLIDER_ENDPLATE_WIDTH * 2 + SLIDER_THUMB_SIZE)
		local header_width = view_settings.slider_size[1] - view_settings.slider_setting_width
		local slider_horizontal_offset = header_width + SLIDER_ENDPLATE_WIDTH

		local slider_value = content.slider_value or 0
		content.slider_horizontal_offset = slider_horizontal_offset + slider_value * slider_area_width
	end

	local using_gamepad = not Managers.ui:using_cursor_navigation()
	local min_value = entry.min_value
	local max_value = entry.max_value
	local get_function = entry.get_function
	local explode_function = entry.explode_function
	local value = get_function(entry)
	local normalized_value = math.normalize_01(value, min_value, max_value)
	local on_drag_value = entry.on_drag_value
	local on_activated = entry.on_activated
	local format_value_function = entry.format_value_function
	local drag_value, new_normalized_value
	local apply_on_drag = content.apply_on_drag and not is_disabled
	local drag_active = content.drag_active and not is_disabled
	local drag_previously_active = content.drag_previously_active
	local focused = content.exclusive_focus and using_gamepad and not is_disabled

	if drag_active or focused then
		if not view._selected_setting then
			view:_set_exclusive_focus_on_setting(widget.name)
		end

		local slider_value = content.slider_value

		drag_value = slider_value and explode_function(slider_value, entry) or get_function(entry)
	elseif not focused or drag_previously_active then
		local previous_slider_value = content.previous_slider_value
		local slider_value = content.slider_value

		if drag_previously_active then
			view:_set_exclusive_focus_on_setting(nil)

			if previous_slider_value ~= slider_value then
				new_normalized_value = slider_value
				drag_value = slider_value and explode_function(slider_value, entry) or get_function(entry)
			end
		elseif normalized_value ~= slider_value then
			content.slider_value = normalized_value
			content.previous_slider_value = normalized_value
			content.scroll_add = nil
		end

		content.previous_slider_value = slider_value
	end

	content.drag_previously_active = drag_active

	local display_value = format_value_function(drag_value or value)

	if display_value then
		content.value_text = display_value
		if view._get_modifier_display_name and entry.modifier_name then
			content.text = view:_get_modifier_display_name(entry.modifier_name, drag_value or value)
		end
		if on_drag_value then
			on_drag_value(drag_value or value, entry)
		end
	end

	local hotspot = content.hotspot

	if hotspot.on_pressed then
		if focused then
			new_normalized_value = content.slider_value
		elseif using_gamepad and entry.pressed_callback then
			entry.pressed_callback()
		end
	end

	if focused and view:can_exit() then
		view:set_can_exit(false)
	end

	if apply_on_drag and drag_value and not new_normalized_value and content.slider_value ~= content.previous_slider_value then
		new_normalized_value = content.slider_value
	end

	if new_normalized_value then
		local new_value = explode_function(new_normalized_value, entry)

		on_activated(new_value, entry)

		content.slider_value = new_normalized_value
		content.previous_slider_value = new_normalized_value
		content.scroll_add = nil
	end

	return pass_input
end

local havoc_badge_pass_function = function (rank)
	local rank_badges = view_settings.havoc_rank_badges
	local letter_size = {
		40.95,
		40.95
	}
	local letter_margin = 8.57
	local current_rank = rank
	local current_rank_badge = rank_badges[#rank_badges]

	for i = 1, #rank_badges do
		local rank_badge = rank_badges[i]
		local level = rank_badge.level
		if current_rank and current_rank < level then
			current_rank_badge = rank_badges[i - 1]
			break
		end
	end

	local pass_templates = {}

	pass_templates[#pass_templates + 1] = {
		value_id = "current_havoc_rank_badge",
		style_id = "current_havoc_rank_badge",
		pass_type = "texture",
		value = "content/ui/materials/base/ui_default_base",
		style = {
			horizontal_alignment = "center",
			color = Color.white(255, true),
			offset = {
				0,
				56,
				10
			},
			size = view_settings.havoc_badge_size,
			material_values = {
				texture_map = current_rank_badge.texture
			}
		}
	}

	local current_rank_to_string = tostring(current_rank)
	local current_rank_width = (letter_size[1] - letter_margin * 2) * #current_rank_to_string
	local start_next_offset = (view_settings.havoc_badge_size[1] - current_rank_width) * 0.5 - letter_margin

	for i = 1, #current_rank_to_string do
		local rank_number = tonumber(string.sub(current_rank_to_string, i, i))
		local x_offset = start_next_offset + (letter_size[1] - letter_margin * 2) * (i - 1)

		pass_templates[#pass_templates + 1] = {
			pass_type = "texture",
			value = "content/ui/materials/frames/havoc_numbers",
			value_id = "current_havoc_rank_value_" .. i,
			style_id = "current_havoc_rank_value_" .. i,
			style = {
				horizontal_alignment = "left",
				start_offset_y = 104,
				size = {
					letter_size[1],
					letter_size[2]
				},
				color = Color.white(255, true),
				offset = {
					x_offset,
					104,
					6
				},
				material_values = {
					number = rank_number
				}
			}
		}
	end
	return pass_templates
end

local blueprints = {
	spacing_vertical = {
		size = {
			view_settings.grid_settings.grid_size[1],
			10,
		}
	},
	settings_dropdown = {
		update = function (parent, widget, input_service, dt, t)
			local content = widget.content
			local entry = content.entry

			if content.close_setting then
				content.close_setting = nil
				content.exclusive_focus = false

				local hotspot = content.hotspot or content.button_hotspot
				if hotspot then
					hotspot.is_selected = false
				end
				return
			end

			local is_disabled = entry.disabled or false
			content.disabled = is_disabled

			local size = { view_settings.dropdown_setting_width, view_settings.dropdown_size[2] }
			local using_gamepad = not Managers.ui:using_cursor_navigation()
			local offset = widget.offset
			local style = widget.style
			local options = content.options
			local options_by_id = content.options_by_id
			local num_visible_options = content.num_visible_options
			local num_options = #options
			local focused = content.exclusive_focus and not is_disabled

			if focused then
				offset[3] = 90
			else
				offset[3] = 0
			end

			local selected_index = content.selected_index
			local value, new_value
			local hotspot = content.hotspot
			local hotspot_style = style.hotspot

			if selected_index and focused then
				if using_gamepad and hotspot.on_pressed then
					new_value = options[selected_index].id
				end
				hotspot_style.on_pressed_sound = hotspot_style.on_pressed_fold_in_sound
			else
				hotspot_style.on_pressed_sound = hotspot_style.on_pressed_fold_out_sound
			end

			if entry.get_function then
				value = entry.get_function(entry)
			else
				value = content.internal_value or "<not selected>"
			end

			local localization_manager = Managers.localization
			local preview_option = options_by_id[value]
			local preview_option_id = preview_option and preview_option.id
			local preview_value = preview_option and preview_option.display_name or "loc_settings_option_unavailable"
			local ignore_localization = preview_option and preview_option.ignore_localization
			content.value_text = ignore_localization and preview_value or localization_manager:localize(preview_value)

			local always_keep_order = true
			local grow_downwards = true
			content.grow_downwards = grow_downwards

			local new_selection_index
			if not selected_index or not focused then
				for i = 1, #options do
					local option = options[i]

					if option.id == preview_option_id then
						selected_index = i

						break
					end
				end
				selected_index = selected_index or 1
			end

			if selected_index and focused then
				if input_service:get("navigate_up_continuous") then
					if grow_downwards or not grow_downwards and always_keep_order then
						new_selection_index = math.max(selected_index - 1, 1)
					else
						new_selection_index = math.min(selected_index + 1, num_options)
					end
				elseif input_service:get("navigate_down_continuous") then
					if grow_downwards or not grow_downwards and always_keep_order then
						new_selection_index = math.min(selected_index + 1, num_options)
					else
						new_selection_index = math.max(selected_index - 1, 1)
					end
				end
			end

			if new_selection_index or not content.selected_index then
				if new_selection_index then
					selected_index = new_selection_index
				end

				if num_visible_options < num_options then
					local step_size = 1 / num_options
					local new_scroll_percentage = math.min(selected_index - 1, num_options) * step_size

					content.scroll_percentage = new_scroll_percentage
					content.scroll_add = nil
				end

				content.selected_index = selected_index
			end

			local scroll_percentage = content.scroll_percentage

			if scroll_percentage then
				local step_size = 1 / (num_options - (num_visible_options - 1))
				content.start_index = math.max(1, math.ceil(scroll_percentage / step_size))
			end

			local option_hovered = false
			local option_index = 1
			local start_index = content.start_index or 1
			local end_index = math.min(start_index + num_visible_options - 1, num_options)
			local using_scrollbar = num_visible_options < num_options

			for i = start_index, end_index do
				local actual_i = i

				if not grow_downwards and always_keep_order then
					actual_i = end_index - i + start_index
				end

				local option_text_id = "option_text_" .. option_index
				local option_hotspot_id = "option_hotspot_" .. option_index
				local outline_style_id = "outline_" .. option_index
				local option_hotspot = content[option_hotspot_id]

				option_hovered = option_hovered or option_hotspot.is_hover
				option_hotspot.is_selected = actual_i == selected_index

				local option = options[actual_i]

				if option_hotspot.on_pressed then
					option_hotspot.on_pressed = nil
					new_value = option.id
					content.selected_index = actual_i
				end

				local option_display_name = option.display_name
				local option_ignore_localization = option.ignore_localization

				content[option_text_id] = option_ignore_localization and option_display_name or localization_manager:localize(option_display_name)

				local options_y = size[2] * option_index

				style[option_hotspot_id].offset[2] = grow_downwards and options_y or -options_y
				style[option_text_id].offset[2] = grow_downwards and options_y or -options_y

				local entry_length = using_scrollbar and size[1] - style.scrollbar_hotspot.size[1] or size[1]

				style[outline_style_id].size[1] = entry_length
				style[option_text_id].size[1] = size[1]
				option_index = option_index + 1
			end

			local value_changed = new_value ~= nil

			if value_changed and new_value ~= value then
				local on_activated = entry.on_activated
				on_activated(new_value, entry, content)
			end

			local scrollbar_hotspot = content.scrollbar_hotspot
			local scrollbar_hovered = scrollbar_hotspot.is_hover

			if (input_service:get("left_pressed") or input_service:get("confirm_pressed") or input_service:get("back")) and content.exclusive_focus and not content.wait_next_frame then
				content.wait_next_frame = true
				return
			end

			if content.wait_next_frame then
				content.wait_next_frame = nil
				content.close_setting = true
				return
			end
		end,
	},
	modifier_slider = {
		size = view_settings.slider_size,
		pass_template = modifier_slider_template,
		init = slider_init_function,
		update = slider_update_function,
	},
	havoc_difficulty_slider = {
		size = view_settings.difficulty_slider_size,
		pass_template = SliderPassTemplates.value_slider(view_settings.difficulty_slider_size[1], view_settings.difficulty_slider_size[2], 0, true),
		init = slider_init_function,
		update = slider_update_function,
	},
	havoc_badge = {
		pass_template_function = havoc_badge_pass_function,
	}
}

return blueprints
