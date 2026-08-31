local mod = get_mod("Realms")
local JwtTicketUtils = require("scripts/multiplayer/utilities/jwt_ticket_utils")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")

local SessionTicket = {}

local PROTOCOL_VERSION = 7
local MAX_TICKET_SIZE = 196608
local MAX_PASSWORD_SIZE = 1024
local HEADER_FIELDS = {
	alg = true,
	typ = true,
}
local PAYLOAD_FIELDS = {
	clientSnapshot = true,
	instanceId = true,
	sessionId = true,
	sessionSettings = true,
	hostPeerId = true,
	password = true,
	realmsProtocol = true,
}

local function has_only_fields(value, allowed_fields)
	for field in pairs(value) do
		if not allowed_fields[field] then
			return false
		end
	end

	return true
end

local function valid_peer_id(peer_id)
	return type(peer_id) == "string" and #peer_id == 16 and string.match(peer_id, "^[0-9a-f]+$") ~= nil
end
local function client_instance_id(host_peer_id)
	return "realms--local--listen--session--" .. host_peer_id .. "--v1"
end


function SessionTicket.validate_password(password)
	if type(password) ~= "string" then
		return false, "error_password_type"
	end
	if #password > MAX_PASSWORD_SIZE then
		return false, "error_password_too_long"
	end
	if string.find(password, "%s") then
		return false, "error_password_whitespace"
	end

	return true
end

function SessionTicket.create(host_peer_id, password, client_snapshot)
	local valid_password, password_error = SessionTicket.validate_password(password)

	if not valid_password then
		return nil, password_error
	end

	local header = {
		alg = "none",
		typ = "Realms",
	}
	local payload = {
		clientSnapshot = client_snapshot,
		instanceId = client_instance_id(host_peer_id),
		sessionId = host_peer_id,
		sessionSettings = {},
		hostPeerId = host_peer_id,
		realmsProtocol = PROTOCOL_VERSION,
	}

	if password ~= "" then
		payload.password = password
	end
	local ticket = string.encode_base64(cjson.encode(header)) .. "." .. string.encode_base64(cjson.encode(payload)) .. "."

	if #ticket > MAX_TICKET_SIZE then
		return nil, "Realms session ticket exceeds the protocol limit"
	end

	return ticket
end

function SessionTicket.decode(ticket)
	if type(ticket) ~= "string" or #ticket == 0 or #ticket > MAX_TICKET_SIZE then
		return nil, "Realms session ticket size is invalid", DisconnectReason.CLIENT_DATA_REJECTED
	end

	local decoded, header, payload = pcall(function ()
		local decoded_header, decoded_payload = JwtTicketUtils.decode_jwt_ticket(ticket)

		return decoded_header, decoded_payload
	end)

	if not decoded
		or type(header) ~= "table"
		or not has_only_fields(header, HEADER_FIELDS)
		or header.alg ~= "none"
		or header.typ ~= "Realms"
		or type(payload) ~= "table"
		or not has_only_fields(payload, PAYLOAD_FIELDS)
	then
		return nil, "Realms session ticket envelope is invalid", DisconnectReason.CLIENT_DATA_REJECTED
	end

	return payload
end

function SessionTicket.validate(payload, expected_host_peer_id, expected_password)
	if payload.realmsProtocol ~= PROTOCOL_VERSION then
		return nil, "Realms protocol version does not match the host", DisconnectReason.PROTOCOL_MISMATCH
	end
	if not valid_peer_id(payload.hostPeerId) or payload.hostPeerId ~= expected_host_peer_id then
		return nil, "Realms session ticket targets a different host", DisconnectReason.CLIENT_DATA_REJECTED
	end
	local password = payload.password or ""
	if payload.instanceId ~= client_instance_id(payload.hostPeerId)
		or payload.sessionId ~= payload.hostPeerId
		or type(payload.sessionSettings) ~= "table"
		or next(payload.sessionSettings) ~= nil
	then
		return nil, "Realms retained client ticket fields are invalid", DisconnectReason.CLIENT_DATA_REJECTED
	end

	local valid_password = SessionTicket.validate_password(password)

	if not valid_password or password ~= expected_password then
		return nil, "Realms server password is incorrect", DisconnectReason.PASSWORD_INCORRECT
	end
	if type(payload.clientSnapshot) ~= "table" then
		return nil, "Realms client snapshot is missing", DisconnectReason.CLIENT_DATA_REJECTED
	end

	return payload.clientSnapshot
end

SessionTicket.MAX_TICKET_SIZE = MAX_TICKET_SIZE
SessionTicket.PROTOCOL_VERSION = PROTOCOL_VERSION

return SessionTicket
