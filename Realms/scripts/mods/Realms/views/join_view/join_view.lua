local mod = get_mod("Realms")
local dmf = get_mod("DMF")
local ViewElementInputLegend = require("scripts/ui/view_elements/view_element_input_legend/view_element_input_legend")
local TextInputUtils = dmf:io_dofile("dmf/scripts/mods/dmf/modules/ui/options/text_input_utils")
local JoinTarget = mod:io_dofile("Realms/scripts/mods/Realms/core/join_target")
local NativeEos = mod:io_dofile("Realms/scripts/mods/Realms/runtime/eos")
local Session = mod._session
local definitions = mod:io_dofile("Realms/scripts/mods/Realms/views/join_view/join_view_definitions")

local SERVER_ADDRESS_SETTING_ID = "join_server_address"
local HIDE_SERVER_ADDRESS_SETTING_ID = "hide_join_server_address"
local PASSWORD_MODE_HEIGHT_REDUCTION = 64
local ADDRESS_CHARACTER_MAP = {
	["。"] = ".",
	["．"] = ".",
	["｡"] = ".",
	["："] = ":",
	["［"] = "[",
	["］"] = "]",
	["　"] = " ",
}
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


RealmsJoinView.init = function (self, settings, context)
	self._join_context = context and context.submit and context or nil
	self._focus_names = self._join_context and {"password_input", "connect_button"} or FOCUS_WIDGET_NAMES
	self._input_names = self._join_context and {"password_input"} or {"server_address_input", "password_input"}
	local view_definitions = definitions

	if self._join_context then
		view_definitions = table.clone(definitions)
		local graph = view_definitions.scenegraph_definition
		local widgets = view_definitions.widget_definitions

		graph.panel.size[2] = graph.panel.size[2] - PASSWORD_MODE_HEIGHT_REDUCTION
		graph.password_label.position[2] = graph.password_label.position[2] - PASSWORD_MODE_HEIGHT_REDUCTION
		graph.password_input.position[2] = graph.password_input.position[2] - PASSWORD_MODE_HEIGHT_REDUCTION
		graph.error_text.position[2] = graph.error_text.position[2] - PASSWORD_MODE_HEIGHT_REDUCTION
		widgets.server_address_input = nil
		widgets.title.content[widgets.title.passes[1].value_id] = mod:localize("join_steam_password_title")
		local host_name = context.steam_id and Steam.user_name(Steam.id_dec_to_hex(context.steam_id))

		widgets.server_address_label.content[widgets.server_address_label.passes[1].value_id] = host_name and host_name ~= ""
			and mod:localize("join_steam_host", host_name) or mod:localize("join_password_required")
	end

	RealmsJoinView.super.init(self, view_definitions, settings, context)
end

RealmsJoinView.on_enter = function (self)
	RealmsJoinView.super.on_enter(self)

	local server_address = mod:get(SERVER_ADDRESS_SETTING_ID) or ""
	if not self._join_context then
		local address_content = self._widgets_by_name.server_address_input.content

		set_input_value(address_content, server_address)
		address_content.mask_input = mod:get(HIDE_SERVER_ADDRESS_SETTING_ID)
	elseif self._join_context.incorrect then
		self:_set_error(Managers.localization:localize("loc_realms_password_incorrect"))
	end

	self._focus_index = 1
	self._server_address = server_address
	self._input_signature = server_address .. "\31"
	self._last_password = ""
	self._widgets_by_name.connect_button.content.hotspot.pressed_callback = callback(self, "cb_on_connect_pressed")

	for i = 1, #self._input_names do
		self._widgets_by_name[self._input_names[i]].content.hotspot.use_is_focused = true
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
	for i = 1, #self._focus_names do
		local hotspot = self._widgets_by_name[self._focus_names[i]].content.hotspot
		local focused = not self._using_cursor_navigation and i == self._focus_index

		hotspot.is_focused = focused
		hotspot.is_selected = focused
	end
end

RealmsJoinView._active_input_content = function (self)
	for i = 1, #self._input_names do
		local content = self._widgets_by_name[self._input_names[i]].content

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
		self._focus_index = math.min(self._focus_index + 1, #self._focus_names)
		self:_update_focus()
	end
end

RealmsJoinView.update = function (self, dt, t, input_service)
	local pass_input, pass_draw = RealmsJoinView.super.update(self, dt, t, input_service)

	if input_service then
		for i = 1, #self._input_names do
			local focused = not self._using_cursor_navigation and i == self._focus_index

			update_text_input(self._widgets_by_name[self._input_names[i]].content, input_service, focused)
		end
	end

	self:_update_input_values()

	if not self._join_context then
		-- Without a target there is nothing to connect to. An empty password is still a valid attempt.
		self._widgets_by_name.connect_button.content.hotspot.disabled = (self._widgets_by_name.server_address_input.content.input_text or "") == ""
	end

	if self._resolving_code and not mod._eos.is_resolving() then
		self._resolving_code = false
		Managers.ui:close_view(self.view_name)
	end

	return pass_input, pass_draw
end

RealmsJoinView._report_code_failure = function (self, message)
	if not self._resolving_code then
		return false
	end

	self._resolving_code = false
	self:_set_error(message)

	return true
end

RealmsJoinView._update_input_values = function (self)
	if self._join_context then
		local password = self._widgets_by_name.password_input.content.input_text

		if self._last_password and self._last_password ~= password then
			self:_set_error()
		end

		self._last_password = password

		return
	end
	local content = self._widgets_by_name.server_address_input.content
	local server_address = content.input_text or ""

	if not content.is_writing and server_address ~= self._normalized_server_address then
		local normalized = server_address

		for character, replacement in pairs(ADDRESS_CHARACTER_MAP) do
			normalized = string.gsub(normalized, character, replacement)
		end

		normalized = string.trim(normalized)
		self._normalized_server_address = normalized

		if normalized ~= server_address then
			TextInputUtils.clear_selection(content)
			set_input_value(content, normalized)
			server_address = normalized
		end
	end

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
end

RealmsJoinView._set_error = function (self, message)
	self._widgets_by_name.error_text.content.text = message or ""
end

RealmsJoinView.cb_on_connect_pressed = function (self)
	if self._join_context then
		finish_editing(self._widgets_by_name.password_input.content)

		local accepted, submit_error = self._join_context.submit(self._widgets_by_name.password_input.content.input_text or "")

		if not accepted then
			self:_set_error(submit_error)

			return
		end

		self._submitted = true
		Managers.ui:close_view(self.view_name)

		return
	end
	finish_editing(self._widgets_by_name.server_address_input.content)
	self:_update_input_values()

	local address_value = self._widgets_by_name.server_address_input.content.input_text or ""
	local password = self._widgets_by_name.password_input.content.input_text or ""
	local invite_code = NativeEos.normalize_code(address_value)

	if invite_code then
		-- Addresses always carry a port, so a bare six-character value can only be an invite code.
		local accepted, join_error = mod._eos.join(invite_code, password, callback(self, "_report_code_failure"))

		if not accepted then
			self:_set_error(join_error)

			return
		end

		-- Stay open until the code resolves so a lookup failure is reported here.
		self._resolving_code = true
		self:_set_error()

		return
	end

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
		self:_update_input_values()

		return
	end

	Managers.ui:close_view(self.view_name)
end

RealmsJoinView.on_exit = function (self)
	-- Failures that arrive after the view closes become notifications.
	self._resolving_code = false
	for i = 1, #self._input_names do
		finish_editing(self._widgets_by_name[self._input_names[i]].content)
	end

	self:_update_input_values()
	if self._join_context and not self._submitted then
		self._join_context.cancel()
	end

	RealmsJoinView.super.on_exit(self)
end

return RealmsJoinView
