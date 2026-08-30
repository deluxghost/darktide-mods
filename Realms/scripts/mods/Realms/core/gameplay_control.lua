local mod = get_mod("Realms")
local DisconnectReason = mod:io_dofile("Realms/scripts/mods/Realms/protocol/disconnect_reason")
local GameplayControlProtocol = mod:io_dofile("Realms/scripts/mods/Realms/protocol/gameplay_control_protocol")

local GameplayControl = {
	__class_name = "RealmsGameplayControl",
}
local host_handlers = {}
local client_handlers = {}
local disconnect_handlers = {}
local ready_handlers = {}
local registered_channels = {}
local Preparation
local Session

local CLIENT_TO_HOST_RPC = "rpc_check_mechanism"
local HOST_TO_CLIENT_RPC = "rpc_check_mechanism_reply"
local HELLO_RETRY_INTERVAL = 1
local REASSEMBLY_TIMEOUT = 10

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

local function game_session_active()
	return Managers.state and Managers.state.game_session ~= nil and not Preparation.is_waiting()
end

local function control_delegate()
	local connection_manager = Managers.connection

	return connection_manager and connection_manager:network_event_delegate() or nil
end

local function unregister_channel(channel_id)
	local registration = registered_channels[channel_id]

	if not registration then
		return
	end

	local delegate = control_delegate()
	local objects = delegate and delegate._registered_channel_objects[registration.rpc_name]

	if objects and objects[channel_id] == GameplayControl then
		delegate:unregister_channel_events(channel_id, registration.rpc_name)
	end

	registered_channels[channel_id] = nil
end

local function notify_disconnected(peer_id)
	peer_id = normalize_peer_id(peer_id)

	for _, handler in pairs(disconnect_handlers) do
		handler(peer_id)
	end
end

local function unregister_all_channels()
	local channel_ids = table.keys(registered_channels)

	for i = 1, #channel_ids do
		local channel_id = channel_ids[i]
		local registration = registered_channels[channel_id]

		unregister_channel(channel_id)
		notify_disconnected(registration.peer_id)
	end
end

local function fail_channel(channel_id, reason)
	mod:info("Rejected gameplay-control channel=%s: %s", tostring(channel_id), reason)

	local host_connection = active_host_connection()

	if host_connection and host_connection:is_realms_channel(channel_id) then
		host_connection:kick(channel_id, DisconnectReason.CLIENT_DATA_REJECTED)

		return
	end

	local client_connection = active_client_connection()

	if client_connection and client_connection:host_channel() == channel_id then
		mod:error(mod:localize("preparation_control_failed"))
		Managers.multiplayer_session:leave("realms_invalid_gameplay_control")
	end
end

local function register_channel(channel_id, peer_id, role)
	local rpc_name = role == "host" and CLIENT_TO_HOST_RPC or HOST_TO_CLIENT_RPC
	local registration = registered_channels[channel_id]

	if registration then
		return registration
	end

	local delegate = control_delegate()

	if not delegate then
		return nil, "Network event delegate is unavailable"
	end

	local objects = delegate._registered_channel_objects[rpc_name]
	local existing = objects and objects[channel_id]

	if existing and existing ~= GameplayControl then
		if existing.__class_name ~= GameplayControl.__class_name then
			return nil, string.format("RPC %s is still owned by %s", rpc_name, tostring(existing.__class_name))
		end

		delegate:unregister_channel_events(channel_id, rpc_name)
	end

	delegate:register_connection_channel_events(GameplayControl, channel_id, rpc_name)

	registration = {
		hello_sent_at = nil,
		peer_id = normalize_peer_id(peer_id),
		ready = false,
		receive_chunks = nil,
		receive_size = 0,
		receive_started_at = nil,
		role = role,
		rpc_name = rpc_name,
	}
	registered_channels[channel_id] = registration

	return registration
end

local function encode_message(message_type, data)
	local payload, encode_error = GameplayControlProtocol.encode(message_type, data)

	if not payload then
		return nil, encode_error
	end

	return payload
end

local function send_frames(payload, send_frame)
	for offset = 1, #payload, GameplayControlProtocol.MAX_FRAME_SIZE do
		local chunk = string.sub(payload, offset, offset + GameplayControlProtocol.MAX_FRAME_SIZE - 1)
		local is_last = offset + GameplayControlProtocol.MAX_FRAME_SIZE > #payload

		send_frame(chunk, is_last)
	end

	return true
end

local function notify_ready(channel_id, registration)
	for _, handler in pairs(ready_handlers) do
		local accepted, handler_error = handler(channel_id, registration.peer_id, registration.role)

		if accepted == false then
			return false, handler_error
		end
	end

	return true
end

function GameplayControl.install(session, preparation)
	Session = session
	Preparation = preparation

	GameplayControl.register_host_handler("hello", function (channel_id)
		local registration = registered_channels[channel_id]

		registration.ready = true

		local sent, send_error = GameplayControl.send_to_client(channel_id, "server_settings", {
			max_members = Session.max_members(),
		})

		if not sent then
			return false, send_error
		end

		return notify_ready(channel_id, registration)
	end)

	GameplayControl.register_client_handler("server_settings", function (channel_id, peer_id, data)
		local applied, apply_error = Session.apply_remote_max_members(data.max_members)

		if applied then
			local registration = registered_channels[channel_id]

			registration.ready = true

			return notify_ready(channel_id, registration)
		end

		return applied, apply_error
	end)
end

function GameplayControl.register_host_handler(message_type, handler)
	if host_handlers[message_type] then
		error("Gameplay-control host handler already registered for " .. message_type)
	end

	host_handlers[message_type] = handler
end

function GameplayControl.register_client_handler(message_type, handler)
	if client_handlers[message_type] then
		error("Gameplay-control client handler already registered for " .. message_type)
	end

	client_handlers[message_type] = handler
end

function GameplayControl.register_disconnect_handler(name, handler)
	if disconnect_handlers[name] then
		error("Gameplay-control disconnect handler already registered for " .. name)
	end

	disconnect_handlers[name] = handler
end

function GameplayControl.register_ready_handler(name, handler)
	if ready_handlers[name] then
		error("Gameplay-control ready handler already registered for " .. name)
	end

	ready_handlers[name] = handler
end

function GameplayControl.remote_connected(channel_id, peer_id)
	if not Session.is_active_host() or not game_session_active() then
		return
	end

	local registration, register_error = register_channel(channel_id, peer_id, "host")

	if not registration then
		fail_channel(channel_id, register_error)
	end
end

function GameplayControl.remote_disconnected(channel_id, peer_id)
	unregister_channel(channel_id)
	notify_disconnected(peer_id)
end

function GameplayControl.send_to_host(message_type, data)
	if not Session.is_active_client() or not game_session_active() then
		return false, "Gameplay-control client session is unavailable"
	end

	local connection = active_client_connection()
	local channel_id = connection and connection:host_channel()

	if not channel_id then
		return false, "Gameplay-control host channel is unavailable"
	end

	local payload, encode_error = encode_message(message_type, data)

	if not payload then
		return false, encode_error
	end

	return send_frames(payload, function (chunk, is_last)
		RPC.rpc_check_mechanism(channel_id, chunk, is_last)
	end)
end

function GameplayControl.send_to_client(channel_id, message_type, data)
	local registration = registered_channels[channel_id]

	if not Session.is_active_host() or not registration or registration.role ~= "host" or not registration.ready then
		return false, "Gameplay-control client channel is unavailable"
	end

	local payload, encode_error = encode_message(message_type, data)

	if not payload then
		return false, encode_error
	end

	return send_frames(payload, function (chunk, is_last)
		RPC.rpc_check_mechanism_reply(channel_id, is_last, chunk)
	end)
end

function GameplayControl.send_to_peer(peer_id, message_type, data)
	if not Session.is_active_host() or not game_session_active() then
		return false, "Gameplay-control host session is unavailable"
	end

	peer_id = normalize_peer_id(peer_id)

	for channel_id, registration in pairs(registered_channels) do
		if registration.role == "host" and registration.ready and registration.peer_id == peer_id then
			return GameplayControl.send_to_client(channel_id, message_type, data)
		end
	end

	return false, "Gameplay-control peer is unavailable"
end

function GameplayControl.send_to_clients(message_type, data, excluded_peer_id)
	if not Session.is_active_host() or not game_session_active() then
		return false, "Gameplay-control host session is unavailable"
	end

	excluded_peer_id = excluded_peer_id and normalize_peer_id(excluded_peer_id) or nil

	for channel_id, registration in pairs(registered_channels) do
		if registration.role == "host" and registration.ready and registration.peer_id ~= excluded_peer_id then
			local sent, send_error = GameplayControl.send_to_client(channel_id, message_type, data)

			if not sent then
				return false, send_error
			end
		end
	end

	return true
end

function GameplayControl.is_peer_available(peer_id)
	peer_id = normalize_peer_id(peer_id)

	for _, registration in pairs(registered_channels) do
		if registration.ready and registration.peer_id == peer_id then
			return true
		end
	end

	return false
end

function GameplayControl.ready_peer_ids()
	local peer_ids = {}

	for _, registration in pairs(registered_channels) do
		if registration.ready then
			peer_ids[#peer_ids + 1] = registration.peer_id
		end
	end

	return peer_ids
end

function GameplayControl.is_available()
	if not game_session_active() then
		return false
	end
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

function GameplayControl.broadcast_server_settings()
	if not Session.is_active_host() or not game_session_active() then
		return
	end

	for channel_id, registration in pairs(registered_channels) do
		if registration.role == "host" and registration.ready then
			local sent, send_error = GameplayControl.send_to_client(channel_id, "server_settings", {
				max_members = Session.max_members(),
			})

			if not sent then
				mod:error("Failed synchronizing server settings channel=%d: %s", channel_id, send_error)
			end
		end
	end
end

local function receive_message(channel_id, expected_role, payload)
	local registration = registered_channels[channel_id]

	local message, decode_error = GameplayControlProtocol.decode(payload)

	if not message then
		fail_channel(channel_id, decode_error)

		return
	end

	local handler = expected_role == "host" and host_handlers[message.type] or client_handlers[message.type]

	if not handler then
		fail_channel(channel_id, "Gameplay-control message has no registered handler")

		return
	end

	local accepted, handler_error = handler(channel_id, registration.peer_id, message.data)

	if accepted == false then
		fail_channel(channel_id, handler_error or "Gameplay-control message was rejected")
	end
end

local function receive_frame(channel_id, expected_role, is_last, chunk)
	local registration = registered_channels[channel_id]

	if not registration or registration.role ~= expected_role then
		fail_channel(channel_id, "Gameplay-control frame arrived outside a registered Realms channel")

		return
	end
	if type(is_last) ~= "boolean"
		or type(chunk) ~= "string"
		or #chunk == 0
		or #chunk > GameplayControlProtocol.MAX_FRAME_SIZE
	then
		fail_channel(channel_id, "Gameplay-control frame is invalid")

		return
	end

	if not registration.receive_chunks then
		registration.receive_chunks = {}
		registration.receive_size = 0
		registration.receive_started_at = Managers.time:time("main")
	end

	registration.receive_chunks[#registration.receive_chunks + 1] = chunk
	registration.receive_size = registration.receive_size + #chunk

	if registration.receive_size > GameplayControlProtocol.MAX_MESSAGE_SIZE then
		fail_channel(channel_id, "Gameplay-control message exceeds the size limit")

		return
	end
	if not is_last then
		return
	end

	local payload = table.concat(registration.receive_chunks)

	registration.receive_chunks = nil
	registration.receive_size = 0
	registration.receive_started_at = nil

	receive_message(channel_id, expected_role, payload)
end

function GameplayControl.rpc_check_mechanism(self, channel_id, payload, is_last)
	receive_frame(channel_id, "host", is_last, payload)
end

function GameplayControl.rpc_check_mechanism_reply(self, channel_id, is_last, payload)
	receive_frame(channel_id, "client", is_last, payload)
end

local function expire_partial_messages()
	if not next(registered_channels) then
		return
	end

	local t = Managers.time:time("main")

	for channel_id, registration in pairs(registered_channels) do
		if registration.receive_started_at and t - registration.receive_started_at > REASSEMBLY_TIMEOUT then
			registration.receive_chunks = nil
			registration.receive_size = 0
			registration.receive_started_at = nil

			fail_channel(channel_id, "Gameplay-control message reassembly timed out")
		end
	end
end

function GameplayControl.update()
	expire_partial_messages()

	local host_connection = active_host_connection()

	if host_connection and game_session_active() then
		local connected_peers = host_connection:connected_peers()

		for channel_id, peer_id in pairs(connected_peers) do
			if not registered_channels[channel_id] then
				GameplayControl.remote_connected(channel_id, peer_id)
			end
		end

		local registered_ids = table.keys(registered_channels)

		for i = 1, #registered_ids do
			local channel_id = registered_ids[i]
			local registration = registered_channels[channel_id]

			if registration.role == "host" and not connected_peers[channel_id] then
				GameplayControl.remote_disconnected(channel_id, registration.peer_id)
			end
		end

		return
	end

	local client_connection = active_client_connection()

	if client_connection and game_session_active() then
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

		local t = Managers.time:time("main")

		if not registration.ready and (not registration.hello_sent_at or t - registration.hello_sent_at >= HELLO_RETRY_INTERVAL) then
			local sent, send_error = GameplayControl.send_to_host("hello", {})

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

return GameplayControl
