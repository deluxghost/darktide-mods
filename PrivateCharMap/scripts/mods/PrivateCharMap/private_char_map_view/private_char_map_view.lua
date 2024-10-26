local mod = get_mod("PrivateCharMap")
local ScriptWorld = require("scripts/foundation/utilities/script_world")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local ViewElementGrid = require("scripts/ui/view_elements/view_element_grid/view_element_grid")
local definitions = mod:io_dofile("PrivateCharMap/scripts/mods/PrivateCharMap/private_char_map_view/private_char_map_view_definitions")

local bytemarkers = { {0x7FF, 192}, {0xFFFF, 224}, {0x1FFFFF, 240} }

local function utf8(decimal)
	if decimal < 128 then
		return string.char(decimal)
	end
	local charbytes = {}
	for bytes, vals in ipairs(bytemarkers) do
		if decimal <= vals[1] then
			for b = bytes + 1, 2, -1 do
				local mod = decimal % 64
				decimal = (decimal - mod) / 64
				charbytes[b] = string.char(128 + mod)
			end
			charbytes[1] = string.char(vals[2] + decimal)
			break
		end
	end
	return table.concat(charbytes)
end

PrivateCharMapView = class("PrivateCharMapView", "BaseView")

PrivateCharMapView.init = function(self, settings)
	PrivateCharMapView.super.init(self, definitions, settings)
end

PrivateCharMapView.on_enter = function(self)
	PrivateCharMapView.super.on_enter(self)
	self:_setup_input_legend()
	self:_setup_grid()
end

PrivateCharMapView._setup_input_legend = function(self)
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

PrivateCharMapView._setup_grid = function(self)
	self._char_table_element = self:_add_element(ViewElementGrid, "char_table", 103, definitions.grid_settings, "char_table_pivot")
	self._char_table_element:set_visibility(true)
	self._char_table_element:present_grid_layout({}, {})
	local layout = {}

	for i = 0xe000, 0xe3ff do
		layout[#layout + 1] = {
			widget_type = "char_box",
			char_index = i - 0xe000 + 1,
			char_pos = string.format("U+%04X", i),
			char_text = utf8(i),
		}
	end

	local spacing_entry = {
		widget_type = "spacing_vertical"
	}

	table.insert(layout, 1, spacing_entry)
	table.insert(layout, #layout + 1, spacing_entry)

	local left_click_callback = callback(self, "cb_on_char_left_pressed")

	self._char_table_element:present_grid_layout(layout, definitions.blueprints, left_click_callback)
end

PrivateCharMapView.cb_on_char_left_pressed = function(self, widget, element)
	if widget and widget.content and widget.content.char_pos and widget.content.char_text then
		Clipboard.put(widget.content.char_text)
		mod:notify(mod:localize("msg_copied_char", widget.content.char_text, widget.content.char_pos))
	end
end

PrivateCharMapView._on_back_pressed = function(self)
	Managers.ui:close_view(self.view_name)
end

PrivateCharMapView._destroy_renderer = function(self)
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

PrivateCharMapView.update = function(self, dt, t, input_service)
	return PrivateCharMapView.super.update(self, dt, t, input_service)
end

PrivateCharMapView.draw = function(self, dt, t, input_service, layer)
	PrivateCharMapView.super.draw(self, dt, t, input_service, layer)
end

PrivateCharMapView._draw_widgets = function(self, dt, t, input_service, ui_renderer, render_settings)
	PrivateCharMapView.super._draw_widgets(self, dt, t, input_service, ui_renderer, render_settings)
end

PrivateCharMapView.on_exit = function(self)
	PrivateCharMapView.super.on_exit(self)

	self:_destroy_renderer()
end

return PrivateCharMapView
