local PlayerMovement = require("scripts/utilities/player_movement")
local mod = get_mod("Mechanization")
local Seated = mod.load_module("players/seated_animation")
local Platform = mod.load_module("players/platform")
local Occupants = {}
local INPUT_TIMEOUT = 0.5

Occupants.find_player = function (peer)
	for _, player in pairs(Managers.player:players()) do
		if string.lower(tostring(player:peer_id())) == peer and player:is_human_controlled() then
			return player
		end
	end
end

Occupants.find_peer = function (vehicles, peer)
	for _, vehicle in pairs(vehicles) do
		for _, occupant in pairs(vehicle.occupants) do
			if occupant.peer == peer then
				return vehicle, occupant
			end
		end
	end
end

Occupants.for_unit = function (vehicles, unit)
	for _, vehicle in pairs(vehicles) do
		for _, occupant in pairs(vehicle.occupants) do
			if occupant.unit == unit then
				return vehicle, occupant
			end
		end
	end
end

Occupants.is_ogryn = function (player)
	return ScriptUnit.extension(player.player_unit, "unit_data_system"):breed().name == "ogryn"
end

Occupants.can_use_seat = function (seat, player)
	return not Occupants.is_ogryn(player) or seat.allow_ogryn == true
end

Occupants.free_seat = function (vehicle, player)
	for index = 2, #vehicle.type.seats do
		if not vehicle.occupants[index] and Occupants.can_use_seat(vehicle.type.seats[index], player) then
			return index
		end
	end
	return nil, Occupants.is_ogryn(player) and "hud_no_ogryn_space" or "hud_full"
end

Occupants.next_seat = function (vehicle, occupant)
	if occupant.seat.movement then
		return
	end
	local count = #vehicle.type.seats
	for offset = 1, count - 1 do
		local index = (occupant.index - 1 + offset) % count + 1
		local seat = vehicle.type.seats[index]
		local same_platform = seat.platform and seat.platform == occupant.seat.platform
		if index ~= 1 and not seat.movement and not same_platform and not vehicle.occupants[index] and Occupants.can_use_seat(seat, occupant.player) then
			return index
		end
	end
end

Occupants.switch = function (vehicle, occupant, index)
	assert(not vehicle.occupants[index], "Vehicle seat is occupied")
	assert(Occupants.can_use_seat(vehicle.type.seats[index], occupant.player), "Vehicle seat cannot accommodate this player")
	vehicle.occupants[occupant.index] = nil
	Seated.stop(occupant)
	occupant.index = index
	occupant.seat = assert(vehicle.type.seats[index], "Unknown vehicle seat")
	occupant.input.actions = {}
	occupant.platform = nil
	if occupant.seat.platform then
		Platform.start(vehicle, occupant)
	end
	Seated.start(occupant)
	vehicle.occupants[index] = occupant
end

Occupants.pose = function (vehicle, occupant)
	local body = Unit.world_rotation(vehicle.unit, 1)
	local seat = occupant.seat
	local offset = occupant.platform and occupant.platform.render:unbox() or Vector3(unpack(seat.position))
	local position = vehicle.position:unbox() + Quaternion.rotate(body, offset)
	if occupant.platform then
		local first_person = ScriptUnit.extension(occupant.unit, "unit_data_system"):read_component("first_person")
		return position, Quaternion.from_yaw_pitch_roll(Quaternion.yaw(first_person.rotation), 0, 0)
	end
	local rotation = Quaternion.multiply(body, Quaternion.from_yaw_pitch_roll(seat.yaw, 0, 0))
	return position, rotation
end

Occupants.personal_weapons = function (occupant)
	local seat = occupant.seat
	return not seat.protected and not seat.movement and #seat.actions == 0
end

Occupants.add = function (vehicle, index, peer, time)
	local player = Occupants.find_player(peer)
	if not player or not player.player_unit or not ALIVE[player.player_unit] then
		return
	end
	assert(not vehicle.occupants[index], "Vehicle seat is occupied")
	assert(Occupants.can_use_seat(vehicle.type.seats[index], player), "Vehicle seat cannot accommodate this player")
	local axes = {}
	for axis in pairs(vehicle.type.controls) do
		axes[axis] = 0
	end
	local occupant = {
		peer = peer,
		player = player,
		unit = player.player_unit,
		index = index,
		seat = assert(vehicle.type.seats[index], "Unknown vehicle seat"),
		input = { axes = axes, yaw = vehicle.yaw, pitch = 0, actions = {} },
		input_time = time,
	}
	if occupant.seat.platform then
		Platform.start(vehicle, occupant)
	end
	Seated.start(occupant)
	vehicle.occupants[index] = occupant
	return occupant
end

Occupants.remove = function (vehicle, index, position)
	local occupant = vehicle.occupants[index]
	if not occupant then
		return
	end
	vehicle.occupants[index] = nil
	Seated.stop(occupant)
	if position and ALIVE[occupant.unit] then
		PlayerMovement.teleport(occupant.player, Vector3(unpack(position)))
	end
end

Occupants.snapshot = function (vehicle)
	local seats = {}
	for index = 1, #vehicle.type.seats do
		local occupant = vehicle.occupants[index]
		seats[index] = occupant and occupant.peer or false
	end
	return seats
end

Occupants.receive = function (vehicle, peers, time, released_peer)
	assert(type(peers) == "table" and #peers == #vehicle.type.seats, "Invalid vehicle seats")
	local seen = {}
	for index, peer in ipairs(peers) do
		assert(peer == false or type(peer) == "string", "Invalid vehicle occupant")
		assert(peer == false or not seen[peer], "Duplicate vehicle occupant")
		if peer then
			seen[peer] = true
		end
	end
	-- Release all old seats before applying the snapshot, including seat changes.
	for index, occupant in pairs(vehicle.occupants) do
		if peers[index] ~= occupant.peer then
			Occupants.remove(vehicle, index)
		end
	end
	for index, peer in ipairs(peers) do
		if peer and peer ~= released_peer and not vehicle.occupants[index] then
			Occupants.add(vehicle, index, peer, time)
		end
	end
end

local function current_input (occupant, time)
	local input = occupant.input
	if time - occupant.input_time > INPUT_TIMEOUT then
		for axis in pairs(input.axes) do
			input.axes[axis] = 0
		end
		input.actions = {}
	end
	return input
end

Occupants.action_owner = function (vehicle, action)
	for index = #vehicle.type.seats, 1, -1 do
		local occupant = vehicle.occupants[index]
		if occupant then
			for _, assigned in ipairs(occupant.seat.actions) do
				if assigned == action then
					return occupant
				end
			end
		end
	end
end

Occupants.controls = function (vehicle, time)
	local controls = { axes = {}, actions = {}, yaw = vehicle.yaw, pitch = 0 }
	for axis in pairs(vehicle.type.controls) do
		controls.axes[axis] = 0
	end
	for index = 1, #vehicle.type.seats do
		local occupant = vehicle.occupants[index]
		if occupant then
			local input = current_input(occupant, time)
			if occupant.seat.movement then
				for axis, value in pairs(input.axes) do
					controls.axes[axis] = value
				end
				controls.yaw, controls.pitch = input.yaw, input.pitch
			end
		end
	end
	for action in pairs(vehicle.type.actions) do
		local owner = Occupants.action_owner(vehicle, action)
		if owner then
			local input = current_input(owner, time)
			controls.actions[action] = {
				yaw = input.yaw,
				pitch = input.pitch,
				pressed = input.actions[action] == true,
				unit = owner.unit,
			}
		end
	end
	return controls
end

Occupants.install = Seated.install

return Occupants
