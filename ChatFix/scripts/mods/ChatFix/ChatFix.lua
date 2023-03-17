local mod = get_mod("ChatFix")
local ChatSettings = require("scripts/ui/constant_elements/elements/chat/constant_element_chat_settings")

mod.on_enabled = function(initial_call)
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
end

mod.on_disabled = function(initial_call)
	ChatSettings.inactivity_timeout = 5
end

mod:hook("ConstantElementChat", "_add_notification", function(func, self, message, channel_tag)
	if mod:get("chat_join_leave_fix") then
		self._time_since_last_update = 0
	end
	return func(self, message, channel_tag)
end)
