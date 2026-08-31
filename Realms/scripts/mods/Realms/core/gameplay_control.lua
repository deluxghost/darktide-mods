local mod = get_mod("Realms")
local GameplayControlProtocol = mod:io_dofile("Realms/scripts/mods/Realms/protocol/gameplay_control_protocol")

local GameplayControl = {}
local host_handlers = {}
local client_handlers = {}
local disconnect_handlers = {}
local ready_handlers = {}
local ready_peers = {}
local client_ready = false
local hello_sent_at
local phase_active = false
local Preparation
local Session
local SessionControl

local HELLO_RETRY_INTERVAL = 1

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function game_session_active()
	return Managers.state and Managers.state.game_session ~= nil and not Preparation.is_waiting()
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

local function notify_ready(channel_id, peer_id, role)
	return notify(ready_handlers, channel_id, normalize_peer_id(peer_id), role)
end

local function notify_disconnected(peer_id)
	notify(disconnect_handlers, normalize_peer_id(peer_id))
end

local function clear_phase()
	if not phase_active then
		return
	end

	phase_active = false
	hello_sent_at = nil

	if client_ready then
		client_ready = false

		local connection = Managers.connection and Managers.connection._connection_client
		local peer_id = connection and connection:host()

		if peer_id then
			notify_disconnected(peer_id)
		end
	end

	local peer_ids = table.keys(ready_peers)

	for i = 1, #peer_ids do
		ready_peers[peer_ids[i]] = nil
		notify_disconnected(peer_ids[i])
	end
end

local function receive_host_message(message_type, channel_id, peer_id, data)
	if not game_session_active() then
		return true
	end
	if message_type ~= "hello" and not ready_peers[normalize_peer_id(peer_id)] then
		return true
	end

	return host_handlers[message_type](channel_id, peer_id, data)
end

local function receive_client_message(message_type, channel_id, peer_id, data)
	if not game_session_active() then
		return true
	end
	if message_type ~= "server_settings" and not client_ready then
		return true
	end

	return client_handlers[message_type](channel_id, peer_id, data)
end

function GameplayControl.install(session, preparation, session_control)
	Session = session
	Preparation = preparation
	SessionControl = session_control

	SessionControl.register_protocol(GameplayControlProtocol)
	SessionControl.register_disconnect_handler("gameplay_control", function (peer_id)
		local normalized_peer_id = normalize_peer_id(peer_id)

		if ready_peers[normalized_peer_id] then
			ready_peers[normalized_peer_id] = nil
			notify_disconnected(normalized_peer_id)
		elseif client_ready then
			client_ready = false
			hello_sent_at = nil
			notify_disconnected(normalized_peer_id)
		end
	end)

	GameplayControl.register_host_handler("hello", function (channel_id, peer_id)
		peer_id = normalize_peer_id(peer_id)
		local was_ready = ready_peers[peer_id] == true

		ready_peers[peer_id] = true

		local sent, send_error = SessionControl.send_to_client(channel_id, GameplayControlProtocol.NAME, "server_settings", {
			max_members = Session.max_members(),
		})

		if not sent then
			ready_peers[peer_id] = nil

			return false, send_error
		end

		if was_ready then
			return true
		end

		return notify_ready(channel_id, peer_id, "host")
	end)

	GameplayControl.register_client_handler("server_settings", function (channel_id, peer_id, data)
		local applied, apply_error = Session.apply_remote_max_members(data.max_members)

		if not applied then
			return false, apply_error
		end

		local was_ready = client_ready

		client_ready = true

		if was_ready then
			return true
		end

		return notify_ready(channel_id, peer_id, "client")
	end)
end

function GameplayControl.register_host_handler(message_type, handler)
	if host_handlers[message_type] then
		error("Gameplay-control host handler already registered for " .. message_type)
	end

	host_handlers[message_type] = handler
	SessionControl.register_host_handler(GameplayControlProtocol.NAME, message_type, function (channel_id, peer_id, data)
		return receive_host_message(message_type, channel_id, peer_id, data)
	end)
end

function GameplayControl.register_client_handler(message_type, handler)
	if client_handlers[message_type] then
		error("Gameplay-control client handler already registered for " .. message_type)
	end

	client_handlers[message_type] = handler
	SessionControl.register_client_handler(GameplayControlProtocol.NAME, message_type, function (channel_id, peer_id, data)
		return receive_client_message(message_type, channel_id, peer_id, data)
	end)
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

function GameplayControl.send_to_host(message_type, data)
	if not Session.is_active_client() or not game_session_active() or not client_ready then
		return false, "Gameplay-control client session is unavailable"
	end

	return SessionControl.send_to_host(GameplayControlProtocol.NAME, message_type, data)
end

function GameplayControl.send_to_client(channel_id, message_type, data)
	local connection = Managers.connection and Managers.connection._connection_host
	local connected_peers = connection and connection:connected_peers()
	local peer_id = connected_peers and connected_peers[channel_id]

	if not Session.is_active_host()
		or not game_session_active()
		or not peer_id
		or not ready_peers[normalize_peer_id(peer_id)]
	then
		return false, "Gameplay-control client channel is unavailable"
	end

	return SessionControl.send_to_client(channel_id, GameplayControlProtocol.NAME, message_type, data)
end

function GameplayControl.send_to_peer(peer_id, message_type, data)
	peer_id = normalize_peer_id(peer_id)

	if not Session.is_active_host() or not game_session_active() or not ready_peers[peer_id] then
		return false, "Gameplay-control peer is unavailable"
	end

	return SessionControl.send_to_peer(peer_id, GameplayControlProtocol.NAME, message_type, data)
end

function GameplayControl.send_to_clients(message_type, data, excluded_peer_id)
	if not Session.is_active_host() or not game_session_active() then
		return false, "Gameplay-control host session is unavailable"
	end

	excluded_peer_id = excluded_peer_id and normalize_peer_id(excluded_peer_id) or nil

	for peer_id in pairs(ready_peers) do
		if peer_id ~= excluded_peer_id then
			local sent, send_error = SessionControl.send_to_peer(peer_id, GameplayControlProtocol.NAME, message_type, data)

			if not sent then
				return false, send_error
			end
		end
	end

	return true
end

function GameplayControl.is_peer_available(peer_id)
	return ready_peers[normalize_peer_id(peer_id)] == true
end

function GameplayControl.ready_peer_ids()
	return table.keys(ready_peers)
end

function GameplayControl.is_available()
	if not game_session_active() then
		return false
	end
	if Session.is_active_host() then
		return true
	end

	return Session.is_active_client() and client_ready
end

function GameplayControl.broadcast_server_settings()
	if not Session.is_active_host() or not game_session_active() then
		return
	end

	for peer_id in pairs(ready_peers) do
		local sent, send_error = SessionControl.send_to_peer(peer_id, GameplayControlProtocol.NAME, "server_settings", {
			max_members = Session.max_members(),
		})

		if not sent then
			mod:error("Failed synchronizing server settings peer=%s: %s", peer_id, send_error)
		end
	end
end

function GameplayControl.update()
	local active = game_session_active()

	if not active then
		clear_phase()

		return
	end

	phase_active = true

	if not Session.is_active_client() or client_ready or not SessionControl.is_available() then
		return
	end

	local t = Managers.time:time("main")

	if hello_sent_at and t - hello_sent_at < HELLO_RETRY_INTERVAL then
		return
	end

	local sent, send_error = SessionControl.send_to_host(GameplayControlProtocol.NAME, "hello", {})

	if not sent then
		mod:info("Gameplay-control handshake is waiting: %s", send_error)

		return
	end

	hello_sent_at = t
end

return GameplayControl
