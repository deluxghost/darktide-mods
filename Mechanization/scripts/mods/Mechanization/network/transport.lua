local mod = get_mod("Mechanization")
local VehicleNetwork = {
	host_enabled = false,
}
local realms
local solo_play

local function multiplayer ()
	return realms and realms.network_is_available()
end

VehicleNetwork.local_peer = function ()
	return string.lower(tostring(Network.peer_id()))
end

VehicleNetwork.is_host = function ()
	return solo_play and solo_play.has_local_gameplay_authority()
end

VehicleNetwork.available = function ()
	return (VehicleNetwork.is_host() or multiplayer())
		and Managers.state.game_session
		and Managers.state.mission
		and Managers.state.game_mode
		and Managers.state.game_mode:game_mode_name() ~= "hub"
end

VehicleNetwork.from_host = function (sender)
	return multiplayer() and not VehicleNetwork.is_host() and string.lower(tostring(Managers.connection:host())) == sender
end

VehicleNetwork.enabled = function ()
	if VehicleNetwork.is_host() then
		return mod:get("enabled")
	end
	return VehicleNetwork.host_enabled
end

VehicleNetwork.send = function (name, recipient, ...)
	if not multiplayer() then
		return
	end
	local ok, err = realms.network_send(mod, name, recipient, ...)
	if not ok then
		mod:error("Vehicle network %s failed: %s", name, err)
	end
	return ok
end

VehicleNetwork.publish = function (recipient, enabled)
	VehicleNetwork.send("config", recipient, enabled)
end

VehicleNetwork.notice = function (peer, key)
	if peer == VehicleNetwork.local_peer() then
		mod:echo(mod:localize(key))
	else
		VehicleNetwork.send("notice", peer, key)
	end
end

VehicleNetwork.refresh = function ()
	if not VehicleNetwork.available() then
		return
	end
	if VehicleNetwork.is_host() then
		VehicleNetwork.publish("others", mod:get("enabled"))
	else
		VehicleNetwork.host_enabled = false
		VehicleNetwork.send("request", "host")
	end
end

VehicleNetwork.install = function (session)
	solo_play = assert(get_mod("SoloPlay"), "Mechanization requires SoloPlay")
	realms = get_mod("Realms")
	if not realms then
		return
	end
	assert(realms.network_register(mod, "notice", function (sender, key)
		if VehicleNetwork.from_host(sender) then
			assert(key == "no_space" or key == "no_ground" or key == "not_walking", "Invalid vehicle notice")
			mod:echo(mod:localize(key))
		end
	end))
	assert(realms.network_register(mod, "request", function (sender)
		if VehicleNetwork.available() and VehicleNetwork.is_host() then
			VehicleNetwork.publish(sender, mod:get("enabled"))
			session.send_all(sender)
		end
	end))
	assert(realms.network_register(mod, "config", function (sender, enabled)
		if not VehicleNetwork.from_host(sender) then
			return
		end
		assert(type(enabled) == "boolean", "Invalid vehicle config")
		VehicleNetwork.host_enabled = enabled
		if not enabled then
			session.cleanup(true)
		end
	end))
	for name, callback in pairs({
		select = session.receive_select,
		board = session.receive_board,
		switch = session.receive_switch,
		leave = session.receive_leave,
		departure = session.receive_departure,
		input = session.receive_input,
		state = session.receive_state,
		event = session.receive_event,
	}) do
		assert(realms.network_register(mod, name, callback))
	end
	assert(realms.network_on_peer_joined(mod, function (id)
		if not VehicleNetwork.available() then
			return
		end
		if VehicleNetwork.is_host() then
			VehicleNetwork.publish(id, mod:get("enabled"))
			session.send_all(id)
		else
			VehicleNetwork.refresh()
		end
	end))
	assert(realms.network_on_peer_left(mod, function (id)
		session.leave_peer(id, false)
	end))
end

return VehicleNetwork
