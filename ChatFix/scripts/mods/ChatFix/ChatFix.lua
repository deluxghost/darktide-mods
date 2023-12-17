local mod = get_mod("ChatFix")
local ChatSettings = require("scripts/ui/constant_elements/elements/chat/constant_element_chat_settings")
local InputDevice = require("scripts/managers/input/input_device")

local chat_scroll_multiplier = 1.0

mod.on_enabled = function()
	local inactivity_timeout = mod:get("chat_inactivity_timeout")
	if not inactivity_timeout then
		inactivity_timeout = 10
	end
	ChatSettings.inactivity_timeout = inactivity_timeout
end

mod.on_setting_changed = function(setting_id)
	local inactivity_timeout = mod:get("chat_inactivity_timeout")
	if not inactivity_timeout then
		inactivity_timeout = 10
	end
	ChatSettings.inactivity_timeout = inactivity_timeout
	chat_scroll_multiplier = mod:get("chat_scroll_multiplier") or 1.0
end

mod.on_disabled = function()
	ChatSettings.inactivity_timeout = 5
end

mod:hook("ConstantElementChat", "_add_notification", function(func, self, message, channel_tag)
	if mod:get("chat_join_leave_fix") then
		self._time_since_last_update = 0
	end
	return func(self, message, channel_tag)
end)

mod:hook_origin("ConstantElementChat", "_update_scrollbar", function(self, render_settings)
	-- copied from _update_scrollbar
	local messages = self._messages
	local total_num_messages = #messages
	local total_chat_height = self._total_chat_height
	local chat_window_height = self:scenegraph_size("chat_message_area", render_settings.scale)[2]
	local scrollbar_widget = self._widgets_by_name.chat_scrollbar
	local scrollbar_content = scrollbar_widget.content
	local scroll_value = scrollbar_content.scroll_value
	local total_scroll_length = total_chat_height - chat_window_height
	scrollbar_content.hotspot.is_focused = not InputDevice.gamepad_active or self:using_input()
	scrollbar_content.focused = InputDevice.gamepad_active and self:using_input()
	scrollbar_content.scroll_length = total_scroll_length
	scrollbar_content.area_length = chat_window_height
	-- change start
	scrollbar_content.scroll_amount = chat_scroll_multiplier * (chat_window_height / (math.max(chat_window_height, total_chat_height) * 3))
	-- change end
	local is_scrollbar_active = scrollbar_content.drag_active or scroll_value

	if self._has_scrolled_back_in_history then
		if scroll_value and scroll_value == 1 or not is_scrollbar_active and scrollbar_content.value == 1 then
			self:_scroll_to_latest_message()
		else
			local scroll_length_from_top = self._scroll_length_from_top

			if not is_scrollbar_active then
				scroll_length_from_top = math.max(scroll_length_from_top - self._removed_height_since_last_frame, 0)
				scrollbar_content.value = scroll_length_from_top / total_scroll_length
			else
				scroll_length_from_top = total_scroll_length * scrollbar_content.value
			end

			self:_calculate_first_visible_widget(scroll_length_from_top, chat_window_height)

			self._scroll_length_from_top = scroll_length_from_top
		end
	elseif is_scrollbar_active then
		self._scroll_length_from_top = total_scroll_length * scrollbar_content.value
		self._total_height_last_frame = total_chat_height
		self._has_scrolled_back_in_history = true
	else
		self:_scroll_to_latest_message()
	end

	self._removed_height_since_last_frame = 0
end)
