local SessionBootBase = require("scripts/multiplayer/session_boot_base")

local STATES = table.enum("waiting")
local ReusedHostSessionBoot = class("RealmsReusedHostSessionBoot", "SessionBootBase")

ReusedHostSessionBoot.init = function (self, event_object, leaving_game_session)
	ReusedHostSessionBoot.super.init(self, STATES, event_object)

	self.leaving_game_session = leaving_game_session
	self:_set_state(STATES.waiting)
end

ReusedHostSessionBoot.result = function ()
	return nil
end

return ReusedHostSessionBoot
