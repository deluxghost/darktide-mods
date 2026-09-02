local mod = get_mod("Realms")
local GameModeManager = require("scripts/managers/game_mode/game_mode_manager")

local LocalHostPhysics = {}
local SINGLE_THREADED_REASON = "RealmsLocalHost"

function LocalHostPhysics.install(Session)
	mod:hook(GameModeManager, "init", function (func, self, game_mode_context, ...)
		func(self, game_mode_context, ...)

		if game_mode_context.is_server and Session.is_active_host() then
			self:set_wants_single_threaded_physics(true, SINGLE_THREADED_REASON)
		end
	end)
end

return LocalHostPhysics
