local mod = get_mod("Realms")
local Transport = mod:io_dofile("Realms/scripts/mods/Realms/runtime/binary")
local BinaryNetwork = {}
local handlers = {}
local Session
local SessionControl
local error_handler
local HOST_RECIPIENT = "0000000000000000"
local OTHERS_RECIPIENT = "ffffffffffffffff"
local DEFAULT_LIFETIME_MS = 250
local MAX_RECEIVE_MESSAGES = 64
local MAX_RECEIVE_BYTES = 512 * 1024

local function local_peer_id()
	return string.lower(tostring(Network.peer_id()))
end

local function dispatch(message)
	local handler = handlers[message.message_type]

	if not handler then
		return false, "Binary message type is not registered", "message_type_unregistered"
	end

	local accepted, handler_error = handler(message.sender, message.payload, message.reliable, message.message_id)

	return accepted ~= false, handler_error, accepted == false and "message_rejected" or nil
end

local function send_to_peer(peer_id, message)
	local channel_id = SessionControl.channel_for_peer(peer_id)

	if not channel_id then
		return false, "Binary target peer is unavailable: " .. peer_id, "target_peer_unavailable"
	end

	local sent, result = Transport.send(channel_id, message.sender, message.recipient, message.message_type,
		message.payload, message.reliable, message.lifetime_ms)

	return sent, result, not sent and "send_failed" or nil
end

local function broadcast(message)
	local peers = SessionControl.ready_peer_ids()
	local first_error, first_reason

	for i = 1, #peers do
		if peers[i] ~= message.sender then
			local sent, send_error, reason = send_to_peer(peers[i], message)

			if not sent and not first_error then
				first_error, first_reason = send_error, reason
			end
		end
	end

	return first_error == nil, first_error, first_reason
end

local function route_host(message)
	local recipient = message.recipient

	if recipient == HOST_RECIPIENT or recipient == local_peer_id() then
		return dispatch(message)
	end
	if recipient == OTHERS_RECIPIENT then
		local accepted, handler_error, reason = dispatch(message)

		if not accepted then
			return false, handler_error, reason
		end

		return broadcast(message)
	end

	return send_to_peer(recipient, message)
end

local function receive(message)
	local transport_peer = SessionControl.peer_for_channel(message.channel_id)

	if not transport_peer then
		SessionControl.reject_channel(message.channel_id, "Binary message arrived before session-control readiness")

		return
	end

	local accepted, receive_error, reason

	if Session.is_active_host() then
		if transport_peer ~= message.sender then
			SessionControl.reject_channel(message.channel_id, "Binary sender does not match its connection")

			return
		end

		message.lifetime_ms = message.reliable and 0 or DEFAULT_LIFETIME_MS
		accepted, receive_error, reason = route_host(message)
	elseif Session.is_active_client() and (message.recipient == OTHERS_RECIPIENT or message.recipient == local_peer_id()) then
		accepted, receive_error, reason = dispatch(message)
	else
		SessionControl.reject_channel(message.channel_id, "Binary recipient does not match this endpoint")

		return
	end

	if not accepted then
		local details = receive_error or "Handler rejected the message"

		if Session.is_active_host() then
			local sent, send_error = SessionControl.send_binary_error(message.channel_id, message.message_type,
				message.message_id, reason, details)

			if not sent then
				mod:error("Failed returning binary routing error to %s: %s", message.sender, send_error)
			end
		else
			BinaryNetwork.receive_error({ message_type = message.message_type, message_id = message.message_id,
				reason = reason, details = details })
		end
	end
end

function BinaryNetwork.install(session, session_control)
	Session = session
	SessionControl = session_control
end

function BinaryNetwork.register(message_type, callback)
	if type(message_type) ~= "number" or message_type % 1 ~= 0 or message_type < 1 or message_type > 65535
		or type(callback) ~= "function" or handlers[message_type]
	then
		error("Binary message registration is invalid or duplicated")
	end

	handlers[message_type] = callback
end

function BinaryNetwork.set_error_handler(callback)
	if type(callback) ~= "function" then
		error("Binary error handler must be a function")
	end

	error_handler = callback
end

function BinaryNetwork.receive_error(data)
	if error_handler then
		error_handler(data.message_type, data.message_id, data.reason, data.details)
	else
		mod:error("Binary message %d/%d failed (%s): %s", data.message_type, data.message_id, data.reason, data.details)
	end
end

function BinaryNetwork.send(message_type, recipient, payload, reliable, lifetime_ms)
	reliable = reliable == nil and true or reliable
	lifetime_ms = lifetime_ms == nil and (reliable and 0 or DEFAULT_LIFETIME_MS) or lifetime_ms

	if type(message_type) ~= "number" or message_type % 1 ~= 0 or message_type < 1 or message_type > 65535
		or type(recipient) ~= "string" or type(payload) ~= "string" or type(reliable) ~= "boolean"
		or type(lifetime_ms) ~= "number" or lifetime_ms % 1 ~= 0 or lifetime_ms < 0 or lifetime_ms > 4294967295
		or reliable and lifetime_ms ~= 0 or not reliable and lifetime_ms == 0
	then
		return false, "Binary send arguments are invalid"
	end
	if not SessionControl.is_available() then
		return false, "Binary network session is unavailable"
	end

	local sender = local_peer_id()
	local message = {
		message_type = message_type,
		sender = sender,
		recipient = recipient,
		payload = payload,
		reliable = reliable,
		lifetime_ms = lifetime_ms,
	}

	if recipient == "local" or string.lower(recipient) == sender then
		return dispatch(message)
	end
	if recipient == "all" then
		local accepted, handler_error = dispatch(message)

		if not accepted then
			return false, handler_error
		end

		recipient = "others"
	end

	message.recipient = recipient == "host" and HOST_RECIPIENT or recipient == "others" and OTHERS_RECIPIENT
		or string.lower(recipient)

	if message.recipient ~= HOST_RECIPIENT and message.recipient ~= OTHERS_RECIPIENT
		and (#message.recipient ~= 16 or not string.match(message.recipient, "^%x+$"))
	then
		return false, "Binary recipient is invalid"
	end
	if Session.is_active_host() then
		if message.recipient == OTHERS_RECIPIENT then
			return broadcast(message)
		end

		return route_host(message)
	end

	local host = string.lower(tostring(Managers.connection:host()))

	return send_to_peer(host, message)
end

function BinaryNetwork.send_control(channel_id, peer_id, payload, role)
	local sent, result = Transport.send(channel_id, local_peer_id(), peer_id, 0, payload, true, 0)

	if not sent then
		return false, result
	end

	-- The ordered RPC carries only an ID; its payload is already in the binary receive queue.
	if role == "host" then
		RPC.rpc_check_mechanism_reply(channel_id, true, tostring(result))
	else
		RPC.rpc_check_mechanism(channel_id, tostring(result), true)
	end

	return true
end

function BinaryNetwork.receive_control(channel_id, message_id)
	local message, receive_error = Transport.poll(channel_id, message_id)

	if not message then
		SessionControl.reject_channel(channel_id, receive_error or "Binary control wakeup arrived without its payload")

		return
	end

	SessionControl.receive_control(message)
end

function BinaryNetwork.update()
	if not SessionControl.has_channels() then
		return
	end

	local updated, update_error, channel_id = Transport.update()

	if not updated then
		SessionControl.reject_channel(channel_id, update_error)

		return
	end

	local bytes = 0

	for _ = 1, MAX_RECEIVE_MESSAGES do
		local message, receive_error = Transport.poll()

		if message == nil then
			error("Binary transport polling failed: " .. receive_error)
		end
		if not message then
			break
		end

		receive(message)
		bytes = bytes + #message.payload

		if bytes >= MAX_RECEIVE_BYTES then
			break
		end
	end
end

BinaryNetwork.attach = Transport.attach
BinaryNetwork.detach = Transport.detach
BinaryNetwork.stats = Transport.stats

return BinaryNetwork
