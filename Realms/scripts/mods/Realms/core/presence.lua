local mod = get_mod("Realms")
local PresenceSettings = require("scripts/settings/presence/presence_settings")

local Presence = {}

local LOADING_GAME_STATE = "StateLoading"
local LOADING_ACTIVITY = "loading"
local HUB_ACTIVITY = "hub"
local REALMS_ACTIVITY = "training_grounds"

function Presence.install(Session)
	mod:hook(PresenceSettings, "evaluate_presence", function (func, game_state)
		if Session.is_active() then
			if game_state == LOADING_GAME_STATE then
				return LOADING_ACTIVITY
			end

			return Session.is_hub_or_shooting_range() and HUB_ACTIVITY or REALMS_ACTIVITY
		end

		return func(game_state)
	end)
end

return Presence
