local mod = get_mod("ColorViewer")
local ScriptWorld = require("scripts/foundation/utilities/script_world")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local definitions = mod:io_dofile("ColorViewer/scripts/mods/ColorViewer/color_viewer_view/color_viewer_view_definitions")

ColorViewerView = class("ColorViewerView", "BaseView")

ColorViewerView.init = function (self, settings)
	ColorViewerView.super.init(self, definitions, settings)
end

ColorViewerView.on_enter = function (self)
	ColorViewerView.super.on_enter(self)
	self:_setup_input_legend()
	self:_setup_color_table_grid()
	self:_setup_color_table_sort_options()
	self:_setup_control_grid()
end

ColorViewerView._setup_input_legend = function (self)
	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 100)
	local legend_inputs = self._definitions.legend_inputs

	for i = 1, #legend_inputs do
		local legend_input = legend_inputs[i]
		local on_pressed_callback = legend_input.on_pressed_callback and callback(self, legend_input.on_pressed_callback)

		self._input_legend_element:add_entry(
			legend_input.display_name,
			legend_input.input_action,
			legend_input.visibility_function,
			on_pressed_callback,
			legend_input.alignment
		)
	end
end

ColorViewerView.present_grid_layout = function (self, layout)
	local layout_copy = table.clone(layout)
	local spacing_entry = {
		widget_type = "color_table_spacing_vertical"
	}

	table.insert(layout_copy, 1, spacing_entry)
	table.insert(layout_copy, #layout_copy + 1, spacing_entry)
	local left_click_callback = callback(self, "cb_on_color_left_pressed")
	self._color_table_element:present_grid_layout(layout_copy, definitions.blueprints, left_click_callback)
end

ColorViewerView._setup_color_table_grid = function (self)
	self._color_table_element = self:_add_element(ViewElementGrid, "color_table", 103, definitions.color_table_grid_settings, "color_table_pivot")
	self._color_table_element:set_visibility(true)
	self._color_table_element:present_grid_layout({}, {})
	self._color_table_element._selected_color = nil
	local layout = {}

	for _, color_name in ipairs(Color.list) do
		local color = Color[color_name](nil, true)
		local ahsl = mod.argb_to_ahsl(color)
		layout[#layout + 1] = {
			widget_type = "color_box",
			color_name = color_name,
			color_data = color,
			color_ahsl = ahsl,
		}
	end

	table.sort(layout, function (a, b)
		return a.color_name < b.color_name
	end)
	self._layout = layout

	self:present_grid_layout(layout)
end

ColorViewerView._setup_color_table_sort_options = function (self)
	self._sort_options = {
		{
			display_name = mod:localize("sort_option_name_asc"),
			sort_function = mod.sort_comparator({
				"<", mod.compare_color_name,
			}),
		},
		{
			display_name = mod:localize("sort_option_name_desc"),
			sort_function = mod.sort_comparator({
				">", mod.compare_color_name,
			}),
		},
		{
			display_name = mod:localize("sort_option_hue"),
			sort_function = mod.sort_comparator({
				"<", mod.compare_color_mono,
				"<", mod.compare_color_hue,
				">", mod.compare_color_alpha,
			}),
		},
		{
			display_name = mod:localize("sort_option_saturation"),
			sort_function = mod.sort_comparator({
				"<", mod.compare_color_mono,
				">", mod.compare_color_saturation,
				"<", mod.compare_color_alpha,
			}),
		},
		{
			display_name = mod:localize("sort_option_lightness"),
			sort_function = mod.sort_comparator({
				">", mod.compare_color_lightness,
				"<", mod.compare_color_alpha,
			}),
		},
	}
	if self._sort_options and #self._sort_options > 0 then
		local sort_callback = callback(self, "cb_on_sort_button_pressed")

		self._color_table_element:setup_sort_button(self._sort_options, sort_callback)
	end
end

ColorViewerView.cb_on_sort_button_pressed = function (self, option)
	local option_sort_index
	local sort_options = self._sort_options

	for i = 1, #sort_options do
		if sort_options[i] == option then
			option_sort_index = i
			break
		end
	end

	if option_sort_index ~= self._selected_sort_option_index then
		self._selected_sort_option_index = option_sort_index
		self._selected_sort_option = option

		local sort_function = option.sort_function

		self:_sort_grid_layout(sort_function)
	end
end

ColorViewerView._sort_grid_layout = function (self, sort_function)
	local layout = table.clone(self._layout)

	if sort_function and #layout > 1 then
		table.sort(layout, sort_function)
	end
	self:present_grid_layout(layout)

	local selected_widget_index = 1
	for index, widget in ipairs(self._color_table_element._grid_widgets) do
		if widget.content.color_codename == self._color_table_element._selected_color then
			selected_widget_index = index
			break
		end
	end
	self._color_table_element:select_grid_index(selected_widget_index, nil, true)
	self._color_table_element:scroll_to_grid_index(selected_widget_index, true)
end

ColorViewerView._setup_control_grid = function (self)
	self._control_element = self:_add_element(ViewElementGrid, "control", 103, definitions.control_grid_settings, "control_pivot")
	self._control_element:set_visibility(false)
	self._control_element:present_grid_layout({}, {})
end

ColorViewerView._update_control_grid = function (self, color_name)
	local color = Color[color_name](nil, true)
	local layout = {
		{
			widget_type = "control_spacing_vertical"
		},
		{
			widget_type = "color_header",
			color_name = color_name,
			color_data = color,
		},
		{
			widget_type = "copy_text_box",
			copy_type = "Lua",
			text_to_copy = string.format("Color.%s(nil, true)", color_name),
		},
		{
			widget_type = "copy_text_box",
			copy_type = "ARGB",
			text_to_copy = string.format("%d, %d, %d, %d", color[1], color[2], color[3], color[4]),
		},
		{
			widget_type = "copy_text_box",
			copy_type = "ARGB HEX",
			text_to_copy = mod.argb_to_hex(color),
		},
	}

	local left_click_callback = callback(self, "cb_on_copy_left_pressed")

	self._color_table_element._selected_color = color_name
	self._control_element:present_grid_layout(layout, definitions.blueprints, left_click_callback)
	self._control_element:set_visibility(true)
end

ColorViewerView.cb_on_color_left_pressed = function (self, widget, element)
	if widget and widget.content and widget.content.color_codename then
		self:_update_control_grid(widget.content.color_codename)
	end
end

ColorViewerView.cb_on_copy_left_pressed = function (self, widget, element)
	if widget and widget.content and widget.content.text_to_copy and widget.content.copy_type then
		Clipboard.put(widget.content.text_to_copy)
		mod:notify(mod:localize("msg_copied", widget.content.copy_type))
	end
end

ColorViewerView._on_back_pressed = function (self)
	Managers.ui:close_view(self.view_name)
end

ColorViewerView._destroy_renderer = function (self)
	if self._offscreen_renderer then
		self._offscreen_renderer = nil
	end

	local world_data = self._offscreen_world

	if world_data then
		Managers.ui:destroy_renderer(world_data.renderer_name)
		ScriptWorld.destroy_viewport(world_data.world, world_data.viewport_name)
		Managers.ui:destroy_world(world_data.world)

		world_data = nil
	end
end

ColorViewerView.update = function (self, dt, t, input_service)
	return ColorViewerView.super.update(self, dt, t, input_service)
end

ColorViewerView.draw = function (self, dt, t, input_service, layer)
	ColorViewerView.super.draw(self, dt, t, input_service, layer)
end

ColorViewerView._draw_widgets = function (self, dt, t, input_service, ui_renderer, render_settings)
	ColorViewerView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

ColorViewerView.on_exit = function (self)
	ColorViewerView.super.on_exit(self)

	self:_destroy_renderer()
end

return ColorViewerView
