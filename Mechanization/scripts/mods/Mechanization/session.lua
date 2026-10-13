local mod = get_mod("Mechanization")
local Registry = mod.load_module("vehicles/registry")
local VehicleNetwork = mod.load_module("network/transport")
local Occupants = mod.load_module("players/occupants")
local Boarding = mod.load_module("players/boarding")
local Interaction = mod.load_module("players/interaction")
local Health = mod.load_module("vehicles/health")
local Dismount = mod.load_module("physics/dismount")
local PlayerMovement = require("scripts/utilities/player_movement")
local Airdrop = mod.load_module("players/airdrop")
local Messages = mod.load_module("network/messages")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local Platform = mod.load_module("players/platform")
local Interpolation = mod.load_module("network/interpolation")
local Session = {
	vehicles = {},
	clock = 0,
	network_elapsed = 0,
	registry = Registry,
	network = VehicleNetwork,
	occupants = Occupants,
	boarding = Boarding,
	interaction = Interaction,
	health = Health,
	dismount = Dismount,
}
local Contacts = mod.load_module("physics/contacts")
local NETWORK_INTERVAL = 0.05

local function snapshot (v)
	local position = v.position:unbox()
	local platforms = {}
	for index = 1, #v.type.seats do
		platforms[index] = v.occupants[index] and Platform.snapshot(v.occupants[index]) or false
	end
	return {
		time = Session.clock,
		type = v.type.id,
		p = { position.x, position.y, position.z },
		yaw = v.yaw,
		seats = Occupants.snapshot(v),
		platforms = platforms,
		health = v.health:current_health(),
		state = v.type.snapshot(v, Session.clock),
	}
end

Session.publish = function (v)
	VehicleNetwork.send("state", "others", v.peer, snapshot(v))
end

Session.spawn = function (peer, vehicle_type, position, yaw)
	local player = Occupants.find_player(peer)
	if not player or not player.player_unit or not ALIVE[player.player_unit] then
		return
	end
	local v = vehicle_type.controller.create(Managers.world:world("level_world"), position, yaw)
	v.type = vehicle_type
	v.peer = peer
	v.occupants = {}
	Health.attach(v, VehicleNetwork)
	Session.vehicles[peer] = v
	vehicle_type.controller.pose(v)
	return v
end

Session.activate = function (v)
	if v.type.controller.activate then
		v.type.controller.activate(v)
	end
end

Session.local_vehicle = function ()
	return Occupants.find_peer(Session.vehicles, VehicleNetwork.local_peer())
end

Session.for_unit = function (unit)
	return Occupants.for_unit(Session.vehicles, unit)
end

Session.protected = function (unit)
	local _, occupant = Session.for_unit(unit)
	return occupant and occupant.seat.protected
end

Session.personal_weapons = Occupants.personal_weapons

Session.remove = function (peer, dismount)
	local v = Session.vehicles[peer]
	if not v then
		return
	end
	local seated = {}
	for _, occupant in pairs(v.occupants) do
		if VehicleNetwork.is_host() or occupant.peer == VehicleNetwork.local_peer() then
			seated[#seated + 1] = occupant
		end
	end
	local positions, drops
	if dismount then
		positions, drops = Dismount.departure(v, seated, Session.vehicles, true)
	end
	Session.vehicles[peer] = nil
	for index, occupant in pairs(v.occupants) do
		local local_occupant = occupant.peer == VehicleNetwork.local_peer()
		local position = positions and positions[occupant.peer]
		Occupants.remove(v, index)
		if position and (VehicleNetwork.is_host() or local_occupant) then
			if drops[occupant.peer] then
				Airdrop.teleport(occupant.player, position, drops[occupant.peer])
			else
				PlayerMovement.teleport(occupant.player, Vector3(unpack(position)))
			end
		end
	end
	Health.detach(v)
	v.type.controller.destroy(v)
	ScriptUnit.remove_unit(v.unit)
end

Session.leave_peer = function (peer, dismount)
	local v, occupant = Occupants.find_peer(Session.vehicles, peer)
	if not v then
		return true
	end
	local removing = peer == v.peer
	local positions = {}
	local drops = {}
	if dismount then
		local departing = { occupant }
		if removing then
			departing = {}
			for _, seated in pairs(v.occupants) do
				departing[#departing + 1] = seated
			end
		end
		positions, drops = Dismount.departure(v, departing, Session.vehicles, removing)
		if not positions then
			if peer == VehicleNetwork.local_peer() then
				mod:echo(mod:localize("no_exit"))
			elseif VehicleNetwork.is_host() then
				VehicleNetwork.send("departure", peer, v.peer, false, false)
			end
			return false
		end
	end
	if removing then
		for _, seated in pairs(v.occupants) do
			positions[seated.peer] = positions[seated.peer] or false
		end
	else
		positions[peer] = positions[peer] or false
	end
	if VehicleNetwork.is_host() then
		VehicleNetwork.send("departure", "others", v.peer, positions, removing, drops)
	end
	Session.apply_departure(v.peer, positions, removing, drops)
	if VehicleNetwork.is_host() and not removing then
		Session.publish(v)
	end
	return true
end

Session.apply_departure = function (owner, positions, removing, drops)
	local v = Session.vehicles[owner]
	if removing then
		Session.remove(owner, false)
	elseif v then
		for index, occupant in pairs(v.occupants) do
			if positions[occupant.peer] ~= nil then
				Occupants.remove(v, index)
			end
		end
	end
	local local_peer = VehicleNetwork.local_peer()
	for peer, point in pairs(positions) do
		if peer == local_peer then
			Session.exiting = nil
		end
		if point and (VehicleNetwork.is_host() or peer == local_peer) then
			local player = Occupants.find_player(peer)
			if player and player.player_unit and ALIVE[player.player_unit] then
				if drops and drops[peer] then
					Airdrop.teleport(player, point, drops[peer])
				else
					PlayerMovement.teleport(player, Vector3(unpack(point)))
				end
			end
		end
	end
end

Session.eject = function (peer, dismount)
	if VehicleNetwork.is_host() then
		Session.leave_peer(peer, dismount)
	elseif peer == VehicleNetwork.local_peer() then
		if Session.exiting then
			return
		end
		local v = Session.local_vehicle()
		if not v then
			return
		end
		local departure = { owner = v.peer, released = not dismount }
		Session.exiting = departure
		VehicleNetwork.send("leave", "host", dismount)
		if not dismount and v then
			Session.apply_departure(v.peer, { [peer] = false }, peer == v.peer)
			Session.exiting = departure
		end
	end
end

Session.command = function (index, extra)
	if not index then
		local lines = { mod:localize("vehicle_list") }
		for number, vehicle_type in ipairs(Registry.list) do
			lines[#lines + 1] = string.format("%d. %s", number, mod:localize(vehicle_type.name))
		end
		lines[#lines + 1] = mod:localize("vehicle_create_hint")
		mod:echo("%s", table.concat(lines, "\n"))
		return
	end
	if Session.local_vehicle() or Session.exiting then
		mod:echo(mod:localize("already_boarded"))
		return
	end
	if VehicleNetwork.is_host() and not VehicleNetwork.enabled() then
		mod:echo(mod:localize("creation_disabled"))
		return
	end
	if not VehicleNetwork.available() then
		mod:echo(mod:localize("mission_required"))
		return
	end
	local number = tonumber(index)
	local vehicle_type = number and Registry.list[number]
	if extra or not vehicle_type then
		mod:echo(mod:localize("invalid_vehicle"))
		return
	end
	local player = Managers.player:local_player(1)
	if player and player.player_unit and not Occupants.can_use_seat(vehicle_type.seats[1], player) then
		mod:echo(mod:localize("ogryn_cannot_drive"))
		return
	end
	if VehicleNetwork.is_host() then
		Session.receive_select(VehicleNetwork.local_peer(), vehicle_type.id)
	elseif not VehicleNetwork.host_enabled then
		mod:echo(mod:localize("creation_disabled"))
		VehicleNetwork.refresh()
	else
		VehicleNetwork.send("select", "host", vehicle_type.id)
	end
end

Session.send_all = function (recipient)
	for peer, v in pairs(Session.vehicles) do
		VehicleNetwork.send("state", recipient, peer, snapshot(v))
	end
end

Session.cleanup = function (dismount)
	Session.exiting = nil
	Interaction.reset()
	Boarding.reset()
	if not dismount then
		table.clear(Airdrop.units)
	end
	for peer in pairs(Session.vehicles) do
		Session.remove(peer, dismount)
	end
end

Session.stop = function ()
	if VehicleNetwork.available() then
		if VehicleNetwork.is_host() then
			VehicleNetwork.publish("others", false)
		elseif Session.local_vehicle() then
			VehicleNetwork.send("leave", "host", true)
		end
	end
	Session.cleanup(true)
	VehicleNetwork.host_enabled = false
	Session.running = false
end

Session.settings_changed = function ()
	if not VehicleNetwork.available() or not VehicleNetwork.is_host() then
		return
	end
	VehicleNetwork.publish("others", mod:get("enabled"))
	if not mod:get("enabled") then
		Session.cleanup(true)
	end
end

local function read_local_input (v, occupant)
	local orientation = occupant.player:get_orientation()
	local input = Managers.input:get_input_service("Ingame")
	local blocked = Managers.ui:using_input()
	local axes = {}
	for axis, bindings in pairs(v.type.controls) do
		if blocked then
			axes[axis] = 0
		else
			local positive, negative = input:get(bindings[1]), input:get(bindings[2])
			positive = type(positive) == "boolean" and (positive and 1 or 0) or positive
			negative = type(negative) == "boolean" and (negative and 1 or 0) or negative
			axes[axis] = positive - negative
		end
	end
	local actions = {}
	for action, binding in pairs(v.type.actions) do
		actions[action] = not blocked and not not input:get(binding)
	end
	return {
		seat = occupant.index,
		platform = Platform.snapshot(occupant),
		axes = axes,
		yaw = orientation.yaw,
		pitch = (orientation.pitch + math.pi) % (math.pi * 2) - math.pi,
		actions = actions,
	}
end

local function emit_event (v, event)
	VehicleNetwork.send("event", "others", v.peer, event)
end

local function update_local (dt, transmit)
	local mine, occupant = Session.local_vehicle()
	local player = Managers.player:local_player(1)
	local blocked = Managers.ui:using_input() or Session.exiting ~= nil
	Boarding.vehicle = not mine and not blocked and VehicleNetwork.enabled() and Boarding.target(Session.vehicles, player) or nil
	local input_service = Managers.input:get_input_service("Ingame")
	local context = mine
	if Boarding.vehicle and Occupants.free_seat(Boarding.vehicle, player) then
		context = Boarding.vehicle
	end
	local gesture = Interaction.update(
		player and player.player_unit, context, input_service:get("interact_hold"), blocked, dt
	)
	if mine then
		if gesture == "hold" then
			Session.eject(occupant.peer, true)
			return
		end
		if gesture == "tap" and not occupant.seat.movement then
			if VehicleNetwork.is_host() then
				Session.receive_switch(occupant.peer)
			else
				VehicleNetwork.send("switch", "host")
			end
		end
		local input = read_local_input(mine, occupant)
		if VehicleNetwork.is_host() then
			Session.receive_input(occupant.peer, input)
		elseif transmit then
			VehicleNetwork.send("input", "host", input)
		end
	elseif Boarding.vehicle and gesture == "hold" then
		if VehicleNetwork.is_host() then
			Session.receive_board(VehicleNetwork.local_peer(), Boarding.vehicle.peer)
		else
			VehicleNetwork.send("board", "host", Boarding.vehicle.peer)
		end
	end
end

local function update_occupants (v)
	for _, occupant in pairs(v.occupants) do
		local character = ALIVE[occupant.unit] and ScriptUnit.extension(occupant.unit, "unit_data_system"):read_component("character_state")
		if not character or character.state_name == "dead" or PlayerUnitStatus.is_disabled(character) then
			Session.eject(occupant.peer, false)
		end
	end
end

Session.update = function (dt)
	Session.clock = Session.clock + dt
	if not VehicleNetwork.available() then
		Session.cleanup(false)
		Session.running = false
		return
	end
	if not Session.running then
		Session.running = true
		VehicleNetwork.refresh()
	end
	Session.network_elapsed = Session.network_elapsed + dt
	local transmit = Session.network_elapsed >= NETWORK_INTERVAL
	if transmit then
		Session.network_elapsed = 0
	end
	update_local(dt, transmit)
	Airdrop.update()
	for peer, v in pairs(Session.vehicles) do
		if VehicleNetwork.is_host() then
			Health.update(v)
		end
		if VehicleNetwork.is_host() and not v.health:is_alive() then
			Session.leave_peer(peer, true)
		else
			update_occupants(v)
		end
		if Session.vehicles[peer] then
			if VehicleNetwork.is_host() then
				v.input = Occupants.controls(v, Session.clock)
				local origin = v.position:unbox()
				local rotation = Unit.world_rotation(v.unit, 1)
				v.type.controller.step(v, v.input, math.min(dt, 0.1), Session.vehicles)
				v.type.controller.pose(v)
				Contacts.update(v, origin, rotation, Session.clock)
				if v.type.update then
					v.type.update(v, Session.clock, emit_event)
				end
				if transmit then
					Session.publish(v)
				end
			elseif v.stream then
				Interpolation.update(v, Session.clock)
			end
			Platform.update(v, dt)
			v.type.controller.animate(v, dt)
			v.type.controller.pose(v)
		end
	end
end

Session.install = function ()
	Airdrop.install()
	Health.install(Session)
	Messages.install(Session)
	Occupants.install(Session)
	VehicleNetwork.install(Session)
end

return Session
