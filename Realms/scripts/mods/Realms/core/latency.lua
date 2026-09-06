local mod = get_mod("Realms")
local LatencyProtocol = mod:io_dofile("Realms/scripts/mods/Realms/protocol/latency_protocol")
local format_latency = mod:io_dofile("Realms/scripts/mods/Realms/core/latency_format")

local Latency = {}
local Session
local SessionControl

local SAMPLE_INTERVAL = 1
local state = {
	next_sample_at = 0,
	role = "none",
	samples = {},
}

local function normalize_peer_id(peer_id)
	return string.lower(tostring(peer_id))
end

local function reset(role)
	state.next_sample_at = 0
	state.role = role
	state.samples = {}
end

local function current_role()
	return Session.is_active_host() and "host" or Session.is_active_client() and "client" or "none"
end

local function active_host_connection()
	local connection_manager = Managers.connection

	return Session.is_active_host() and connection_manager and connection_manager._connection_host or nil
end

local function latency_ms(peer_id)
	local seconds = Network.ping(peer_id)

	if type(seconds) ~= "number" or seconds ~= seconds or seconds < 0 or seconds == math.huge then
		return nil
	end

	return math.min(math.floor(seconds * 1000 + 0.5), 2147483647)
end

local function sample_host(connection)
	local samples = {}
	local host_peer_id = normalize_peer_id(Network.peer_id())
	local host_latency = latency_ms(host_peer_id)

	if host_latency then
		samples[host_peer_id] = host_latency
	end

	for _, peer_id in pairs(connection:connected_peers()) do
		peer_id = normalize_peer_id(peer_id)

		local peer_latency = latency_ms(peer_id)

		if peer_latency then
			samples[peer_id] = peer_latency
		end
	end

	state.samples = samples
end

local function snapshot_data()
	return {
		samples = state.samples,
	}
end

local function send_snapshot(channel_id)
	return SessionControl.send_to_client(channel_id, LatencyProtocol.NAME, "snapshot", snapshot_data())
end

local function broadcast_snapshot()
	return SessionControl.send_to_clients(LatencyProtocol.NAME, "snapshot", snapshot_data())
end

local function receive_snapshot(channel_id, peer_id, data)
	local role = current_role()

	if role ~= "client" then
		return false, "Latency snapshot arrived outside a client session"
	end
	if state.role ~= role then
		reset(role)
	end
	state.samples = data.samples

	return true
end

local function peer_name(player)
	return string.gsub(tostring(player:name()), "[\r\n]", " ")
end

local function host_peer_id(connection)
	local peer_id = Session.is_active_host() and Network.peer_id() or connection and connection:host()

	return peer_id and normalize_peer_id(peer_id) or nil
end

function Latency.install(session, session_control)
	Session = session
	SessionControl = session_control

	SessionControl.register_protocol(LatencyProtocol)
	SessionControl.register_client_handler(LatencyProtocol.NAME, "snapshot", receive_snapshot)
	SessionControl.register_ready_handler("latency", function (channel_id, peer_id, role)
		if role == "host" and Session.is_active_host() then
			return send_snapshot(channel_id)
		end

		return true
	end)
	SessionControl.register_disconnect_handler("latency", function (peer_id, channel_id, role)
		if role == "client" then
			reset("none")

			return
		end
		if role == "host" then
			peer_id = normalize_peer_id(peer_id)

			if state.samples[peer_id] ~= nil then
				state.samples[peer_id] = nil
				broadcast_snapshot()
			end
		end
	end)
end

function Latency.update()
	local role = current_role()

	if role ~= state.role then
		reset(role)
	end
	if role ~= "host" then
		return
	end

	local t = Managers.time:time("main")

	if t < state.next_sample_at then
		return
	end

	local connection = active_host_connection()

	if not connection then
		return
	end

	state.next_sample_at = t + SAMPLE_INTERVAL
	sample_host(connection)
	broadcast_snapshot()
end

function Latency.values()
	return state.samples
end

function Latency.status_lines(connection)
	local player_manager = Managers.player
	local players = player_manager and player_manager:human_players() or {}
	local host_id = host_peer_id(connection)
	local rows = {}

	for _, player in pairs(players) do
		local peer_id = normalize_peer_id(player:peer_id())

		rows[#rows + 1] = {
			name = peer_name(player),
			peer_id = peer_id,
			role = peer_id == host_id and "host" or "client",
		}
	end

	table.sort(rows, function (a, b)
		if a.role ~= b.role then
			return a.role == "host"
		end
		if a.name ~= b.name then
			return a.name < b.name
		end

		return a.peer_id < b.peer_id
	end)

	local lines = {
		"  players=" .. tostring(#rows),
	}

	for i = 1, #rows do
		local row = rows[i]

		lines[#lines + 1] = string.format("    %s name:%s peer:%s ping:%s", row.role, row.name, row.peer_id, format_latency(state.samples[row.peer_id]))
	end

	return lines
end

return Latency
