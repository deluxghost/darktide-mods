local mod = get_mod("Realms")
local NetworkEventDelegate = require("scripts/managers/multiplayer/network_event_delegate")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local SessionControlProtocol = mod:io_dofile("Realms/scripts/mods/Realms/protocol/session_control_protocol")

local SessionControl = {
	__class_name = "RealmsSessionControl",
}
local protocols = {}
local host_handlers = {}
local client_handlers = {}
local connected_handlers = {}
local ready_handlers = {}
local disconnect_handlers = {}
local registered_channels = {}
local member_peers = {}
local Session
local BinaryNetwork

local CLIENT_TO_HOST_RPC = "rpc_check_mechanism"
local HOST_TO_CLIENT_RPC = "rpc_check_mechanism_reply"
local HELLO_RETRY_INTERVAL = 1
local RECONCILE_INTERVAL = 1
local next_reconcile_at = 0

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function active_host_connection()
	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_host

	return Session.is_active_host() and connection or nil
end

local function active_client_connection()
	local connection_manager = Managers.connection
	local connection = connection_manager and connection_manager._connection_client

	return Session.is_active_client() and connection or nil
end

local function control_delegate()
	local connection_manager = Managers.connection

	return connection_manager and connection_manager:network_event_delegate() or nil
end

local function notify(handlers, ...)
	for _, handler in pairs(handlers) do
		local accepted, handler_error = handler(...)

		if accepted == false then
			return false, handler_error
		end
	end

	return true
end

local function fail_channel(channel_id, reason)
	mod:info("Rejected session-control channel=%s: %s", tostring(channel_id), reason)

	local host_connection = active_host_connection()

	if host_connection and host_connection:is_realms_channel(channel_id) then
		host_connection:kick(channel_id, DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	local client_connection = active_client_connection()

	if client_connection and client_connection:host_channel() == channel_id then
		mod:error(mod:localize("preparation_control_failed"))
		Managers.multiplayer_session:leave("realms_invalid_session_control")
	end
end

local function unregister_channel(channel_id, notify_handlers)
	local registration = registered_channels[channel_id]

	if not registration then
		return
	end

	local detached, detach_error = BinaryNetwork.detach(channel_id)

	if not detached then
		error("Failed detaching session-control transport: " .. detach_error)
	end

	local delegate = registration.delegate
	local objects = delegate._registered_channel_objects[registration.rpc_name]

	if objects and objects[channel_id] == SessionControl then
		delegate:unregister_channel_events(channel_id, registration.rpc_name)
	end

	registered_channels[channel_id] = nil

	if notify_handlers then
		notify(disconnect_handlers, registration.peer_id, channel_id, registration.role)
	end
end

local function unregister_delegate_channels(delegate)
	local channel_ids = table.keys(registered_channels)

	for i = 1, #channel_ids do
		local channel_id = channel_ids[i]
		local registration = registered_channels[channel_id]

		if registration.delegate == delegate then
			unregister_channel(channel_id, true)
		end
	end
end

local function unregister_all_channels()
	if not next(registered_channels) then
		return
	end

	local channel_ids = table.keys(registered_channels)

	for i = 1, #channel_ids do
		unregister_channel(channel_ids[i], true)
	end
end

local function register_channel(channel_id, peer_id, role)
	if type(channel_id) ~= "number" then
		return nil, "Session-control channel is unavailable"
	end

	peer_id = normalize_peer_id(peer_id)

	local registration = registered_channels[channel_id]

	if registration and registration.peer_id == peer_id and registration.role == role then
		return registration
	end
	if registration then
		unregister_channel(channel_id, true)
	end

	local delegate = control_delegate()

	if not delegate then
		return nil, "Network event delegate is unavailable"
	end

	local rpc_name = role == "host" and CLIENT_TO_HOST_RPC or HOST_TO_CLIENT_RPC
	local objects = delegate._registered_channel_objects[rpc_name]
	local existing = objects and objects[channel_id]

	if existing then
		return nil, string.format("RPC %s is still owned by %s", rpc_name, tostring(existing.__class_name))
	end

	local attached, attach_error = BinaryNetwork.attach(channel_id, peer_id, role)

	if not attached then
		return nil, attach_error
	end

	delegate:register_connection_channel_events(SessionControl, channel_id, rpc_name)

	registration = {
		delegate = delegate,
		hello_sent_at = nil,
		peer_id = peer_id,
		ready = false,
		role = role,
		rpc_name = rpc_name,
	}
	registered_channels[channel_id] = registration

	local accepted, handler_error = notify(connected_handlers, channel_id, registration.peer_id, role)

	if accepted == false then
		unregister_channel(channel_id, false)

		return nil, handler_error or "Session-control connection was rejected"
	end

	return registration
end

local function encode_message(protocol_name, message_type, data)
	local protocol = protocols[protocol_name]

	if not protocol then
		return nil, "Session-control protocol is not registered"
	end

	return protocol.encode(message_type, data)
end

local function send_message(channel_id, role, protocol_name, message_type, data, require_ready)
	local registration = registered_channels[channel_id]

	if not registration or registration.role ~= role or require_ready and not registration.ready then
		return false, "Session-control channel is unavailable"
	end

	local payload, encode_error = encode_message(protocol_name, message_type, data)

	if not payload then
		return false, encode_error
	end

	return BinaryNetwork.send_control(channel_id, registration.peer_id, payload, role)
end

local function mark_ready(channel_id, registration)
	if registration.ready then
		return true
	end

	registration.ready = true

	return notify(ready_handlers, channel_id, registration.peer_id, registration.role)
end

local function receive_builtin(channel_id, registration, message)
	if registration.role == "host" and message.type == "hello" then
		local sent, send_error = send_message(channel_id, "host", SessionControlProtocol.NAME, "ready", {}, false)

		if not sent then
			return false, send_error
		end

		return mark_ready(channel_id, registration)
	end
	if registration.role == "client" and message.type == "ready" then
		return mark_ready(channel_id, registration)
	end
	if registration.role == "client" and registration.ready and message.type == "binary_error" then
		BinaryNetwork.receive_error(message.data)

		return true
	end

	return false, "Session-control handshake message is invalid for this endpoint"
end

local function receive_message(channel_id, payload)
	local registration = registered_channels[channel_id]
	local decoded, envelope = pcall(cjson.decode, payload)

	if not decoded or type(envelope) ~= "table" or type(envelope.protocol) ~= "string" then
		fail_channel(channel_id, "Session-control payload is not a valid protocol envelope")

		return
	end

	local protocol = protocols[envelope.protocol]

	if not protocol then
		fail_channel(channel_id, "Session-control protocol is not registered")

		return
	end

	local message, decode_error = protocol.decode(payload)

	if not message then
		fail_channel(channel_id, decode_error)

		return
	end

	local accepted, handler_error

	if protocol == SessionControlProtocol then
		accepted, handler_error = receive_builtin(channel_id, registration, message)
	elseif not registration.ready then
		accepted, handler_error = false, "Session-control application message arrived before the handshake completed"
	else
		local handlers = registration.role == "host" and host_handlers or client_handlers
		local protocol_handlers = handlers[protocol.NAME]
		local handler = protocol_handlers and protocol_handlers[message.type]

		if not handler then
			accepted, handler_error = false, "Session-control message has no registered handler"
		else
			accepted, handler_error = handler(channel_id, registration.peer_id, message.data)
		end
	end

	if accepted == false then
		fail_channel(channel_id, handler_error or "Session-control message was rejected")
	end
end

local function client_connected_to_host(connection)
	local connection_manager = Managers.connection

	if not connection_manager then
		return false
	end

	table.clear(member_peers)
	connection_manager:member_peers(member_peers)

	return table.contains(member_peers, connection:host())
end

local function reconcile_host(connection)
	local connected_peers = connection:connected_peers()

	for channel_id, peer_id in pairs(connected_peers) do
		if not registered_channels[channel_id] then
			SessionControl.remote_connected(channel_id, peer_id)
		end
	end

	local channel_ids = table.keys(registered_channels)

	for i = 1, #channel_ids do
		local channel_id = channel_ids[i]
		local registration = registered_channels[channel_id]

		if registration.role == "host" and not connected_peers[channel_id] then
			SessionControl.remote_disconnected(channel_id, registration.peer_id)
		end
	end
end

function SessionControl.install(session, binary_network)
	Session = session
	BinaryNetwork = binary_network
	SessionControl.register_protocol(SessionControlProtocol)

	mod:hook(NetworkEventDelegate, "destroy", function (func, self, ...)
		unregister_delegate_channels(self)

		return func(self, ...)
	end)
end

function SessionControl.register_protocol(protocol)
	if type(protocol) ~= "table"
		or type(protocol.NAME) ~= "string"
		or type(protocol.encode) ~= "function"
		or type(protocol.decode) ~= "function"
	then
		error("Session-control protocol is invalid")
	end
	if protocols[protocol.NAME] then
		error("Session-control protocol already registered: " .. protocol.NAME)
	end

	protocols[protocol.NAME] = protocol
	host_handlers[protocol.NAME] = {}
	client_handlers[protocol.NAME] = {}
end

function SessionControl.register_host_handler(protocol_name, message_type, handler)
	local handlers = host_handlers[protocol_name]

	if not handlers then
		error("Session-control protocol is not registered: " .. protocol_name)
	end
	if handlers[message_type] then
		error("Session-control host handler already registered for " .. protocol_name .. "." .. message_type)
	end

	handlers[message_type] = handler
end

function SessionControl.register_client_handler(protocol_name, message_type, handler)
	local handlers = client_handlers[protocol_name]

	if not handlers then
		error("Session-control protocol is not registered: " .. protocol_name)
	end
	if handlers[message_type] then
		error("Session-control client handler already registered for " .. protocol_name .. "." .. message_type)
	end

	handlers[message_type] = handler
end

local function register_named_handler(handlers, kind, name, handler)
	if handlers[name] then
		error("Session-control " .. kind .. " handler already registered for " .. name)
	end

	handlers[name] = handler
end

function SessionControl.register_connected_handler(name, handler)
	register_named_handler(connected_handlers, "connected", name, handler)
end

function SessionControl.register_ready_handler(name, handler)
	register_named_handler(ready_handlers, "ready", name, handler)
end

function SessionControl.register_disconnect_handler(name, handler)
	register_named_handler(disconnect_handlers, "disconnect", name, handler)
end

function SessionControl.remote_connected(channel_id, peer_id)
	if not Session.is_active_host() then
		return
	end

	local registration, register_error = register_channel(channel_id, peer_id, "host")

	if not registration then
		fail_channel(channel_id, register_error)
	end
end

function SessionControl.remote_disconnected(channel_id, peer_id)
	local registration = registered_channels[channel_id]

	if registration then
		unregister_channel(channel_id, true)
	elseif peer_id then
		notify(disconnect_handlers, normalize_peer_id(peer_id), channel_id, "host")
	end
end

function SessionControl.send_to_host(protocol_name, message_type, data)
	if not Session.is_active_client() then
		return false, "Session-control client session is unavailable"
	end

	local connection = active_client_connection()
	local channel_id = connection and connection:host_channel()

	return send_message(channel_id, "client", protocol_name, message_type, data, true)
end

function SessionControl.send_to_client(channel_id, protocol_name, message_type, data)
	if not Session.is_active_host() then
		return false, "Session-control host session is unavailable"
	end

	return send_message(channel_id, "host", protocol_name, message_type, data, true)
end

function SessionControl.send_to_peer(peer_id, protocol_name, message_type, data)
	if not Session.is_active_host() then
		return false, "Session-control host session is unavailable"
	end

	peer_id = normalize_peer_id(peer_id)

	for channel_id, registration in pairs(registered_channels) do
		if registration.role == "host" and registration.ready and registration.peer_id == peer_id then
			return SessionControl.send_to_client(channel_id, protocol_name, message_type, data)
		end
	end

	return false, "Session-control peer is unavailable"
end

function SessionControl.send_to_clients(protocol_name, message_type, data, excluded_peer_id)
	if not Session.is_active_host() then
		return false, "Session-control host session is unavailable"
	end

	excluded_peer_id = excluded_peer_id and normalize_peer_id(excluded_peer_id) or nil

	for channel_id, registration in pairs(registered_channels) do
		if registration.role == "host" and registration.ready and registration.peer_id ~= excluded_peer_id then
			local sent, send_error = SessionControl.send_to_client(channel_id, protocol_name, message_type, data)

			if not sent then
				return false, send_error
			end
		end
	end

	return true
end

function SessionControl.is_peer_available(peer_id)
	peer_id = normalize_peer_id(peer_id)

	for _, registration in pairs(registered_channels) do
		if registration.ready and registration.peer_id == peer_id then
			return true
		end
	end

	return false
end

function SessionControl.ready_peer_ids()
	local peer_ids = {}

	for _, registration in pairs(registered_channels) do
		if registration.role == "host" and registration.ready then
			peer_ids[#peer_ids + 1] = registration.peer_id
		end
	end

	return peer_ids
end

function SessionControl.is_available()
	if Session.is_active_host() then
		return true
	end
	if not Session.is_active_client() then
		return false
	end

	local connection = active_client_connection()
	local channel_id = connection and connection:host_channel()
	local registration = channel_id and registered_channels[channel_id]

	return registration and registration.role == "client" and registration.ready or false
end

function SessionControl.receive_control(message)
	local registration = registered_channels[message.channel_id]

	if not registration or message.sender ~= registration.peer_id
		or message.recipient ~= normalize_peer_id(Network.peer_id())
		or not message.reliable or #message.payload > SessionControlProtocol.MAX_MESSAGE_SIZE
	then
		fail_channel(message.channel_id, "Session-control message identity or size is invalid")

		return
	end

	receive_message(message.channel_id, message.payload)
end

local function receive_control_wakeup(channel_id, role, token, complete)
	local registration = registered_channels[channel_id]
	local message_id = tonumber(token)

	if not registration or registration.role ~= role or complete ~= true
		or not message_id or message_id % 1 ~= 0 or message_id < 1 or message_id > 4294967295
	then
		fail_channel(channel_id, "Binary control wakeup is invalid")

		return
	end

	BinaryNetwork.receive_control(channel_id, message_id)
end

function SessionControl.rpc_check_mechanism(self, channel_id, token, complete)
	receive_control_wakeup(channel_id, "host", token, complete)
end

function SessionControl.rpc_check_mechanism_reply(self, channel_id, complete, token)
	receive_control_wakeup(channel_id, "client", token, complete)
end

function SessionControl.send_binary_error(channel_id, message_type, message_id, reason, details)
	return send_message(channel_id, "host", SessionControlProtocol.NAME, "binary_error", {
		message_type = message_type,
		message_id = message_id,
		reason = reason,
		details = details,
	}, true)
end

function SessionControl.channel_for_peer(peer_id)
	for channel_id, registration in pairs(registered_channels) do
		if registration.ready and registration.peer_id == peer_id then
			return channel_id
		end
	end
end

function SessionControl.peer_for_channel(channel_id)
	local registration = registered_channels[channel_id]

	return registration and registration.ready and registration.peer_id or nil
end

function SessionControl.has_channels()
	return next(registered_channels) ~= nil
end

function SessionControl.reject_channel(channel_id, reason)
	fail_channel(channel_id, reason)
end

function SessionControl.shutdown()
	unregister_all_channels()
end

function SessionControl.update()
	local t = Managers.time:time("main")

	local host_connection = active_host_connection()

	if host_connection then
		if t >= next_reconcile_at then
			next_reconcile_at = t + RECONCILE_INTERVAL
			reconcile_host(host_connection)
		end

		return
	end

	local client_connection = active_client_connection()

	if client_connection and client_connected_to_host(client_connection) then
		local channel_id = client_connection:host_channel()
		local registration = registered_channels[channel_id]

		if not registration then
			local register_error

			registration, register_error = register_channel(channel_id, client_connection:host(), "client")

			if not registration then
				fail_channel(channel_id, register_error)

				return
			end
		end

		if not registration.ready and (not registration.hello_sent_at or t - registration.hello_sent_at >= HELLO_RETRY_INTERVAL) then
			local sent, send_error = send_message(channel_id, "client", SessionControlProtocol.NAME, "hello", {}, false)

			if not sent then
				fail_channel(channel_id, send_error)

				return
			end

			registration.hello_sent_at = t
		end

		return
	end

	unregister_all_channels()
end

return SessionControl
