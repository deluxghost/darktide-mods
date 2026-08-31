local mod = get_mod("Realms")
local ConstantElementNotificationFeed = require("scripts/ui/constant_elements/elements/notification_feed/constant_element_notification_feed")

local NotificationFeed = {}
local player_snapshots = setmetatable({}, {__mode = "k"})

local function snapshot_player(data)
	local player = data.player

	if not player or player.__deleted then
		return nil
	end

	local player_name = player:name()
	local player_slot = player:slot()
	local profile = player:profile()

	return {
		name = function ()
			return player_name
		end,
		profile = function ()
			return profile
		end,
		slot = function ()
			return player_slot
		end,
	}
end

function NotificationFeed.install(Session)
	mod:hook(ConstantElementNotificationFeed, "event_add_notification_message", function (func, self, message_type, data, ...)
		if type(data) == "table" and data.player and Session.is_active() then
			player_snapshots[data] = snapshot_player(data)
		end

		return func(self, message_type, data, ...)
	end)

	mod:hook(ConstantElementNotificationFeed, "_generate_notification_data", function (func, self, message_type, data)
		local snapshot = player_snapshots[data]

		if not snapshot then
			return func(self, message_type, data)
		end

		player_snapshots[data] = nil

		local player = data.player

		if not player or not player.__deleted then
			return func(self, message_type, data)
		end

		local safe_data = table.clone(data)

		safe_data.player = snapshot

		return func(self, message_type, safe_data)
	end)
end

return NotificationFeed
