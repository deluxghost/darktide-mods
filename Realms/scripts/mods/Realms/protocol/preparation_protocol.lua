local mod = get_mod("Realms")
local ScriptCJson = require("scripts/foundation/utilities/script_cjson")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local PreparationProtocol = {}

PreparationProtocol.NAME = "realms-preparation"
PreparationProtocol.VERSION = SessionTicket.PROTOCOL_VERSION
PreparationProtocol.MAX_PAYLOAD_SIZE = 4096

local MESSAGE_TYPES = table.set({
	"hello",
	"ready",
	"snapshot",
})

local function valid_ready_peer_ids(peer_ids)
	if type(peer_ids) ~= "table" or #peer_ids > 8 then
		return false
	end

	local seen = {}

	for i = 1, #peer_ids do
		local peer_id = peer_ids[i]

		if type(peer_id) ~= "string" or #peer_id ~= 16 or not string.match(peer_id, "^[0-9a-f]+$") or seen[peer_id] then
			return false
		end

		seen[peer_id] = true
	end

	return true
end

local function validate_message(message)
	if type(message) ~= "table"
		or message.protocol ~= PreparationProtocol.NAME
		or message.version ~= PreparationProtocol.VERSION
		or not MESSAGE_TYPES[message.type]
		or type(message.data) ~= "table"
	then
		return false, "Invalid preparation protocol envelope"
	end

	local data = message.data

	if message.type == "hello" then
		if table.size(data) == 0 then
			return true
		end
	elseif message.type == "ready" then
		if table.size(data) == 1 and type(data.ready) == "boolean" then
			return true
		end
	else
		if table.size(data) == 5
			and type(data.countdown_remaining_ms) == "number"
			and data.countdown_remaining_ms % 1 == 0
			and data.countdown_remaining_ms >= 0
			and data.countdown_remaining_ms <= 5000
			and type(data.revision) == "number"
			and data.revision % 1 == 0
			and data.revision >= 0
			and data.revision <= 2147483647
			and type(data.max_members) == "number"
			and data.max_members % 1 == 0
			and data.max_members >= 2
			and data.max_members <= 8
			and type(data.started) == "boolean"
			and valid_ready_peer_ids(data.ready_peer_ids)
		then
			return true
		end
	end

	return false, "Invalid preparation message data"
end

function PreparationProtocol.encode(message_type, data)
	local message = {
		data = data or {},
		protocol = PreparationProtocol.NAME,
		type = message_type,
		version = PreparationProtocol.VERSION,
	}
	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	local payload = ScriptCJson.encode_lua_to_json_for_lua(message)

	if #payload > PreparationProtocol.MAX_PAYLOAD_SIZE then
		return nil, "Preparation protocol payload exceeds the size limit"
	end

	return payload
end

function PreparationProtocol.decode(payload)
	if type(payload) ~= "string" or #payload == 0 or #payload > PreparationProtocol.MAX_PAYLOAD_SIZE then
		return nil, "Invalid preparation protocol payload size"
	end

	local decoded, message = pcall(cjson.decode, payload)

	if not decoded then
		return nil, "Preparation protocol payload is not valid JSON"
	end

	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	return message
end

return PreparationProtocol
