local mod = get_mod("Realms")
local ScriptCJson = require("scripts/foundation/utilities/script_cjson")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local SessionControlProtocol = {}

SessionControlProtocol.NAME = "realms-session-control"
SessionControlProtocol.VERSION = SessionTicket.PROTOCOL_VERSION
SessionControlProtocol.MAX_MESSAGE_SIZE = 96 * 1024

local MESSAGE_TYPES = table.set({
	"hello",
	"ready",
	"binary_error",
})

local function validate_message(message)
	if type(message) ~= "table"
		or message.protocol ~= SessionControlProtocol.NAME
		or message.version ~= SessionControlProtocol.VERSION
		or not MESSAGE_TYPES[message.type]
		or type(message.data) ~= "table"
	then
		return false, "Invalid session-control protocol message"
	end
	local data = message.data

	if message.type == "binary_error" then
		if table.size(data) ~= 4
			or type(data.message_type) ~= "number" or data.message_type % 1 ~= 0 or data.message_type < 1 or data.message_type > 65535
			or type(data.message_id) ~= "number" or data.message_id % 1 ~= 0 or data.message_id < 1 or data.message_id > 4294967295
			or type(data.reason) ~= "string" or #data.reason == 0 or #data.reason > 64
			or type(data.details) ~= "string" or #data.details > 256
		then
			return false, "Invalid binary routing error"
		end
	elseif table.size(data) ~= 0 then
		return false, "Session-control handshake data must be empty"
	end

	return true
end

function SessionControlProtocol.encode(message_type, data)
	local message = {
		data = data or {},
		protocol = SessionControlProtocol.NAME,
		type = message_type,
		version = SessionControlProtocol.VERSION,
	}
	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	local encoded, payload = pcall(ScriptCJson.encode_lua_to_json_for_lua, message)

	if not encoded then
		return nil, "Session-control protocol message is not JSON serializable: " .. tostring(payload)
	end

	return payload
end

function SessionControlProtocol.decode(payload)
	if type(payload) ~= "string" or #payload == 0 or #payload > SessionControlProtocol.MAX_MESSAGE_SIZE then
		return nil, "Invalid session-control protocol message size"
	end

	local decoded, message = pcall(cjson.decode, payload)

	if not decoded then
		return nil, "Session-control protocol payload is not valid JSON"
	end

	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	return message
end

return SessionControlProtocol
