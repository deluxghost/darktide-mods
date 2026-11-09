local mod = get_mod("Realms")
local NativeSteam = mod:io_dofile("Realms/scripts/mods/Realms/runtime/steam")
local EVENT_TYPES = NativeSteam.EVENT_TYPES
local SteamPlatform = Steam

local Steam = {}
local Session
local local_id
local host_connection
local host_failed
local requested_target
local pending_target
local initialized = false
local client_owned = false

local function client_boot()
	local manager = Managers.multiplayer_session
	local boot = manager and manager._session_boot

	return boot and boot.__class_name == "RealmsClientSessionBoot" and boot or nil
end

local function target()
	if host_connection and not host_failed then
		return local_id
	end
	if Session.is_active_client() then
		return Managers.connection._connection_client._realms_steam_host
	end
end

local function publish(force)
	local current_target = target()

	if not force and current_target == requested_target then
		return
	end
	requested_target = current_target

	local changed, change_error = NativeSteam.publish_target(current_target)

	if not changed then
		mod:error("Steam join information update failed: %s", change_error)

		return
	end

	if not current_target and Managers.presence then
		Managers.presence:_update_platform_presence()
	end
end

function Steam.host_id()
	return host_connection and not host_failed and local_id or nil
end

function Steam.join(steam_id)
	if not local_id then
		return false, mod:localize("steam_unavailable")
	end
	if steam_id == local_id then
		return false, mod:localize("steam_join_self")
	end
	if pending_target == steam_id or Session.is_joining() then
		return false, mod:localize("error_join_already_pending")
	end

	pending_target = steam_id

	return true
end

local function friend_id(player_info)
	if not local_id or player_info:is_own_player() or player_info:is_blocked() or player_info:platform() ~= "steam" then
		return
	end

	local id = player_info:platform_user_id()

	if not id or id == "" then
		return
	end
	if Friends.relationship(id) ~= Friends.FRIEND then
		return
	end

	return SteamPlatform.id_hex_to_dec(tostring(id))
end

function Steam.friend_target(player_info)
	local id = friend_id(player_info)

	if not id then
		return
	end

	local host, lookup_error = NativeSteam.friend_target(id)

	if lookup_error then
		mod:warning("Steam friend lookup failed: %s", lookup_error)
	end

	return host ~= local_id and host or nil
end

function Steam.can_invite(player_info)
	return target() ~= nil and friend_id(player_info) ~= nil
end

function Steam.invite(player_info)
	local host = target()
	local id = friend_id(player_info)

	if not host or not id then
		return false, mod:localize("steam_unavailable")
	end

	return NativeSteam.invite(id, host)
end

function Steam.initialize()
	if initialized or not HAS_STEAM then
		return
	end

	initialized = true

	local initialize_error

	local_id, initialize_error = NativeSteam.initialize()

	if not local_id then
		mod:warning("Steam transport is unavailable: %s", initialize_error)
	end
end

function Steam.update()
	if not local_id then
		return
	end
	NativeSteam.update()

	local connection = Session.is_active_host() and Managers.connection._connection_host or nil

	if connection ~= host_connection then
		if host_connection then
			NativeSteam.stop_host()
		end

		host_connection = connection
		host_failed = false

		if connection then
			local started, start_error = NativeSteam.start_host(connection:password_required())

			if not started then
				host_failed = true
				mod:warning("Steam listener could not start: %s", start_error)
			end
		end
	end

	while true do
		local event, event_error = NativeSteam.poll_event()

		if not event then
			if event_error then
				mod:error("Steam event polling failed: %s", event_error)
			end

			break
		end
		if event.type == EVENT_TYPES.join_requested then
			local accepted, join_error = Steam.join(event.steam_id)

			if not accepted and not Session.is_joining() then
				mod:notify("%s", join_error)
			end
		elseif event.type == EVENT_TYPES.host_error then
			mod:warning("Steam host transport error code=%d: %s", event.code, event.message)
		elseif event.type == EVENT_TYPES.presence_updated then
			Managers.event:trigger("realms_steam_presence_updated")
		else
			local boot = client_boot()

			if boot then
				boot:steam_event(event)
			elseif event.type == EVENT_TYPES.client_error then
				mod:info("Steam client transport closed code=%d: %s", event.code, event.message)
			end
		end
	end

	if pending_target and Managers.ui and Managers.multiplayer_session and Managers.connection
		and not Managers.multiplayer_session:is_booting_session() then
		local player = Managers.player and Managers.player:local_player_safe(1)

		if player and player:profile() then
			local join_target = pending_target

			pending_target = nil

			local started, start_error = Session.start_steam_client(join_target)

			if started then
				client_owned = true
			else
				mod:notify("%s", start_error)
			end
		end
	end

	local steam_client = Session.is_active_client() and Managers.connection._connection_client._realms_transport == "steam"

	if client_owned and not Session.is_joining() and not steam_client then
		NativeSteam.disconnect()
		client_owned = false
	end

	publish()
end

function Steam.settings_changed()
	if local_id and Session.is_active_host() then
		NativeSteam.password_changed(Managers.connection._connection_host:password_required())
	end
end

function Steam.shutdown(is_exiting)
	if not is_exiting or not local_id then
		return
	end

	NativeSteam.shutdown()
	local_id = nil
	initialized = false
	requested_target = nil
	pending_target = nil
	host_connection = nil
	client_owned = false

	if Managers.presence then
		Managers.presence:_update_platform_presence()
	end
end

function Steam.install(session)
	Session = session
	if not HAS_STEAM then
		return
	end

	mod:hook_safe(Presence, "advertise_immaterium_party", function ()
		if local_id and target() then
			publish(true)
		end
	end)
end

function Steam.status_lines()
	if not local_id then
		return {"  steam=unavailable"}
	end

	local status, status_error = NativeSteam.status()

	if not status then
		return {"  steam_error=" .. status_error}
	end

	return {
		string.format("  steam_auth=%d relay=%d listening=%s connections=%d drops=%d", status.authentication, status.relay, tostring(status.listening), status.connections, status.dropped_datagrams),
	}
end

return Steam
