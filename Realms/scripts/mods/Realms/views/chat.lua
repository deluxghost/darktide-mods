local mod = get_mod("Realms")
local ConstantElementChat = require("scripts/ui/constant_elements/elements/chat/constant_element_chat")
local ChatSettings = require("scripts/ui/constant_elements/elements/chat/constant_element_chat_settings")
local InputDevice = require("scripts/managers/input/input_device")
local StringVerification = require("scripts/managers/localization/string_verification")

local ChatView = {}
local CHANNEL_TAG = "realms"
local CHANNEL = {
	tag = CHANNEL_TAG,
}
local Chat

ChatSettings.channel_metadata[CHANNEL_TAG] = {
	name = "loc_realms_chat_channel",
	color = {
		255,
		125,
		184,
		214,
	},
}

local function chat_element()
	local constant_elements = Managers.ui and Managers.ui:ui_constant_elements()

	return constant_elements and constant_elements._elements.ConstantElementChat
end

local function submit_chat(text)
	local sent, send_error = Chat.submit(text)

	if not sent then
		mod:error("%s", send_error)
	end

	return sent
end

local function close_input(self, input_widget)
	input_widget.content.input_text = ""
	input_widget.content.is_writing = false
	self:_enable_mouse_cursor(false)
end

local function handle_console_input(self, input_service, ui_renderer)
	local input_widget = self._input_field_widget

	if not self:using_input() and input_service:get("show_chat") then
		self:_start_chatting(ui_renderer)
	end
	if not self:using_input() then
		return
	end
	if input_service:get("close_view") or input_service:get("back") then
		close_input(self, input_widget)
		self:_update_input_field(ui_renderer, input_widget)

		return
	end

	if IS_XBS then
		if not input_service:get("confirm_pressed") or self._virtual_keyboard_promise then
			return
		end

		local x_game_ui = XGameUI.new_block()

		XGameUI.show_text_entry_async(x_game_ui, "", "", "", "default", ChatSettings.max_message_length)

		self._virtual_keyboard_promise = Managers.xasync:wrap(x_game_ui)

		self._virtual_keyboard_promise:next(function (async_block)
			local text = XGameUI.resolve_text_entry(async_block)
			local last_char = text:sub(#text)

			if last_char == "\x00" then
				text = text:sub(1, #text - 1)
			end
			if text ~= "" then
				submit_chat(text)
			end

			close_input(self, input_widget)
			self:_update_input_field(ui_renderer, input_widget)
			self._virtual_keyboard_promise = nil
		end, function (hr_table)
			local hr = hr_table[1]

			if hr ~= HRESULT.E_ABORT then
				Log.warning("ConstantElementChat", "XBox virtual keyboard closed with 0x%x", hr)
			end

			close_input(self, input_widget)
			self:_update_input_field(ui_renderer, input_widget)
			self._virtual_keyboard_promise = nil
		end)

		return
	end

	if IS_PLAYSTATION then
		local content = input_widget.content

		if input_service:get("confirm_pressed") and not PS5ImeDialog.is_showing() then
			PS5ImeDialog.show({
				max_length = content.max_length,
				placeholder = content.input_text or "",
				title = content.virtual_keyboard_title or content.placeholder_text,
			})
		elseif PS5ImeDialog.is_finished() then
			local result, text = PS5ImeDialog.close()

			content.input_text = result == PS5ImeDialog.END_STATUS_OK and text or content.input_text
		elseif input_service:get("send_chat_message") then
			if content.input_text ~= "" then
				submit_chat(content.input_text)
			end

			close_input(self, input_widget)
			self:_update_input_field(ui_renderer, input_widget)
		end
	end
end

function ChatView.install(chat)
	Chat = chat

	local existing_chat = chat_element()

	if existing_chat then
		Managers.event:unregister(existing_chat, "realms_chat_message")
		Managers.event:register(existing_chat, "realms_chat_message", "cb_realms_chat_message")
	end

	mod:hook(ConstantElementChat, "init", function (func, self, ...)
		local result = func(self, ...)

		Managers.event:register(self, "realms_chat_message", "cb_realms_chat_message")

		return result
	end)

	mod:hook(ConstantElementChat, "destroy", function (func, self, ...)
		Managers.event:unregister(self, "realms_chat_message")

		return func(self, ...)
	end)

	mod:hook(ConstantElementChat, "_handle_active_chat_input", function (func, self, input_service, ui_renderer)
		if not Chat.is_active() then
			return func(self, input_service, ui_renderer)
		end

		local input_widget = self._input_field_widget
		local input_text = input_widget.content.input_text
		local send_realms_message = input_service:get("send_chat_message")
			and #input_text > 0
			and string.sub(input_text, 1, 1) ~= "/"
		local selected_channel_handle = self._selected_channel_handle

		self._selected_channel_handle = nil

		local result = func(self, input_service, ui_renderer)

		self._selected_channel_handle = selected_channel_handle

		if send_realms_message then
			submit_chat(input_text)
			close_input(self, input_widget)
		end

		return result
	end)

	mod:hook(ConstantElementChat, "_handle_console_input", function (func, self, input_service, ui_renderer)
		if Chat.is_active() then
			return handle_console_input(self, input_service, ui_renderer)
		end

		return func(self, input_service, ui_renderer)
	end)

	mod:hook(ConstantElementChat, "_update_input_field", function (func, self, ui_renderer, widget)
		func(self, ui_renderer, widget)

		if not Chat.is_active() then
			return
		end

		local channel_name = Managers.localization:localize("loc_realms_chat_channel")
		local to_channel_text = Managers.localization:localize("loc_chat_to_channel", true, {
			channel_name = channel_name,
		})
		local style = widget.style
		local to_channel_style = style.to_channel

		to_channel_style.text_color = ChatSettings.channel_metadata[CHANNEL_TAG].color
		widget.content.to_channel = to_channel_text

		local field_margin_left = ChatSettings.input_field_margins[1]
		local field_margin_right = ChatSettings.input_field_margins[4]
		local offset = self:_text_size(ui_renderer, to_channel_text, to_channel_style)

		offset = offset + to_channel_style.offset[1] + field_margin_left
		style.display_text.offset[1] = offset
		style.display_text.size = style.display_text.size or {}
		style.display_text.size_addition[1] = -(offset + field_margin_right)
		style.active_placeholder.offset[1] = offset
	end)

	mod:hook(ConstantElementChat, "_setup_input_labels", function (func, self)
		func(self)

		if not Chat.is_active() or not (IS_XBS or IS_PLAYSTATION) or not InputDevice.gamepad_active then
			return
		end

		local input_widget = self._input_field_widget

		if not input_widget.content.is_writing then
			return
		end

		input_widget.content.active_placeholder_text = self:_localize("loc_chat_instruction_placeholder_text", true, {
			cancel_input = self:_get_localized_input_text("back"),
			continue_input = self:_get_localized_input_text("confirm"),
		})
	end)
end

ConstantElementChat.cb_realms_chat_message = function (self, message, sender)
	StringVerification.verify(message):next(function (verified_message)
		if Chat.is_active() then
			self:_add_message(verified_message, sender, CHANNEL)
		end
	end):catch(function (verification_error)
		mod:warning("Chat message verification failed: %s", tostring(verification_error))
	end)
end

return ChatView
