local mod = get_mod("Realms")
local ErrorManager = require("scripts/managers/error/error_manager")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")

local RealmsConnectionError = class("RealmsConnectionError")

RealmsConnectionError.init = function (self, source, reason, details)
	self._reason = reason
	self._log_message = string.format("source=%s reason=%s details=%s", tostring(source), tostring(reason), type(details) == "table" and table.tostring(details, 3) or tostring(details or "n/a"))
end

RealmsConnectionError.level = function ()
	return ErrorManager.ERROR_LEVEL.warning_popup
end

RealmsConnectionError.log_message = function (self)
	return self._log_message
end

RealmsConnectionError.loc_title = function ()
	return "loc_realms_connection_error_title"
end

RealmsConnectionError.loc_description = function (self)
	return DisconnectReason.localization_key(self._reason)
end

RealmsConnectionError.options = function ()
	return
end

return RealmsConnectionError
