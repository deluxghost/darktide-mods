local mod = get_mod("Realms")
local ScriptCJson = require("scripts/foundation/utilities/script_cjson")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local ChatProtocol = {}

ChatProtocol.NAME = "realms-chat"
ChatProtocol.VERSION = SessionTicket.PROTOCOL_VERSION
ChatProtocol.MAX_MESSAGE_SIZE = 96 * 1024
ChatProtocol.MAX_TEXT_CHARACTERS = 200

local MAX_NAME_BYTES = 256
local REJECTION_REASONS = table.set({
	"sender_unavailable",
})

local function valid_text(value)
	if type(value) ~= "string" or value == "" or #value > 1024 then
		return false
	end

	local measured, length = pcall(Utf8.string_length, value)

	return measured and length > 0 and length <= ChatProtocol.MAX_TEXT_CHARACTERS
end

local MESSAGE_VALIDATORS = {
	chat_submit = function (data)
		return table.size(data) == 2
			and type(data.local_player_id) == "number"
			and data.local_player_id % 1 == 0
			and data.local_player_id >= 1
			and data.local_player_id <= 8
			and valid_text(data.text)
	end,
	chat_deliver = function (data)
		return table.size(data) == 2
			and type(data.sender_name) == "string"
			and #data.sender_name > 0
			and #data.sender_name <= MAX_NAME_BYTES
			and valid_text(data.text)
	end,
	chat_rejected = function (data)
		return table.size(data) == 1 and REJECTION_REASONS[data.reason] == true
	end,
}

local function validate_message(message)
	if type(message) ~= "table"
		or message.protocol ~= ChatProtocol.NAME
		or message.version ~= ChatProtocol.VERSION
		or type(message.type) ~= "string"
		or type(message.data) ~= "table"
	then
		return false, "Invalid chat protocol envelope"
	end

	local validator = MESSAGE_VALIDATORS[message.type]

	if not validator or not validator(message.data) then
		return false, "Invalid chat message"
	end

	return true
end

function ChatProtocol.encode(message_type, data)
	local message = {
		data = data or {},
		protocol = ChatProtocol.NAME,
		type = message_type,
		version = ChatProtocol.VERSION,
	}
	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	local encoded, payload = pcall(ScriptCJson.encode_lua_to_json_for_lua, message)

	if not encoded then
		return nil, "Chat protocol message is not JSON serializable: " .. tostring(payload)
	end

	return payload
end

function ChatProtocol.decode(payload)
	if type(payload) ~= "string" or #payload == 0 or #payload > ChatProtocol.MAX_MESSAGE_SIZE then
		return nil, "Invalid chat protocol message size"
	end

	local decoded, message = pcall(cjson.decode, payload)

	if not decoded then
		return nil, "Chat protocol payload is not valid JSON"
	end

	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	return message
end

return ChatProtocol
