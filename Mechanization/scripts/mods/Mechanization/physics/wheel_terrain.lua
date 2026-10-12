local WheelTerrain = {}
local MAX_HITS = 16
local CONTACT_GAP = 0.02
local PROBE_DEPTH = 3

WheelTerrain.rotation = function (yaw, normal)
	local forward = Quaternion.forward(Quaternion.from_yaw_pitch_roll(yaw, 0, 0))
	forward = Vector3.normalize(forward - normal * Vector3.dot(forward, normal))
	return Quaternion.look(forward, normal)
end

local function wheel_contact (vehicle, position, rotation, wheel)
	local settings = vehicle.type.settings
	local offset = Quaternion.rotate(rotation, Vector3(unpack(wheel.position)))
	local center = position + offset
	local lift = settings.max_step_height + settings.suspension_travel + settings.wheel_radius
	local start = center + Vector3.up() * lift
	local radius = settings.wheel_radius - CONTACT_GAP
	local hits = PhysicsWorld.linear_sphere_sweep(
		World.physics_world(vehicle.world), start, center - Vector3.up() * PROBE_DEPTH, radius, MAX_HITS,
		"types", "statics", "collision_filter", "filter_player_mover"
	)
	local nearest
	for _, hit in ipairs(hits or {}) do
		if not vehicle.parts[Actor.unit(hit.actor)] and hit.normal.z >= math.cos(settings.max_slope)
			and (not nearest or hit.distance < nearest.distance) then
			nearest = hit
		end
	end
	if nearest then
		return start.z - nearest.distance + CONTACT_GAP - offset.z
	end
end

WheelTerrain.contacts = function (vehicle, position, rotation)
	local heights = {}
	for index, wheel in ipairs(vehicle.type.settings.wheels) do
		heights[index] = wheel_contact(vehicle, position, rotation, wheel)
	end
	return heights
end

local function fitted_normal (heights, settings)
	local count, x, y, z, xx, yy, xy, xz, yz = 0, 0, 0, 0, 0, 0, 0, 0, 0
	for index, wheel in ipairs(settings.wheels) do
		local height = heights[index]
		if height then
			local sx, sy = wheel.position[1], wheel.position[2]
			count = count + 1
			x, y, z = x + sx, y + sy, z + height
			xx, yy, xy = xx + sx * sx, yy + sy * sy, xy + sx * sy
			xz, yz = xz + sx * height, yz + sy * height
		end
	end
	if count < 3 then
		return
	end
	local a, b, c = xx - x * x / count, xy - x * y / count, yy - y * y / count
	local d, e = xz - x * z / count, yz - y * z / count
	local determinant = a * c - b * b
	if determinant <= 0 then
		return
	end
	local right = (d * c - b * e) / determinant
	local forward = (a * e - b * d) / determinant
	local slope = math.sqrt(right * right + forward * forward)
	local limit = math.tan(settings.max_slope)
	if slope > limit then
		right, forward = right * limit / slope, forward * limit / slope
	end
	return Vector3.normalize(Vector3(-right, -forward, 1))
end

WheelTerrain.support = function (vehicle, position, yaw)
	local rotation = Quaternion.from_yaw_pitch_roll(yaw, 0, 0)
	local heights = WheelTerrain.contacts(vehicle, position, rotation)
	local normal = fitted_normal(heights, vehicle.type.settings)
	return normal and Quaternion.rotate(rotation, normal)
end

WheelTerrain.height = function (vehicle, position, rotation)
	local heights = WheelTerrain.contacts(vehicle, position, rotation)
	local total, highest, count = 0, -math.huge, 0
	for _, height in pairs(heights) do
		total = total + height
		highest = math.max(highest, height)
		count = count + 1
	end
	if count > 0 then
		-- Suspension absorbs differences between individual wheels without letting
		-- the highest contact pass through the tyre or underbody.
		return math.max(total / count, highest - vehicle.type.settings.suspension_travel), heights
	end
end

WheelTerrain.ground = function (world, position, settings)
	local hits = PhysicsWorld.raycast(
		World.physics_world(world), position + Vector3.up() * settings.max_step_height, Vector3.down(), PROBE_DEPTH,
		"all", "types", "statics", "collision_filter", "filter_player_mover"
	)
	local point
	for _, hit in ipairs(hits or {}) do
		if hit[3].z >= math.cos(settings.max_slope) and (not point or hit[1].z > point.z) then
			point = hit[1]
		end
	end
	return point
end

return WheelTerrain
