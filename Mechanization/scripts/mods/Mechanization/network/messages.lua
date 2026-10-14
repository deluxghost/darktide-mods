local mod = get_mod("Mechanization")
local PlayerUnitStatus = require("scripts/utilities/attack/player_unit_status")
local PlayerMovement = require("scripts/utilities/player_movement")
local Collision = mod.load_module("physics/collision")
local Platform = mod.load_module("players/platform")
local Interpolation = mod.load_module("network/interpolation")
local Configuration = mod.load_module("configuration")
local Messages = {}

Messages.install = function (session)
	local VehicleNetwork = session.network
	local Registry = session.registry
	local Occupants = session.occupants
	local Boarding = session.boarding

	local function finite (value)
		return type(value) == "number" and value == value and math.abs(value) < math.huge
	end

	local function available_player (peer)
		local player = Occupants.find_player(peer)
		local unit = player and player.player_unit
		if not unit or not ALIVE[unit] then
			return
		end
		local character = ScriptUnit.extension(unit, "unit_data_system"):read_component("character_state")
		if PlayerUnitStatus.is_disabled(character) or character.state_name == "dead" then
			return
		end
		return player
	end

	local function prepare_spawn (v, creator)
		local ignored_units = { [creator.player_unit] = true }
		local bots = {}
		for _, player in pairs(Managers.player:bot_players()) do
			local unit = player.player_unit
			if unit and ALIVE[unit] then
				ignored_units[unit] = true
				bots[#bots + 1] = { player = player, unit = unit }
			end
		end
		if not v.type.controller.can_spawn(v, session.vehicles, ignored_units) then
			return false
		end
		v.type.controller.pose(v)
		local overlapping = {}
		for _, bot in ipairs(bots) do
			local radius, height = Collision.character_size(bot.unit)
			if not Collision.outside(v, Unit.world_position(bot.unit, 1), radius, height) then
				overlapping[#overlapping + 1] = bot
			end
		end
		local positions = session.dismount.departure(v, overlapping, session.vehicles, false)
		if not positions then
			return false
		end
		for _, bot in ipairs(overlapping) do
			PlayerMovement.teleport(bot.player, Vector3(unpack(positions[bot.unit])))
		end
		return true
	end

	session.receive_departure = function (sender, owner, positions, removing, drops)
		if not VehicleNetwork.from_host(sender) then
			return
		end
		assert(type(owner) == "string" and type(removing) == "boolean", "Invalid vehicle departure")
		if positions == false then
			session.exiting = nil
			mod:echo(mod:localize("no_exit"))
			return
		end
		assert(type(positions) == "table", "Invalid departure positions")
		assert(type(drops) == "table", "Invalid departure descents")
		for peer, speed in pairs(drops) do
			assert(positions[peer] and finite(speed) and speed > 0 and speed <= 20, "Invalid departure descent")
		end
		for peer, point in pairs(positions) do
			assert(type(peer) == "string", "Invalid departing peer")
			if point ~= false then
				assert(type(point) == "table" and #point == 3, "Invalid departure position")
				for index = 1, 3 do
					assert(finite(point[index]), "Invalid departure coordinate")
				end
			end
		end
		session.apply_departure(owner, positions, removing, drops)
	end

	session.receive_leave = function (peer, dismount)
		if VehicleNetwork.is_host() then
			assert(type(dismount) == "boolean", "Invalid vehicle departure")
			session.leave_peer(peer, dismount)
		end
	end

	session.receive_select = function (peer, type_id)
		if not VehicleNetwork.available() or not VehicleNetwork.is_host() or not VehicleNetwork.enabled() then
			return
		end
		if Occupants.find_peer(session.vehicles, peer) then
			return
		end
		local vehicle_type = assert(Registry.by_id[type_id], "Unknown vehicle type")
		local player = available_player(peer)
		if not player then
			return
		end
		if not Occupants.can_use_seat(vehicle_type.seats[1], player) then
			VehicleNetwork.notice(peer, "ogryn_cannot_drive")
			return
		end
		local character = ScriptUnit.extension(player.player_unit, "unit_data_system"):read_component("character_state")
		if character.state_name ~= "walking" then
			VehicleNetwork.notice(peer, "not_walking")
			return
		end
		local position = Unit.world_position(player.player_unit, 1)
		local yaw = Quaternion.yaw(Unit.world_rotation(player.player_unit, 1))
		local point = vehicle_type.controller.spawn_position(Managers.world:world("level_world"), position, yaw)
		if not point then
			VehicleNetwork.notice(peer, "no_ground")
			return
		end
		local v = session.spawn(peer, vehicle_type, point, yaw)
		if v then
			if not prepare_spawn(v, player) then
				session.remove(peer, false)
				VehicleNetwork.notice(peer, "no_space")
				return
			end
			session.activate(v)
			Occupants.add(v, 1, peer, session.clock)
			session.publish(v)
			return v
		end
	end

	session.receive_command = function (peer, type_id)
		if not VehicleNetwork.is_host() then
			return
		end
		local player = available_player(peer)
		if not player then
			return
		end
		local account = player:account_id()
		local departed = session.last_departures[account]
		local remaining = departed and departed + Configuration.cooldown() - session.clock or 0
		if remaining > 0 then
			VehicleNetwork.notice(peer, "spawn_wait", math.ceil(remaining))
			return
		end
		local v = session.receive_select(peer, type_id)
		if v then
			v.command_account = account
		end
		return v
	end

	session.receive_board = function (peer, owner)
		if not VehicleNetwork.enabled() or not VehicleNetwork.available() or not VehicleNetwork.is_host() then
			return
		end
		assert(type(owner) == "string", "Invalid vehicle owner")
		local v = session.vehicles[owner]
		local player = available_player(peer)
		if not v or not player or Occupants.find_peer(session.vehicles, peer) then
			return
		end
		if Boarding.target(session.vehicles, player) ~= v then
			return
		end
		local index = Occupants.free_seat(v, player)
		if index then
			Occupants.add(v, index, peer, session.clock)
			session.publish(v)
		end
	end

	session.receive_switch = function (peer)
		if not VehicleNetwork.available() or not VehicleNetwork.is_host() or not VehicleNetwork.enabled() then
			return
		end
		local v, occupant = Occupants.find_peer(session.vehicles, peer)
		if not occupant or not available_player(peer) then
			return
		end
		local index = Occupants.next_seat(v, occupant)
		if index then
			Occupants.switch(v, occupant, index)
			session.publish(v)
		end
	end

	session.receive_input = function (peer, input)
		if not VehicleNetwork.is_host() then
			return
		end
		assert(type(input) == "table" and type(input.axes) == "table", "Invalid vehicle controls")
		assert(finite(input.yaw) and finite(input.pitch) and math.abs(input.pitch) <= math.pi, "Invalid vehicle aim")
		assert(type(input.actions) == "table", "Invalid vehicle actions")
		local v, occupant = Occupants.find_peer(session.vehicles, peer)
		if occupant then
			assert(type(input.seat) == "number" and input.seat % 1 == 0, "Invalid input seat")
			if input.seat ~= occupant.index then
				return
			end
			for axis in pairs(input.axes) do
				assert(v.type.controls[axis], "Unknown vehicle control axis")
			end
			for axis in pairs(v.type.controls) do
				assert(finite(input.axes[axis]) and math.abs(input.axes[axis]) <= 1, "Invalid vehicle control axis: " .. axis)
			end
			for action, pressed in pairs(input.actions) do
				assert(v.type.actions[action] and type(pressed) == "boolean", "Invalid vehicle action")
			end
			occupant.input = input
			occupant.input_time = session.clock
			if occupant.platform then
				Platform.receive_input(v, occupant, input.platform, finite)
			end
		end
	end

	session.receive_state = function (sender, owner, data)
		if not VehicleNetwork.available() or not VehicleNetwork.enabled() or not VehicleNetwork.from_host(sender) then
			return
		end
		assert(type(owner) == "string", "Invalid vehicle owner")
		assert(type(data) == "table" and type(data.p) == "table" and #data.p == 3 and finite(data.yaw), "Invalid vehicle state")
		assert(finite(data.time), "Invalid vehicle snapshot time")
		local vehicle_type = assert(Registry.by_id[data.type], "Unknown vehicle type")
		Configuration.validate(data.type, data.config)
		assert(finite(data.health) and data.health >= 0 and data.health <= data.config.health, "Invalid vehicle health")
		for index = 1, 3 do
			assert(finite(data.p[index]), "Invalid vehicle vector")
		end
		vehicle_type.validate_state(data.state, finite)
		local peers = data.seats
		assert(type(peers) == "table" and peers[1] == owner, "Missing vehicle owner seat")
		assert(type(data.platforms) == "table" and #data.platforms == #vehicle_type.seats, "Invalid platform snapshot")
		for index, state in ipairs(data.platforms) do
			if state then
				assert(vehicle_type.seats[index].platform and state.peer == peers[index], "Invalid platform occupant")
				assert(type(state.p) == "table" and #state.p == 3 and type(state.v) == "table" and #state.v == 3, "Invalid platform state")
				for axis = 1, 3 do
					assert(finite(state.p[axis]) and finite(state.v[axis]), "Invalid platform vector")
				end
			end
		end
		local departure = session.exiting
		local released = departure and departure.owner == owner and departure.released
		if released and owner == VehicleNetwork.local_peer() then
			return
		end
		local v = session.vehicles[owner]
		assert(not v or v.type == vehicle_type, "Vehicle type changed without departure")
		if v then
			for key, value in pairs(v.config) do
				assert(data.config[key] == value, "Vehicle configuration changed without departure")
			end
		end
		if not v then
			v = session.spawn(owner, vehicle_type, Vector3(unpack(data.p)), data.yaw, data.config)
			if v then
				session.activate(v)
			end
		end
		if v then
			Interpolation.receive(v, data, session.clock)
			v.health.remaining = data.health
			if v.type.receive_state then
				v.type.receive_state(v, data.state, session.clock)
			end
			Occupants.receive(v, peers, session.clock, released and VehicleNetwork.local_peer())
		end
	end

	session.receive_event = function (sender, owner, event)
		if not VehicleNetwork.available() or not VehicleNetwork.from_host(sender) then
			return
		end
		assert(type(owner) == "string", "Invalid vehicle owner")
		local v = session.vehicles[owner]
		if v then
			assert(v.type.receive_event, "Vehicle type has no events")
			v.type.receive_event(v, event, finite)
		end
	end
end

return Messages
