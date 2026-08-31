local mod = get_mod("Realms")
local ChatProtocol = mod:io_dofile("Realms/scripts/mods/Realms/protocol/chat_protocol")

local Chat = {}
local pending_messages = {}
local Session
local SessionControl

local MAX_PENDING_MESSAGES = 16

local function player_at(peer_id, local_player_id)
	local player_manager = Managers.player

	return player_manager and player_manager:player(peer_id, local_player_id) or nil
end

local function local_player()
	local player_manager = Managers.player

	return player_manager and player_manager:local_player(1) or nil
end

local function show_message(data)
	Managers.event:trigger("realms_chat_message", data.text, data.sender_name)
end

local function delivery(player_name, text)
	return {
		sender_name = player_name,
		text = text,
	}
end

local function broadcast(data)
	show_message(data)

	local peer_ids = SessionControl.ready_peer_ids()

	for i = 1, #peer_ids do
		local peer_id = peer_ids[i]
		local sent, send_error = SessionControl.send_to_peer(peer_id, ChatProtocol.NAME, "chat_deliver", data)

		if not sent then
			mod:info("Chat delivery skipped peer %s: %s", peer_id, send_error)
		end
	end

	return true
end

local function reject(channel_id, reason)
	local sent, send_error = SessionControl.send_to_client(channel_id, ChatProtocol.NAME, "chat_rejected", {
		reason = reason,
	})

	if not sent then
		mod:info("Chat rejection could not be delivered: %s", send_error)
	end

	return true
end

local function receive_submission(channel_id, peer_id, data)
	local player = player_at(peer_id, data.local_player_id)

	if not player then
		return reject(channel_id, "sender_unavailable")
	end

	return broadcast(delivery(player:name(), data.text))
end

local function receive_delivery(channel_id, peer_id, data)
	show_message(data)

	return true
end

local function receive_rejection(channel_id, peer_id, data)
	mod:error(mod:localize("chat_sender_unavailable"))

	return true
end

local function send_pending()
	if not Session.is_active_client() or not SessionControl.is_available() then
		return
	end

	while #pending_messages > 0 do
		local message = pending_messages[1]
		local sent, send_error = SessionControl.send_to_host(ChatProtocol.NAME, "chat_submit", message)

		if not sent then
			mod:info("Chat message is waiting for the session channel: %s", send_error)

			return
		end

		table.remove(pending_messages, 1)
	end
end

function Chat.install(session, session_control)
	Session = session
	SessionControl = session_control

	SessionControl.register_protocol(ChatProtocol)
	SessionControl.register_host_handler(ChatProtocol.NAME, "chat_submit", receive_submission)
	SessionControl.register_client_handler(ChatProtocol.NAME, "chat_deliver", receive_delivery)
	SessionControl.register_client_handler(ChatProtocol.NAME, "chat_rejected", receive_rejection)
	SessionControl.register_disconnect_handler("chat", function ()
		table.clear(pending_messages)
	end)
end

function Chat.is_active()
	return Session and Session.is_active()
end

function Chat.submit(text)
	if not Chat.is_active() then
		return false, "Realms chat is unavailable"
	end

	local measured, text_length = pcall(Utf8.string_length, text)

	if not measured or text_length < 1 or text_length > ChatProtocol.MAX_TEXT_CHARACTERS then
		return false, mod:localize("chat_message_invalid")
	end

	local player = local_player()

	if not player then
		return false, mod:localize("chat_sender_unavailable")
	end

	if Session.is_active_host() then
		return broadcast(delivery(player:name(), text))
	end

	local message = {
		local_player_id = player:local_player_id(),
		text = text,
	}

	if #pending_messages >= MAX_PENDING_MESSAGES then
		return false, mod:localize("chat_queue_full")
	end

	pending_messages[#pending_messages + 1] = message
	send_pending()

	return true
end

function Chat.update()
	if not Chat.is_active() then
		table.clear(pending_messages)

		return
	end

	send_pending()
end

return Chat
