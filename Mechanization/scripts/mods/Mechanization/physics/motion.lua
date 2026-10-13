local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Motion = {}
local MAX_HITS = 64
local MAX_SLIDES = 3
local CONTACT_GAP = 0.02
local MIN_MOVE_SQUARED = 0.0000000001
local DEPTH_STEPS = 16
local DEPTH_EPSILON = 0.0001

local function obstacle (vehicle, actor)
	local unit = Actor.unit(actor)
	if Collision.contains_unit(vehicle, unit) then
		return false
	end
	local data = ScriptUnit.has_extension(unit, "unit_data_system")
	local breed = data and data:breed()
	return not breed or breed.breed_type ~= "player" and breed.breed_type ~= "minion" and breed.breed_type ~= "companion"
end

local function shape_bounds (shape, tolerance, vertical_tolerance, step_height, rotation)
	local center = Vector3(unpack(shape.center))
	local half = Vector3(unpack(shape.half)) - Vector3(tolerance, tolerance, vertical_tolerance)
	if half.x <= 0 or half.y <= 0 or half.z <= 0 then
		return
	end
	if step_height then
		-- Ground support handles low obstacles; the hull sweep must not treat them as walls.
		local right, forward, up = Quaternion.right(rotation), Quaternion.forward(rotation), Quaternion.up(rotation)
		local lateral_height = center.x * right.z + center.y * forward.z
		local lateral_radius = half.x * math.abs(right.z) + half.y * math.abs(forward.z)
		local floor = (step_height - lateral_height + lateral_radius) / up.z
		local bottom = math.max(center.z - half.z, floor)
		local top = center.z + half.z
		if bottom >= top then
			return
		end
		center.z, half.z = (bottom + top) * 0.5, (top - bottom) * 0.5
	end
	return center, half
end

local function overlaps (vehicle, position, rotation, filter, step_height, erosion)
	local actors, seen = {}, {}
	local settings = vehicle.type.settings
	for _, shape in ipairs(settings.collision_shapes) do
		local center, half = shape_bounds(
			shape,
			settings.terrain_contact_tolerance + erosion,
			settings.vertical_contact_tolerance + erosion,
			step_height,
			rotation
		)
		if center then
			local hits = PhysicsWorld.immediate_overlap(
				World.physics_world(vehicle.world), "shape", "oobb", "position", position + Quaternion.rotate(rotation, center),
				"rotation", rotation, "size", half, "types", "both", "collision_filter", filter
			)
			for _, actor in ipairs(hits) do
				if not seen[actor] then
					seen[actor] = true
					actors[#actors + 1] = actor
				end
			end
		end
	end
	return actors
end

Motion.overlap = function (vehicle, position, rotation, filter, step_height)
	return overlaps(vehicle, position, rotation, filter, step_height, 0)
end

local function contact_depth (vehicle, position, rotation, actor)
	local low, high = 0, 0
	for _, shape in ipairs(vehicle.type.settings.collision_shapes) do
		high = math.max(high, math.min(unpack(shape.half)))
	end
	for _ = 1, DEPTH_STEPS do
		local middle = (low + high) * 0.5
		local touching = false
		local clearance = vehicle.type.settings.hull_clearance or vehicle.type.settings.suspension_travel
		for _, hit in ipairs(overlaps(vehicle, position, rotation, "filter_player_mover", clearance, middle)) do
			if hit == actor then
				touching = true
				break
			end
		end
		if touching then
			low = middle
		else
			high = middle
		end
	end
	return high
end

local function escaping_contacts (vehicle, origin, rotation, destination, target_rotation)
	local existing, before, after = {}, 0, 0
	local step_height = vehicle.type.settings.hull_clearance or vehicle.type.settings.suspension_travel
	for _, actor in ipairs(Motion.overlap(vehicle, origin, rotation, "filter_player_mover", step_height)) do
		if obstacle(vehicle, actor) then
			local depth = contact_depth(vehicle, origin, rotation, actor)
			existing[actor] = depth
			before = before + depth
		end
	end
	if before == 0 then
		return
	end
	for _, actor in ipairs(Motion.overlap(vehicle, destination, target_rotation, "filter_player_mover", step_height)) do
		if obstacle(vehicle, actor) then
			if not existing[actor] then
				return
			end
			local depth = contact_depth(vehicle, destination, target_rotation, actor)
			if depth > existing[actor] + DEPTH_EPSILON then
				return
			end
			after = after + depth
		end
	end
	-- Existing penetration may only decrease; an occupied hull must still be able to retreat.
	return after < before - DEPTH_EPSILON and existing or nil
end

local function sweep (vehicle, origin, destination, rotation)
	local settings = vehicle.type.settings
	local results = {}
	local step_height = settings.hull_clearance or settings.suspension_travel
	for _, shape in ipairs(settings.collision_shapes) do
		local center, half = shape_bounds(
			shape, settings.terrain_contact_tolerance, settings.vertical_contact_tolerance, step_height, rotation
		)
		if center then
			local offset = Quaternion.rotate(rotation, center)
			local hits = PhysicsWorld.linear_obb_sweep(
				World.physics_world(vehicle.world), origin + offset, destination + offset, half, rotation, MAX_HITS,
				"collision_filter", "filter_player_mover"
			)
			for _, hit in ipairs(hits or {}) do
				results[#results + 1] = hit
			end
		end
	end
	local sweep_support = vehicle.type.controller.sweep_support
	if sweep_support then
		for _, hit in ipairs(sweep_support(vehicle, origin, destination, rotation)) do
			results[#results + 1] = hit
		end
	end
	return results
end

local function blocker (vehicle, origin, destination, rotation)
	local travel = destination - origin
	local length = Vector3.length(travel)
	if length == 0 then
		return 1
	end
	local fraction, normal = 1, nil
	local escaping, checked_escape
	local lateral = Vector3.length_squared(Vector3.flat(travel)) > MIN_MOVE_SQUARED
	for _, hit in ipairs(sweep(vehicle, origin, destination, rotation) or {}) do
		if obstacle(vehicle, hit.actor) and Vector3.dot(travel, hit.normal) < -0.00001 then
			if hit.distance <= CONTACT_GAP and not checked_escape then
				escaping = escaping_contacts(vehicle, origin, rotation, destination, rotation)
				checked_escape = true
			end
			local allowed = math.max(0, (hit.distance - CONTACT_GAP) / length)
			if allowed < fraction and not (escaping and escaping[hit.actor]) then
				fraction, normal = allowed, hit.normal
				local supports_contact = vehicle.type.controller.supports_contact
				local ground = hit.support or supports_contact and supports_contact(vehicle, normal)
				if supports_contact and not ground and lateral and travel.z == 0 and Vector3.length_squared(Vector3.flat(normal)) > 0.000001 then
					-- Horizontal travel slides along walls; suspension lift is solved separately.
					normal = Vector3.normalize(Vector3.flat(normal))
				end
			end
		end
	end
	return fraction, normal
end

local function slide (vehicle, position, destination, rotation, vehicles)
	local remaining = destination - position
	local contact_normal
	for _ = 1, MAX_SLIDES do
		if Vector3.length_squared(remaining) < MIN_MOVE_SQUARED then
			break
		end
		local fraction, normal = blocker(vehicle, position, position + remaining, rotation)
		contact_normal = normal or contact_normal
		local candidate = position + remaining * fraction
		if not Collision.clear_vehicles(vehicle, candidate, rotation, vehicles) then
			local low, high = 0, fraction
			for _ = 1, 8 do
				local middle = (low + high) * 0.5
				if Collision.clear_vehicles(vehicle, position + remaining * middle, rotation, vehicles) then
					low = middle
				else
					high = middle
				end
			end
			return position + remaining * low, contact_normal
		end
		position = candidate
		if not normal then
			break
		end
		remaining = remaining * (1 - fraction)
		remaining = remaining - normal * math.min(0, Vector3.dot(remaining, normal))
	end
	return position, contact_normal
end

Motion.translate = function (vehicle, destination, rotation, vehicles)
	return slide(vehicle, vehicle.position:unbox(), destination, rotation, vehicles)
end

Motion.vertical = function (vehicle, position, height, rotation, vehicles)
	local destination = Vector3(position.x, position.y, height)
	local fraction = blocker(vehicle, position, destination, rotation)
	local candidate = Vector3.lerp(position, destination, fraction)
	if Collision.clear_vehicles(vehicle, candidate, rotation, vehicles) then
		return candidate
	end
	return position
end

Motion.rotation_clear = function (vehicle, previous, rotation, vehicles)
	local origin = vehicle.position:unbox()
	if not Collision.clear_vehicles(vehicle, origin, rotation, vehicles) then
		return false
	end
	local clearance = vehicle.type.settings.hull_clearance or vehicle.type.settings.suspension_travel
	for _, actor in ipairs(Motion.overlap(vehicle, origin, rotation, "filter_player_mover", clearance)) do
		if obstacle(vehicle, actor) then
			return escaping_contacts(vehicle, origin, previous, origin, rotation) ~= nil
		end
	end
	return true
end

local function clear_rotation_position (vehicle, position, rotation, vehicles)
	if not Collision.clear_vehicles(vehicle, position, rotation, vehicles) then
		return false
	end
	for _, actor in ipairs(Motion.overlap(vehicle, position, rotation, "filter_player_mover")) do
		if obstacle(vehicle, actor) then
			return false
		end
	end
	return true
end

Motion.rotation_position = function (vehicle, previous, rotation, vehicles)
	local origin = vehicle.position:unbox()
	if Motion.rotation_clear(vehicle, previous, rotation, vehicles) then
		return origin
	end
	local radius = 0
	for _, shape in ipairs(vehicle.type.settings.collision_shapes) do
		radius = math.max(radius, Vector3.length(Vector3(unpack(shape.center))) + Vector3.length(Vector3(unpack(shape.half))))
	end
	local angle = Quaternion.angle(previous, rotation)
	local limit = radius * angle + CONTACT_GAP
	-- Rotation may displace the hull by its swept arc, but cannot push it through a wall.
	local directions = { Vector3.up(), Vector3.down(), Vector3.right(), -Vector3.right(), Vector3.forward(), -Vector3.forward() }
	local distance = math.min(CONTACT_GAP, limit)
	while distance <= limit do
		for _, direction in ipairs(directions) do
			local candidate = origin + direction * distance
			if clear_rotation_position(vehicle, candidate, rotation, vehicles) then
				local low, high = 0, distance
				for _ = 1, 8 do
					local middle = (low + high) * 0.5
					if clear_rotation_position(vehicle, origin + direction * middle, rotation, vehicles) then
						high = middle
					else
						low = middle
					end
				end
				candidate = origin + direction * high
				local reachable = Motion.translate(vehicle, candidate, previous, vehicles)
				if Vector3.distance(reachable, candidate) <= DEPTH_EPSILON then
					return candidate
				end
			end
		end
		if distance == limit then
			break
		end
		distance = math.min(distance * 2, limit)
	end
end

return Motion
