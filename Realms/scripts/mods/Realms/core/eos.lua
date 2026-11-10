local mod = get_mod("Realms")
local NativeEos = mod:io_dofile("Realms/scripts/mods/Realms/runtime/eos")
local StatusFormat = mod:io_dofile("Realms/scripts/mods/Realms/core/status_format")
local EVENT_TYPES = NativeEos.EVENT_TYPES
local STATES = NativeEos.STATES

-- Cross-platform play through Epic Online Services. Opt-in: nothing touches EOS until the
-- crossplay setting is enabled, and joining is only possible through in-game invite codes.
local Eos = {}
local SETTING_ID = "enable_crossplay"
local Session
local running = false
local ready = false
local host_connection
local host_failed
local host_code
local invites_open = false
local pending_resolve
local pending_target
local client_owned = false

local function client_boot()
	local manager = Managers.multiplayer_session
	local boot = manager and manager._session_boot

	return boot and boot.__class_name == "RealmsClientSessionBoot" and boot or nil
end

local function display_name()
	local player = Managers.player and Managers.player:local_player_safe(1)
	local name = player and player:name()

	return type(name) == "string" and name ~= "" and name or "Realms"
end

-- The caller's report callback shows the failure when it still can. Otherwise it becomes a notification.
local function join_failed(request, message)
	if not (request.report and request.report(message)) then
		mod:notify("%s", message)
	end
end

local function stop_host()
	if host_connection and not host_failed then
		NativeEos.stop_host()
	end

	host_connection = nil
	host_failed = false
	invites_open = false
	host_code = nil
end

local function start()
	if running then
		return true
	end

	local available, available_error = NativeEos.available()

	if not available then
		return false, available_error
	end

	local started, start_error = NativeEos.start(display_name())

	if not started then
		return false, start_error
	end

	running = true
	ready = false

	return true
end

local function stop(is_exiting)
	if not running then
		if is_exiting then
			NativeEos.stop(true)
		end

		return
	end

	stop_host()
	NativeEos.stop(is_exiting)
	running = false
	ready = false
	pending_resolve = nil
	pending_target = nil
	client_owned = false
end

function Eos.enabled()
	return mod:get(SETTING_ID) == true
end

function Eos.is_ready()
	return ready
end

-- Invite code of the hosted session, or nil while unavailable.
function Eos.host_code()
	return host_connection and not host_failed and invites_open and host_code or nil
end

-- Starts joining by invite code. Returns false and a localized error when it cannot begin.
-- report(message) is called on failure and returns true when it displayed the message itself.
function Eos.join(code_text, password, report)
	if not Eos.enabled() then
		return false, mod:localize("eos_disabled")
	end
	if not ready then
		return false, mod:localize("eos_not_ready")
	end

	local code = NativeEos.normalize_code(code_text)

	if not code then
		return false, mod:localize("eos_code_invalid")
	end
	if code == Eos.host_code() then
		return false, mod:localize("steam_join_self")
	end
	if pending_resolve or pending_target or Session.is_joining() then
		return false, mod:localize("error_join_already_pending")
	end

	local resolving, resolve_error = NativeEos.resolve_code(code)

	if not resolving then
		return false, resolve_error
	end

	pending_resolve = {
		code = code,
		password = password or "",
		report = report,
	}

	return true
end

function Eos.is_resolving()
	return pending_resolve ~= nil
end

local function handle_event(event)
	local kind = event.type

	if kind == EVENT_TYPES.login_succeeded then
		ready = true
		mod:info("EOS signed in as %s", event.remote)
	elseif kind == EVENT_TYPES.login_failed then
		ready = false
		mod:warning("EOS sign-in failed code=%d: %s", event.code, event.message)
	elseif kind == EVENT_TYPES.host_code then
		if host_connection and not host_failed and invites_open then
			mod:info("EOS invite code published for lobby %s", event.message)
			host_code = event.text
		end
	elseif kind == EVENT_TYPES.host_code_failed then
		mod:warning("EOS invite code could not be published code=%d: %s", event.code, event.message)
	elseif kind == EVENT_TYPES.code_resolved or kind == EVENT_TYPES.code_failed then
		local request = pending_resolve

		if not request or request.code ~= event.text then
			return
		end

		pending_resolve = nil

		if kind == EVENT_TYPES.code_failed then
			if event.code == NativeEos.CODE_ERRORS.not_found then
				join_failed(request, mod:localize("eos_code_not_found"))
			else
				mod:warning("EOS invite code lookup failed: %s", event.message)
				join_failed(request, mod:localize("eos_code_lookup_failed"))
			end

			return
		end
		pending_target = {
			remote = event.remote,
			password = request.password,
			report = request.report,
		}
	elseif kind == EVENT_TYPES.host_error then
		mod:warning("EOS host transport error code=%d: %s", event.code, event.message)
	elseif kind == EVENT_TYPES.log then
		mod:info("EOS [%s] %s", event.text, event.message)
	else
		local boot = client_boot()

		if boot then
			boot:transport_event("eos", event)
		elseif kind == EVENT_TYPES.client_error then
			mod:info("EOS client transport closed code=%d: %s", event.code, event.message)
		end
	end
end

local function update_host(enabled)
	local connection = ready and Session.is_active_host() and Managers.connection._connection_host or nil

	if connection ~= host_connection then
		stop_host()

		-- A host session that starts while cross-platform play is off never listens on EOS.
		if connection and enabled then
			host_connection = connection

			local started, start_error = NativeEos.start_host(connection:password_required())

			if started then
				invites_open = true
			else
				host_failed = true
				mod:warning("EOS listener could not start: %s", start_error)
			end
		end

		return
	end

	if not host_connection or host_failed or invites_open == enabled then
		return
	end

	-- Turning cross-platform play off only withdraws the invite code. Players who already joined
	-- through EOS stay connected until the session ends.
	invites_open = enabled
	NativeEos.set_invites_open(enabled)

	if not enabled then
		host_code = nil
	end
end

local function is_eos_client()
	local connection_client = Session.is_active_client() and Managers.connection._connection_client

	return connection_client and connection_client._realms_transport == "eos" or false
end

-- True while the current Realms session still depends on EOS, so stopping it would drop players.
local function in_use()
	if is_eos_client() or client_owned and Session.is_joining() then
		return true
	end
	if host_connection and not host_failed then
		return NativeEos.connection_count() > 0
	end

	return false
end

local function update_client()
	if pending_target and Managers.ui and Managers.multiplayer_session and Managers.connection
		and not Managers.multiplayer_session:is_booting_session() then
		local player = Managers.player and Managers.player:local_player_safe(1)

		if player and player:profile() then
			local target = pending_target

			pending_target = nil

			local started, start_error = Session.start_eos_client(target.remote, target.password)

			if started then
				client_owned = true
			else
				join_failed(target, start_error)
			end
		end
	end

	if client_owned and not Session.is_joining() and not is_eos_client() then
		NativeEos.disconnect()
		client_owned = false
	end
end

function Eos.update()
	local enabled = Eos.enabled()

	if enabled and not running then
		local started, start_error = start()

		if not started then
			-- Stay disabled until the setting changes again rather than retrying every frame.
			mod:set(SETTING_ID, false)
			mod:warning("Cross-platform play is unavailable: %s", start_error)

			return
		end
	end
	if not running then
		return
	end
	if not enabled and (pending_resolve or pending_target) then
		-- Joins that have not connected yet are abandoned. Established sessions are kept.
		local request = pending_resolve or pending_target

		pending_resolve = nil
		pending_target = nil
		join_failed(request, mod:localize("eos_disabled"))
	end

	while true do
		local event, event_error = NativeEos.poll_event()

		if not event then
			if event_error then
				mod:error("EOS event polling failed: %s", event_error)
			end

			break
		end

		handle_event(event)
	end

	update_host(enabled)
	update_client()

	if not enabled and not in_use() then
		stop(false)
	end
end

function Eos.settings_changed()
	if running and host_connection and not host_failed then
		NativeEos.password_changed(host_connection:password_required())
	end
end

function Eos.shutdown(is_exiting)
	if is_exiting then
		stop(true)
	end
end

function Eos.install(session)
	Session = session
end

local NAT_TYPES = {
	[0] = "unknown",
	"open",
	"moderate",
	"strict",
}
local NETWORK_TYPES = {
	[-1] = "none",
	[0] = "none",
	"direct",
	"relay",
}

function Eos.status_lines()
	if not running then
		return {"eos=disabled"}
	end

	local status, status_error = NativeEos.status()

	if not status then
		return {"eos_error=" .. status_error}
	end

	local state_name = "unknown"

	for name, value in pairs(STATES) do
		if value == status.state then
			state_name = name
		end
	end

	-- The invite code is left out because status output may be on stream.
	local path = NETWORK_TYPES[status.client_network_type] or tostring(status.client_network_type)

	return {
		string.format("eos=%s nat=%s invites=%s connections=%d%s sent=%s received=%s drops=%d fragmented=%d", state_name, NAT_TYPES[status.nat_type] or tostring(status.nat_type), status.hosting and "open" or "closed", status.connections, path ~= "none" and " path=" .. path or "", StatusFormat.bytes(status.sent_bytes), StatusFormat.bytes(status.received_bytes), status.dropped_datagrams, status.fragmented_datagrams),
	}
end

return Eos
