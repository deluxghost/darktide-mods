local mod = get_mod("Realms")
local ScriptCJson = require("scripts/foundation/utilities/script_cjson")
local Native = mod:io_dofile("Realms/scripts/mods/Realms/runtime/native")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local LatencyProtocol = {}

LatencyProtocol.NAME = "realms-latency"
LatencyProtocol.VERSION = SessionTicket.PROTOCOL_VERSION
LatencyProtocol.MAX_MESSAGE_SIZE = 4096

local function valid_peer_id(peer_id)
	return type(peer_id) == "string"
		and #peer_id == 16
		and string.match(peer_id, "^[0-9a-f]+$") ~= nil
end

local function validate_message(message)
	if type(message) ~= "table"
		or message.protocol ~= LatencyProtocol.NAME
		or message.version ~= LatencyProtocol.VERSION
		or message.type ~= "snapshot"
		or type(message.data) ~= "table"
		or table.size(message.data) ~= 1
	then
		return false, "Invalid latency protocol envelope"
	end

	local data = message.data

	if type(data.samples) ~= "table"
		or table.size(data.samples) > assert(Native.maximum_host_members())
	then
		return false, "Invalid latency snapshot"
	end

	for peer_id, latency_ms in pairs(data.samples) do
		if not valid_peer_id(peer_id)
			or type(latency_ms) ~= "number"
			or latency_ms % 1 ~= 0
			or latency_ms < 0
			or latency_ms > 2147483647
		then
			return false, "Invalid latency sample"
		end
	end

	return true
end

function LatencyProtocol.encode(message_type, data)
	local message = {
		data = data or {},
		protocol = LatencyProtocol.NAME,
		type = message_type,
		version = LatencyProtocol.VERSION,
	}
	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	local encoded, payload = pcall(ScriptCJson.encode_lua_to_json_for_lua, message)

	if not encoded then
		return nil, "Latency protocol message is not JSON serializable: " .. tostring(payload)
	end
	if #payload > LatencyProtocol.MAX_MESSAGE_SIZE then
		return nil, "Latency protocol message exceeds the size limit"
	end

	return payload
end

function LatencyProtocol.decode(payload)
	if type(payload) ~= "string" or #payload == 0 or #payload > LatencyProtocol.MAX_MESSAGE_SIZE then
		return nil, "Invalid latency protocol message size"
	end

	local decoded, message = pcall(cjson.decode, payload)

	if not decoded then
		return nil, "Latency protocol payload is not valid JSON"
	end

	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	return message
end

return LatencyProtocol
