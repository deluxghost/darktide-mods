local Collision = {}
local CONTACT_GAP = 0.03

Collision.contains_unit = function (vehicle, unit)
	return vehicle.parts[unit] == true
end

Collision.player_footprint = function (unit)
	local mover = Unit.mover(unit)
	if mover then
		return Mover.radius(mover)
	end
	-- Remote characters and minions have no player mover.
	return ScriptUnit.extension(unit, "unit_data_system"):breed().broadphase_radius
end

Collision.character_size = function (unit)
	local breed = ScriptUnit.extension(unit, "unit_data_system"):breed()
	local first = ScriptUnit.has_extension(unit, "first_person_system")
	local radius = Collision.player_footprint(unit)
	local height = first and first:extrapolated_character_height() + radius or breed.base_height
	return radius, height
end

Collision.closest_point = function (vehicle, position)
	local center, half = vehicle.type.controller.bounds(vehicle)
	local rotation = Unit.world_rotation(vehicle.unit, 1)
	local local_position = Quaternion.rotate(Quaternion.inverse(rotation), position - vehicle.position:unbox()) - center
	local point = Vector3(
		math.clamp(local_position.x, -half.x, half.x),
		math.clamp(local_position.y, -half.y, half.y),
		math.clamp(local_position.z, -half.z, half.z)
	)
	return vehicle.position:unbox() + Quaternion.rotate(rotation, center + point)
end

Collision.local_position = function (vehicle, position)
	local rotation = Unit.world_rotation(vehicle.unit, 1)
	return Quaternion.rotate(Quaternion.inverse(rotation), position - vehicle.position:unbox())
end

Collision.outside = function (vehicle, position, radius, height)
	local center, half = vehicle.type.controller.bounds(vehicle)
	local point = Collision.local_position(vehicle, position) - center
	return math.abs(point.x) > half.x + radius or math.abs(point.y) > half.y + radius
		or point.z >= half.z or point.z + height <= -half.z
end

Collision.contains_player = function (vehicle, unit)
	for _, occupant in pairs(vehicle.occupants) do
		if occupant.unit == unit then
			return true
		end
	end
	return false
end

Collision.clear_players = function (vehicle, position, rotation, ignored_units)
	local center, half = vehicle.type.controller.bounds(vehicle)
	for _, player in pairs(Managers.player:players()) do
		local unit = player.player_unit
		if unit and not (ignored_units and ignored_units[unit]) and ALIVE[unit] and not Collision.contains_player(vehicle, unit) then
			local radius = Collision.player_footprint(unit)
			local first = ScriptUnit.extension(unit, "first_person_system")
			local height = first:default_height("default") + radius
			local point = Quaternion.rotate(Quaternion.inverse(rotation), Unit.world_position(unit, 1) - position) - center
			local horizontal_overlap = math.abs(point.x) < half.x + radius and math.abs(point.y) < half.y + radius
			if horizontal_overlap and point.z < half.z and point.z + height > -half.z then
				return false
			end
		end
	end
	return true
end

local function box (vehicle, position, rotation)
	local center, half = vehicle.type.controller.bounds(vehicle)
	return {
		center = position + Quaternion.rotate(rotation, center),
		half = { half.x, half.y, half.z },
		axes = { Quaternion.right(rotation), Quaternion.forward(rotation), Quaternion.up(rotation) },
	}
end

local function separated_boxes (first, second, axis)
	if Vector3.length_squared(axis) < 0.000001 then
		return false
	end
	local radius = 0
	for index = 1, 3 do
		radius = radius + first.half[index] * math.abs(Vector3.dot(first.axes[index], axis))
		radius = radius + second.half[index] * math.abs(Vector3.dot(second.axes[index], axis))
	end
	return math.abs(Vector3.dot(second.center - first.center, axis)) >= radius
end

local function boxes_overlap (first, second)
	for index = 1, 3 do
		if separated_boxes(first, second, first.axes[index]) or separated_boxes(first, second, second.axes[index]) then
			return false
		end
		for other = 1, 3 do
			if separated_boxes(first, second, Vector3.cross(first.axes[index], second.axes[other])) then
				return false
			end
		end
	end
	return true
end

Collision.clear_vehicles = function (vehicle, position, rotation, vehicles)
	local candidate = box(vehicle, position, rotation)
	for _, other in pairs(vehicles) do
		if other ~= vehicle then
			local bounds = box(other, other.position:unbox(), Unit.world_rotation(other.unit, 1))
			if boxes_overlap(candidate, bounds) then
				return false
			end
		end
	end
	return true
end

Collision.push = function (vehicles, unit, position, dt, ignored_vehicle)
	local radius, height = Collision.character_size(unit)
	for _, vehicle in pairs(vehicles) do
		if vehicle ~= ignored_vehicle and not Collision.contains_player(vehicle, unit) then
			local center, half = vehicle.type.controller.bounds(vehicle)
			local point = Collision.local_position(vehicle, position) - center
			local overlap_x = half.x + radius - math.abs(point.x)
			local overlap_y = half.y + radius - math.abs(point.y)
			if overlap_x > 0 and overlap_y > 0 and point.z < half.z and point.z + height > -half.z then
				local local_push = overlap_x < overlap_y and Vector3(point.x >= 0 and overlap_x or -overlap_x, 0, 0)
					or Vector3(0, point.y >= 0 and overlap_y or -overlap_y, 0)
				local displacement = Vector3.flat(Quaternion.rotate(Unit.world_rotation(vehicle.unit, 1), local_push))
				local mover = Unit.mover(unit)
				if mover then
					Mover.move(mover, displacement, dt)
					position = Mover.position(mover)
				else
					position = position + Vector3.flat(displacement)
				end
			end
		end
	end
	return position
end

local function intersection (start, finish, lower, upper)
	-- Control effects can release a seated player inside the hull. Allow escape
	-- from this initial overlap; subsequent movement from outside still collides.
	if start.x > lower.x and start.x < upper.x and start.y > lower.y and start.y < upper.y and start.z > lower.z and start.z < upper.z then
		return
	end
	local entry, leave = -math.huge, 1
	local normal
	local direction = finish - start
	for _, axis in ipairs({ "x", "y", "z" }) do
		local delta = direction[axis]
		if math.abs(delta) < 0.00001 then
			if start[axis] <= lower[axis] or start[axis] >= upper[axis] then
				return
			end
		else
			local first = (lower[axis] - start[axis]) / delta
			local last = (upper[axis] - start[axis]) / delta
			local near = math.min(first, last)
			if near > entry then
				entry = near
				normal = Vector3.zero()
				normal[axis] = delta > 0 and -1 or 1
			end
			leave = math.min(leave, math.max(first, last))
			if entry > leave then
				return
			end
		end
	end
	if entry >= 0 and entry < 1 and leave > entry then
		return entry, normal
	end
end

Collision.move = function (vehicles, unit, from, destination, ignored_vehicle)
	if not next(vehicles) then
		return destination
	end
	local radius, height = Collision.character_size(unit)
	local result = destination
	for _, vehicle in pairs(vehicles) do
		if vehicle ~= ignored_vehicle then
			local center, half = vehicle.type.controller.bounds(vehicle)
			local start = Collision.local_position(vehicle, from)
			local finish = Collision.local_position(vehicle, result)
			local lower = center - half - Vector3(radius, radius, height)
			local upper = center + half + Vector3(radius, radius, 0)
			local fraction, normal = intersection(start, finish, lower, upper)
			if fraction then
				local contact = Vector3.lerp(start, finish, fraction)
				local remaining = finish - contact
				local slide = remaining - normal * Vector3.dot(remaining, normal)
				local point = contact + normal * CONTACT_GAP + slide
				result = vehicle.position:unbox() + Quaternion.rotate(Unit.world_rotation(vehicle.unit, 1), point)
			end
		end
	end
	return result
end

return Collision
