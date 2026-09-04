local mod = get_mod("Realms")
local MultiplayerSession = require("scripts/managers/multiplayer/multiplayer_session")
local MultiplayerSessionManager = require("scripts/managers/multiplayer/multiplayer_session_manager")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local RealmsConnectionError = mod:io_dofile("Realms/scripts/mods/Realms/errors/realms_connection_error")

local DisconnectErrors = {}

local ENGINE_LEFT_SESSION_REASON = "leave_to_hub"

function DisconnectErrors.normalize_left_session_reason(mechanism_name, context)
	if mechanism_name ~= "left_session" or type(context) ~= "table" then
		return
	end

	local reason = context.left_session_reason

	if not DisconnectReason.is_known(reason) then
		return
	end

	mod:info("Mapping left session reason %s to %s", tostring(reason), ENGINE_LEFT_SESSION_REASON)

	context.left_session_reason = ENGINE_LEFT_SESSION_REASON
end

function DisconnectErrors.install()
	mod:hook(MultiplayerSession, "disconnected_from_host", function (func, self, is_error, source, reason, details)
		local session_manager = Managers.multiplayer_session
		local expected_leave = reason == "realms_disconnect" or reason == "realms_switch_session" or session_manager and session_manager:is_leaving()

		if self._realms_protocol and not expected_leave and (not is_error or not DisconnectReason.is_known(reason)) then
			mod:info("Replacing unstructured disconnect reason=%s details=%s", tostring(reason), type(details) == "table" and table.tostring(details, 3) or tostring(details))
			is_error = true
			reason = DisconnectReason.CONNECTION_LOST
		end

		return func(self, is_error, source, reason, details)
	end)

	mod:hook(MultiplayerSessionManager, "_show_session_error", function (func, self, disconnection_info)
		local reason = disconnection_info.reason

		if not DisconnectReason.is_known(reason) then
			return func(self, disconnection_info)
		end

		Managers.error:report_error(RealmsConnectionError:new(disconnection_info.source, reason, disconnection_info.error_details))
	end)
end

return DisconnectErrors
