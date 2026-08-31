local mod = get_mod("Realms")
local ScriptCJson = require("scripts/foundation/utilities/script_cjson")
local ProfileUpdate = mod:io_dofile("Realms/scripts/mods/Realms/protocol/profile_update")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local GameplayControlProtocol = {}

GameplayControlProtocol.NAME = "realms-gameplay-control"
GameplayControlProtocol.VERSION = SessionTicket.PROTOCOL_VERSION
GameplayControlProtocol.MAX_MESSAGE_SIZE = 96 * 1024

local MESSAGE_VALIDATORS = {
	hello = function (data)
		return table.size(data) == 0
	end,
	profile_pending = ProfileUpdate.valid_pending_data,
	profile_cancel = ProfileUpdate.valid_pending_data,
	profile_update = ProfileUpdate.valid_update_data,
	server_settings = function (data)
		return table.size(data) == 1
			and type(data.max_members) == "number"
			and data.max_members % 1 == 0
			and data.max_members >= 2
			and data.max_members <= 8
	end,
	gameplay_time_scale = function (data)
		return table.size(data) == 1
			and type(data.scale) == "number"
			and data.scale >= 0
			and data.scale <= 10
	end,
	shooting_range_inventory = function (data)
		return table.size(data) == 1 and type(data.open) == "boolean"
	end,
	shooting_range_status = function (data)
		return table.size(data) == 1 and type(data.invulnerable) == "boolean"
	end,
}

local function validate_message(message)
	if type(message) ~= "table"
		or message.protocol ~= GameplayControlProtocol.NAME
		or message.version ~= GameplayControlProtocol.VERSION
		or type(message.type) ~= "string"
		or type(message.data) ~= "table"
	then
		return false, "Invalid gameplay-control protocol envelope"
	end

	local validator = MESSAGE_VALIDATORS[message.type]

	if not validator or not validator(message.data) then
		return false, "Invalid gameplay-control message"
	end

	return true
end

function GameplayControlProtocol.encode(message_type, data)
	local message = {
		data = data or {},
		protocol = GameplayControlProtocol.NAME,
		type = message_type,
		version = GameplayControlProtocol.VERSION,
	}
	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	local encoded, payload = pcall(ScriptCJson.encode_lua_to_json_for_lua, message)

	if not encoded then
		return nil, "Gameplay-control protocol message is not JSON serializable: " .. tostring(payload)
	end
	if #payload > GameplayControlProtocol.MAX_MESSAGE_SIZE then
		return nil, "Gameplay-control protocol message exceeds the size limit"
	end

	return payload
end

function GameplayControlProtocol.decode(payload)
	if type(payload) ~= "string" or #payload == 0 or #payload > GameplayControlProtocol.MAX_MESSAGE_SIZE then
		return nil, "Invalid gameplay-control protocol message size"
	end

	local decoded, message = pcall(cjson.decode, payload)

	if not decoded then
		return nil, "Gameplay-control protocol payload is not valid JSON"
	end

	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	return message
end

return GameplayControlProtocol
