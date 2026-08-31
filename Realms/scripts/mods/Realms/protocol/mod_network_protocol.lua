local mod = get_mod("Realms")
local ScriptCJson = require("scripts/foundation/utilities/script_cjson")
local SessionTicket = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_ticket")

local ModNetworkProtocol = {}

ModNetworkProtocol.NAME = "realms-mod-network"
ModNetworkProtocol.VERSION = SessionTicket.PROTOCOL_VERSION
ModNetworkProtocol.MAX_MESSAGE_SIZE = 96 * 1024

local MAX_ARGUMENTS = 32
local MAX_MOD_NAME_LENGTH = 64
local MAX_RPC_NAME_LENGTH = 64
local MAX_RECIPIENT_LENGTH = 128
local ROUTE_ERRORS = table.set({
	"message_rejected",
	"target_peer_unavailable",
	"target_rpc_unsupported",
})

local function valid_string(value, max_length)
	return type(value) == "string" and #value > 0 and #value <= max_length
end

local function valid_arguments(arguments)
	if type(arguments) ~= "table" or table.size(arguments) ~= 2 then
		return false
	end

	local count = arguments.count
	local values = arguments.values

	if type(count) ~= "number" or count % 1 ~= 0 or count < 0 or count > MAX_ARGUMENTS or type(values) ~= "table" then
		return false
	end

	local value_count = 0
	local max_index = 0

	for index in pairs(values) do
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > count then
			return false
		end

		value_count = value_count + 1
		max_index = math.max(max_index, index)
	end

	return value_count == count and max_index == count
end

local function valid_manifest(manifest)
	if type(manifest) ~= "table" then
		return false
	end

	for mod_name, rpc_names in pairs(manifest) do
		if not valid_string(mod_name, MAX_MOD_NAME_LENGTH) or type(rpc_names) ~= "table" then
			return false
		end

		local count = 0
		local max_index = 0

		for index, rpc_name in pairs(rpc_names) do
			if type(index) ~= "number"
				or index % 1 ~= 0
				or index < 1
				or not valid_string(rpc_name, MAX_RPC_NAME_LENGTH)
			then
				return false
			end

			count = count + 1
			max_index = math.max(max_index, index)
		end

		if count ~= max_index then
			return false
		end
	end

	return true
end

local MESSAGE_VALIDATORS = {
	mod_network_delivery = function (data)
		return table.size(data) == 4
			and valid_arguments(data.arguments)
			and valid_string(data.mod_name, MAX_MOD_NAME_LENGTH)
			and valid_string(data.rpc_name, MAX_RPC_NAME_LENGTH)
			and valid_string(data.sender_peer_id, MAX_RECIPIENT_LENGTH)
	end,
	mod_network_error = function (data)
		return table.size(data) == 3
			and valid_string(data.mod_name, MAX_MOD_NAME_LENGTH)
			and valid_string(data.rpc_name, MAX_RPC_NAME_LENGTH)
			and ROUTE_ERRORS[data.reason] == true
	end,
	mod_network_manifest = function (data)
		return table.size(data) == 1 and valid_manifest(data.rpcs)
	end,
	mod_network_request = function (data)
		return table.size(data) == 4
			and valid_arguments(data.arguments)
			and valid_string(data.mod_name, MAX_MOD_NAME_LENGTH)
			and valid_string(data.rpc_name, MAX_RPC_NAME_LENGTH)
			and valid_string(data.recipient, MAX_RECIPIENT_LENGTH)
	end,
}

local function validate_message(message)
	if type(message) ~= "table"
		or message.protocol ~= ModNetworkProtocol.NAME
		or message.version ~= ModNetworkProtocol.VERSION
		or type(message.type) ~= "string"
		or type(message.data) ~= "table"
	then
		return false, "Invalid mod-network protocol envelope"
	end

	local validator = MESSAGE_VALIDATORS[message.type]

	if not validator or not validator(message.data) then
		return false, "Invalid mod-network message"
	end

	return true
end

function ModNetworkProtocol.encode(message_type, data)
	local message = {
		data = data or {},
		protocol = ModNetworkProtocol.NAME,
		type = message_type,
		version = ModNetworkProtocol.VERSION,
	}
	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	local encoded, payload = pcall(ScriptCJson.encode_lua_to_json_for_lua, message)

	if not encoded then
		return nil, "Mod-network protocol message is not JSON serializable: " .. tostring(payload)
	end
	if #payload > ModNetworkProtocol.MAX_MESSAGE_SIZE then
		return nil, "Mod-network protocol message exceeds the size limit"
	end

	return payload
end

function ModNetworkProtocol.decode(payload)
	if type(payload) ~= "string" or #payload == 0 or #payload > ModNetworkProtocol.MAX_MESSAGE_SIZE then
		return nil, "Invalid mod-network protocol message size"
	end

	local decoded, message = pcall(cjson.decode, payload)

	if not decoded then
		return nil, "Mod-network protocol payload is not valid JSON"
	end

	local valid, validation_error = validate_message(message)

	if not valid then
		return nil, validation_error
	end

	return message
end

return ModNetworkProtocol
