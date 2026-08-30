local DisconnectReason = {}

DisconnectReason.CONNECTION_FAILED = "realms_connection_failed"
DisconnectReason.CONNECTION_LOST = "realms_connection_lost"
DisconnectReason.SERVER_CLOSED = "realms_server_closed"
DisconnectReason.SERVER_PRIVATE = "realms_server_private"
DisconnectReason.SERVER_FULL = "realms_server_full"
DisconnectReason.PASSWORD_INCORRECT = "realms_password_incorrect"
DisconnectReason.PROTOCOL_MISMATCH = "realms_protocol_mismatch"
DisconnectReason.GAME_VERSION_MISMATCH = "realms_game_version_mismatch"
DisconnectReason.SERVER_CONTEXT_INVALID = "realms_server_context_invalid"
DisconnectReason.CLIENT_DATA_REJECTED = "realms_client_data_rejected"
DisconnectReason.SERVER_ERROR = "realms_server_error"
DisconnectReason.HOST_BOOT_FAILED = "realms_host_boot_failed"

local LOCALIZATION_KEYS = {
	[DisconnectReason.CONNECTION_FAILED] = "loc_realms_connection_failed",
	[DisconnectReason.CONNECTION_LOST] = "loc_realms_connection_lost",
	[DisconnectReason.SERVER_CLOSED] = "loc_realms_server_closed",
	[DisconnectReason.SERVER_PRIVATE] = "loc_realms_server_private",
	[DisconnectReason.SERVER_FULL] = "loc_realms_server_full",
	[DisconnectReason.PASSWORD_INCORRECT] = "loc_realms_password_incorrect",
	[DisconnectReason.PROTOCOL_MISMATCH] = "loc_realms_protocol_mismatch",
	[DisconnectReason.GAME_VERSION_MISMATCH] = "loc_realms_game_version_mismatch",
	[DisconnectReason.SERVER_CONTEXT_INVALID] = "loc_realms_server_context_invalid",
	[DisconnectReason.CLIENT_DATA_REJECTED] = "loc_realms_client_data_rejected",
	[DisconnectReason.SERVER_ERROR] = "loc_realms_server_error",
	[DisconnectReason.HOST_BOOT_FAILED] = "loc_realms_host_boot_failed",
}

function DisconnectReason.is_known(reason)
	return LOCALIZATION_KEYS[reason] ~= nil
end

function DisconnectReason.localization_key(reason)
	return LOCALIZATION_KEYS[reason]
end

return DisconnectReason
