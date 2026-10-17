local mod = get_mod("Realms")
local Audio = mod:io_dofile("Realms/scripts/mods/Realms/runtime/voice")
local ChatConstants = require("scripts/foundation/managers/chat/chat_manager_constants")
local ffi = Mods.lua.ffi
local Voice = {}
local Session, SessionControl, BinaryNetwork
local connection, failed_connection, privilege
local running = false
local speakers = {}
local next_speaker = 0
local mute_revision = 0
local permission_generation = 0
local last_capture_stream, volume
local last_packet_speaking = false
local stream_state = mod:persistent_table("voice_stream")
local wire = ffi.new("uint32_t[2]")
local MESSAGE_TYPE = 1
local CHANNEL = "realms_voice"
local FRAME_MS = 20
local BITRATE = 24000
local DEVICE_PERIOD_MS = 10
local SPEAKING_TIMEOUT = 0.3
local PACKET_LIFETIME_MS = 100
local HEADER_SIZE = ffi.sizeof(wire)
local MAX_PACKET_SIZE = 960
local MAX_PACKETS_PER_UPDATE = 8
local NATIVE_SPEAKER_ROWS = 4
local COUNTER_MODULUS = 4294967296
local COUNTER_HALF = COUNTER_MODULUS / 2

local function set_speaking(speaker, speaking)
	if speaker.participant.is_speaking == speaking then
		return
	end

	speaker.participant.is_speaking = speaking
	Managers.event:trigger("chat_manager_participant_update", CHANNEL, speaker.participant)
end

function Voice.stop()
	local was_running = running
	permission_generation = permission_generation + 1
	privilege = nil
	local stopped, stop_error = Audio.stop()
	running = false

	for _, speaker in pairs(speakers) do
		set_speaking(speaker, false)
	end
	table.clear(speakers)
	last_capture_stream, volume = nil, nil
	last_packet_speaking = false
	next_speaker = 0
	if was_running then
		Managers.event:trigger("voip_manager_updated_channel_state", CHANNEL, ChatConstants.ChannelConnectionState.DISCONNECTED, false)
	end

	return stopped, stop_error
end

local function fail(message)
	failed_connection = connection
	Voice.stop()
	mod:error("Voice chat stopped: %s", message)
end

local function player_info(player)
	return Managers.data_service.social:get_player_info_by_account_id(player:account_id())
end

local function can_hear(info)
	if info:is_voice_muted() or info:is_blocked() then
		return false
	end
	if not IS_GDK then
		return true
	end

	local account = Managers.account

	if info:platform() ~= Managers.data_service.social:platform() then
		local relation = info:is_friend() and XblAnonymousUserType.CrossNetworkFriend or XblAnonymousUserType.CrossNetworkUser

		return not account:has_crossplay_restriction(relation, XblPermission.CommunicateUsingVoice)
	end

	local id = info:platform_user_id()

	if not account:user_restriction_verified(id, XblPermission.CommunicateUsingVoice) then
		account:verify_user_restriction_batched(id, XblPermission.CommunicateUsingVoice, "CHAT_MISSION")

		return nil
	end

	return not account:user_has_restriction(id, XblPermission.CommunicateUsingVoice)
end

local function refresh_speakers(t)
	local present = {}

	for _, player in pairs(Managers.player:human_players()) do
		local peer_id = string.lower(tostring(player:peer_id()))
		local info = player_info(player)

		if info and info:character_name() and info:user_display_name() then
			present[peer_id] = true
			local speaker = speakers[peer_id]

			if speaker and speaker.player ~= player then
				set_speaking(speaker, false)
				local removed, remove_error = Audio.remove_speaker(speaker.id)

				if not removed then
					return false, remove_error
				end
				speaker = nil
			end
			if not speaker then
				next_speaker = next_speaker + 1
				speaker = {
					id = next_speaker,
					player = player,
					participant = {
						account_id = player:account_id(),
						is_speaking = false,
						is_muted_for_me = false,
						realms_voice = true,
					},
				}
				speakers[peer_id] = speaker
			end

			local muted = speaker.participant.is_muted_for_me

			if speaker.mute_revision ~= mute_revision then
				local allowed = player == Managers.player:local_player(1) or can_hear(info)
				muted = not allowed
				-- Pending privacy checks stay muted but must be rechecked after a failed batch.
				speaker.mute_revision = allowed ~= nil and mute_revision or nil
			end

			if muted and not speaker.participant.is_muted_for_me then
				local removed, remove_error = Audio.remove_speaker(speaker.id)

				if not removed then
					return false, remove_error
				end
				speaker.sequence = nil
			end
			speaker.participant.is_muted_for_me = muted

			if muted or not speaker.last_audio or t - speaker.last_audio >= SPEAKING_TIMEOUT then
				set_speaking(speaker, false)
			end
		end
	end

	for peer_id, speaker in pairs(speakers) do
		if not present[peer_id] then
			set_speaking(speaker, false)
			local removed, remove_error = Audio.remove_speaker(speaker.id)

			if not removed then
				return false, remove_error
			end
			speakers[peer_id] = nil
		end
	end

	return true
end

local function receive(peer_id, payload, reliable)
	if reliable or #payload <= HEADER_SIZE or #payload > HEADER_SIZE + MAX_PACKET_SIZE then
		return false, "Voice packet framing is invalid"
	end
	if not running then
		return true
	end

	local speaker = speakers[peer_id]

	if not speaker or speaker.participant.is_muted_for_me then
		return true
	end

	ffi.copy(wire, payload, HEADER_SIZE)
	local stream, sequence = tonumber(wire[0]), tonumber(wire[1])

	if speaker.stream ~= stream then
		if speaker.stream and (stream - speaker.stream) % COUNTER_MODULUS >= COUNTER_HALF then
			return true
		end

		local removed, remove_error = Audio.remove_speaker(speaker.id)

		if not removed then
			fail(remove_error)

			return true
		end
		speaker.stream, speaker.sequence = stream, nil
	end

	if speaker.sequence then
		local distance = (sequence - speaker.sequence) % COUNTER_MODULUS

		if distance == 0 or distance >= COUNTER_HALF then
			return true
		end
		for _ = 1, math.min(distance - 1, 2) do
			local concealed, conceal_error = Audio.submit(speaker.id, "")

			if not concealed then
				fail(conceal_error)

				return true
			end
		end
	end

	local submitted, submit_error = Audio.submit(speaker.id, string.sub(payload, HEADER_SIZE + 1))

	if not submitted then
		fail(submit_error)

		return true
	end

	speaker.sequence = sequence
	speaker.last_audio = Managers.time:time("main")
	set_speaking(speaker, true)

	return true
end

local function capture_settings()
	local mode = Application.user_setting("sound_settings", "voice_chat")

	if mode == nil then
		mode = 2
	end
	if mode == 1 then
		return true, true
	end
	if mode ~= 2 then
		return false, false
	end

	local input = Managers.chat._input_service

	return true, input and input:has("voip_push_to_talk") and not not input:get("voip_push_to_talk") or false
end

function Voice.update()
	local manager = Managers.connection
	local current = Session.is_active_host() and manager._connection_host
		or Session.is_active_client() and manager._connection_client or nil
	local player = Managers.player and Managers.player:local_player_safe(1)
	local ready = current and SessionControl.is_available() and player and Managers.chat
		and Managers.chat._privileges_manager and Managers.data_service and Managers.data_service.social
	local own_info = ready and player_info(player)
	ready = ready and own_info and own_info:character_name() and own_info:user_display_name()

	if current ~= connection then
		if running then
			Voice.stop()
		end
		connection, failed_connection, privilege = current, nil, nil
	end
	if not ready or current == failed_connection then
		if running then
			Voice.stop()
		end

		return
	end
	if privilege == nil then
		privilege = "pending"
		local requesting_connection = connection
		local requesting_generation = permission_generation
		Managers.chat._privileges_manager:communications_privilege(false):next(function (result)
			if connection == requesting_connection and permission_generation == requesting_generation then
				privilege = result.has_privilege == true

				if not privilege then
					fail("Communications privilege denied: " .. tostring(result.deny_reason))
				end
			end
		end):catch(function (message)
			if connection == requesting_connection and permission_generation == requesting_generation then
				fail("Could not check communications privilege: " .. tostring(message))
			end
		end)
	end
	if privilege ~= true then
		return
	end
	if not running then
		local started, start_error = Audio.start({
			frame_ms = FRAME_MS,
			bitrate = BITRATE,
			device_period_ms = DEVICE_PERIOD_MS,
			echo_cancellation = mod:get("voice_echo_cancellation"),
			noise_suppression = mod:get("voice_noise_suppression"),
		})

		if not started then
			fail(start_error)

			return
		end
		running = true
		Managers.event:trigger("voip_manager_updated_channel_state", CHANNEL, ChatConstants.ChannelConnectionState.CONNECTED, false)
	end

	local updated, update_error = Audio.update()

	if not updated then
		fail(update_error)

		return
	end

	local t = Managers.time:time("main")
	local refreshed, refresh_error = refresh_speakers(t)

	if not refreshed then
		fail(refresh_error)

		return
	end

	local capture, wanted = capture_settings()
	capture = capture and Audio.capture_available()
	wanted = capture and wanted

	if capture ~= Audio.is_capture_enabled() then
		local changed, change_error = Audio.set_capture(capture)

		if not changed then
			fail(change_error)

			return
		end
	end
	if wanted ~= Audio.is_transmitting() then
		local changed, change_error = Audio.set_transmission(wanted)

		if not changed then
			fail(change_error)

			return
		end
	end

	local setting = Application.user_setting("sound_settings", "options_voip_volume_slider_v2")
	local gain = (setting == nil and 50 or setting) / 50

	if gain ~= volume then
		local changed, change_error = Audio.set_volume(gain)

		if not changed then
			fail(change_error)

			return
		end
		volume = gain
	end

	local own_speaker = speakers[string.lower(tostring(Network.peer_id()))]

	if not wanted and own_speaker then
		set_speaking(own_speaker, false)
	end

	for _ = 1, MAX_PACKETS_PER_UPDATE do
		local packet, poll_error = Audio.poll()

		if packet == nil then
			fail(poll_error)

			return
		end
		if not packet then
			break
		end
		if packet.stream ~= last_capture_stream then
			last_capture_stream = packet.stream
			last_packet_speaking = false
		end
		if packet.speaking then
			if not last_packet_speaking then
				stream_state.id = ((stream_state.id or 0) + 1) % COUNTER_MODULUS
			end
			wire[0], wire[1] = stream_state.id, packet.sequence
			local payload = ffi.string(wire, HEADER_SIZE) .. packet.payload
			local sent, send_error = BinaryNetwork.send(MESSAGE_TYPE, "others", payload, false, PACKET_LIFETIME_MS)

			if not sent then
				fail(send_error)

				return
			end
			if own_speaker then
				own_speaker.last_audio = t
				set_speaking(own_speaker, true)
			end
		end
		last_packet_speaking = packet.speaking
	end
end

function Voice.processing_settings_changed()
	if not running then
		return
	end

	local updated, update_error = Audio.set_processing(mod:get("voice_echo_cancellation"), mod:get("voice_noise_suppression"))

	if not updated then
		fail(update_error)
	end
end

local function update_speaking_list(self)
	local capacity = self._realms_voice_capacity or NATIVE_SPEAKER_ROWS
	local count = running and #self._players_speaking_order or 0
	local definitions = self._definitions
	local template = definitions.widget_definitions.player_4
	local positions = definitions.scenegraph_definition
	local spacing = positions.player_4.position[2] - positions.player_3.position[2]

	for i = capacity + 1, count do
		local widget = self:_create_widget("player_" .. i, template)
		widget.offset[2] = widget.offset[2] + (i - NATIVE_SPEAKER_ROWS) * spacing
		self._widgets[#self._widgets + 1] = widget
	end
	capacity = math.max(capacity, count)
	self._realms_voice_capacity = capacity

	for i = NATIVE_SPEAKER_ROWS + 1, capacity do
		local content = self._widgets_by_name["player_" .. i].content
		local account_id = running and self._players_speaking_order[i] or nil
		content.account_id = account_id
		content.display_name = account_id and self._available_players[account_id] or ""
		content.visible = account_id ~= nil and self._players_speaking[account_id] == true and content.display_name ~= ""
	end
end

function Voice.install(session, session_control, binary_network)
	Session, SessionControl, BinaryNetwork = session, session_control, binary_network
	BinaryNetwork.register(MESSAGE_TYPE, receive)
	mod:hook_safe(CLASS.ChatManager, "player_mute_status_changed", function ()
		mute_revision = mute_revision + 1
		privilege = nil
	end)

	mod:hook(CLASS.ConstantElementVoiceChat, "_voip_manager_updated_channel_state", function (func, self, channel, state, incoming)
		if running then
			state = ChatConstants.ChannelConnectionState.CONNECTED
		elseif channel == CHANNEL then
			self._ready = false
		end

		return func(self, channel, state, incoming)
	end)

	for _, class in ipairs({ CLASS.ConstantElementVoiceChat, CLASS.HudElementPlayerPanelBase }) do
		mod:hook(class, "_chat_manager_participant_update", function (func, self, channel, participant)
			if running and not participant.realms_voice then
				return
			end

			return func(self, channel, participant)
		end)
	end

	mod:hook_safe(CLASS.ConstantElementVoiceChat, "init", function (self)
		if running then
			self:_voip_manager_updated_channel_state(CHANNEL, ChatConstants.ChannelConnectionState.CONNECTED, false)

			for _, speaker in pairs(speakers) do
				self:_chat_manager_participant_update(CHANNEL, speaker.participant)
			end
		end
	end)
	mod:hook_safe(CLASS.ConstantElementVoiceChat, "_update_players_speaking", update_speaking_list)
end

return Voice
