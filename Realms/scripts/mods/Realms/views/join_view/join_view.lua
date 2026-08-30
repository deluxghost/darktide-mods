local mod = get_mod("Realms")
local dmf = get_mod("DMF")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local TextInputUtils = dmf:io_dofile("dmf/scripts/mods/dmf/modules/ui/options/text_input_utils")
local JoinTarget = mod:io_dofile("Realms/scripts/mods/Realms/core/join_target")
local Session = mod._session
local definitions = mod:io_dofile("Realms/scripts/mods/Realms/views/join_view/join_view_definitions")

local SERVER_ADDRESS_SETTING_ID = "join_server_address"
local FOCUS_WIDGET_NAMES = {
	"server_address_input",
	"password_input",
	"connect_button",
}

RealmsJoinView = class("RealmsJoinView", "BaseView")

local function finish_editing(content)
	content.is_writing = false
	TextInputUtils.clear_selection(content)
end

local function update_text_input(content, input_service, focused)
	local hotspot = content.hotspot

	if content.is_writing then
		if input_service:get("left_pressed") and not hotspot.is_hover then
			finish_editing(content)
		end
	else
		TextInputUtils.clear_selection(content)
	end

	hotspot.is_selected = focused or content.is_writing
end

local function set_input_value(content, value)
	content.input_text = value
	content.display_text = value
	content._input_text = nil
	content.caret_position = Utf8.string_length(value) + 1
	content._caret_position = nil
	content._input_text_first_visible_pos = 1
	content.force_caret_update = true
end


RealmsJoinView.init = function (self, settings)
	RealmsJoinView.super.init(self, definitions, settings)
end

RealmsJoinView.on_enter = function (self)
	RealmsJoinView.super.on_enter(self)

	local server_address = mod:get(SERVER_ADDRESS_SETTING_ID) or ""
	local address_content = self._widgets_by_name.server_address_input.content

	set_input_value(address_content, server_address)

	self._focus_index = 1
	self._server_address = server_address
	self._input_signature = server_address .. "\31"
	self._widgets_by_name.connect_button.content.hotspot.pressed_callback = callback(self, "cb_on_connect_pressed")

	for i = 1, 2 do
		self._widgets_by_name[FOCUS_WIDGET_NAMES[i]].content.hotspot.use_is_focused = true
	end

	self:_setup_input_legend()
	self:_update_focus()
end

RealmsJoinView._setup_input_legend = function (self)
	self._input_legend_element = self:_add_element(ViewElementInputLegend, "input_legend", 100)
	self._input_legend_element:add_entry(
		"loc_class_selection_button_back",
		"back",
		nil,
		callback(self, "_on_back_pressed"),
		"left_alignment"
	)
end

RealmsJoinView._update_focus = function (self)
	for i = 1, #FOCUS_WIDGET_NAMES do
		local hotspot = self._widgets_by_name[FOCUS_WIDGET_NAMES[i]].content.hotspot
		local focused = not self._using_cursor_navigation and i == self._focus_index

		hotspot.is_focused = focused
		hotspot.is_selected = focused
	end
end

RealmsJoinView._active_input_content = function (self)
	for i = 1, 2 do
		local content = self._widgets_by_name[FOCUS_WIDGET_NAMES[i]].content

		if content.is_writing then
			return content, i
		end
	end
end

RealmsJoinView._on_navigation_input_changed = function (self)
	RealmsJoinView.super._on_navigation_input_changed(self)

	self:_update_focus()
end

RealmsJoinView._handle_input = function (self, input_service, dt, t)
	RealmsJoinView.super._handle_input(self, input_service, dt, t)

	if self._using_cursor_navigation then
		return
	end

	local input_content = self:_active_input_content()

	if input_content then
		return
	end

	if input_service:get("navigate_up_continuous") then
		self._focus_index = math.max(self._focus_index - 1, 1)
		self:_update_focus()
	elseif input_service:get("navigate_down_continuous") then
		self._focus_index = math.min(self._focus_index + 1, #FOCUS_WIDGET_NAMES)
		self:_update_focus()
	end
end

RealmsJoinView.update = function (self, dt, t, input_service)
	local pass_input, pass_draw = RealmsJoinView.super.update(self, dt, t, input_service)

	if input_service then
		for i = 1, 2 do
			local focused = not self._using_cursor_navigation and i == self._focus_index

			update_text_input(self._widgets_by_name[FOCUS_WIDGET_NAMES[i]].content, input_service, focused)
		end
	end

	local server_address = self._widgets_by_name.server_address_input.content.input_text or ""
	local input_signature = server_address
		.. "\31"
		.. (self._widgets_by_name.password_input.content.input_text or "")

	if server_address ~= self._server_address then
		self._server_address = server_address
		mod:set(SERVER_ADDRESS_SETTING_ID, server_address)
	end

	if input_signature ~= self._input_signature then
		self._input_signature = input_signature
		self:_set_error()
	end

	return pass_input, pass_draw
end

RealmsJoinView._set_error = function (self, message)
	self._widgets_by_name.error_text.content.text = message or ""
end

RealmsJoinView.cb_on_connect_pressed = function (self)
	local address_value = self._widgets_by_name.server_address_input.content.input_text or ""
	local password = self._widgets_by_name.password_input.content.input_text or ""
	local server_address, server_port, parse_error = JoinTarget.parse(address_value)

	if not server_address then
		self:_set_error(parse_error)

		return
	end

	local started, start_error = Session.start_client(server_address, server_port, password)

	if not started then
		self:_set_error(start_error)

		return
	end

	self:_set_error()
	Managers.ui:close_view(self.view_name)
end

RealmsJoinView._on_back_pressed = function (self)
	local input_content = self:_active_input_content()

	if input_content then
		finish_editing(input_content)

		return
	end

	Managers.ui:close_view(self.view_name)
end

return RealmsJoinView
