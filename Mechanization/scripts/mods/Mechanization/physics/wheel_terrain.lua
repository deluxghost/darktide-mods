local mod = get_mod("Mechanization")
local Surfaces = mod.load_module("physics/surfaces")
local WheelTerrain = {}
local MAX_HITS = 16
local TREAD_SEGMENTS = 8
local CONTACT_GAP = 0.01
local PROBE_DEPTH = 8
local MIN_SUPPORTS = 2

WheelTerrain.rotation = function (yaw, normal)
	local forward = Quaternion.forward(Quaternion.from_yaw_pitch_roll(yaw, 0, 0))
	forward = Vector3.normalize(forward - normal * Vector3.dot(forward, normal))
	return Quaternion.look(forward, normal)
end

local function wheel_contact (vehicle, position, rotation, wheel)
	local settings = vehicle.type.settings
	local turn = Quaternion.from_yaw_pitch_roll(wheel.front and vehicle.steering or 0, 0, 0)
	local orientation = Quaternion.multiply(rotation, turn)
	local center = position + Quaternion.rotate(rotation, Vector3(unpack(wheel.position)))
	local lift = settings.max_step_height + settings.suspension_travel + settings.wheel_radius
	local max_ground = center.z - settings.wheel_radius + settings.max_step_height + settings.suspension_travel
	local nearest, normal, actor
	-- Narrow strips follow the lower tyre arc without the oversized axle of a sphere.
	for index = 1, TREAD_SEGMENTS do
		local first_angle = (index - 1) * math.pi / TREAD_SEGMENTS - math.pi * 0.5
		local last_angle = index * math.pi / TREAD_SEGMENTS - math.pi * 0.5
		local first = Vector3(0, math.sin(first_angle), -math.cos(first_angle)) * settings.wheel_radius
		local last = Vector3(0, math.sin(last_angle), -math.cos(last_angle)) * settings.wheel_radius
		local tangent = Vector3.normalize(last - first)
		local local_rotation = Quaternion.look(tangent, Vector3.cross(Vector3.right(), tangent))
		local offset = Quaternion.rotate(orientation, (first + last) * 0.5)
		local hits = PhysicsWorld.linear_obb_sweep(
			World.physics_world(vehicle.world), center + offset + Vector3.up() * lift, center + offset - Vector3.up() * PROBE_DEPTH,
			Vector3(settings.wheel_width * 0.45, Vector3.distance(first, last) * 0.5, CONTACT_GAP),
			Quaternion.multiply(orientation, local_rotation), MAX_HITS, "collision_filter", "filter_player_mover"
		)
		for _, hit in ipairs(hits or {}) do
			if Surfaces.is_ground(hit.actor) and not vehicle.parts[Actor.unit(hit.actor)] and hit.normal.z >= math.cos(settings.max_slope) and hit.position.z <= max_ground
				and (not nearest or hit.distance < nearest) then
				nearest = hit.distance
				normal = hit.normal
				actor = hit.actor
			end
		end
	end
	return nearest and position.z + lift - nearest, normal, actor
end

WheelTerrain.contacts = function (vehicle, position, rotation)
	local heights, normals, count = {}, Vector3.zero(), 0
	local highest, actor = -math.huge, nil
	for index, wheel in ipairs(vehicle.type.settings.wheels) do
		local height, normal, contact = wheel_contact(vehicle, position, rotation, wheel)
		heights[index] = height
		if height then
			normals, count = normals + normal, count + 1
			if height > highest then
				highest, actor = height, contact
			end
		end
	end
	return heights, count >= MIN_SUPPORTS and Vector3.normalize(normals), actor
end

local function support_plane (points, first, second, third, travel)
	local a, b, c = points[first], points[second], points[third]
	local dx, dy, dz = b.x - a.x, b.y - a.y, b.z - a.z
	local ex, ey, ez = c.x - a.x, c.y - a.y, c.z - a.z
	local determinant = dx * ey - dy * ex
	if math.abs(determinant) < 0.000001 then
		return
	end
	local u = (-a.x * ey + a.y * ex) / determinant
	local v = (-dx * a.y + dy * a.x) / determinant
	if u < -0.000001 or v < -0.000001 or u + v > 1.000001 then
		return
	end
	local right = (dz * ey - dy * ez) / determinant
	local forward = (dx * ez - dz * ex) / determinant
	local height = a.z - right * a.x - forward * a.y
	for _, point in ipairs(points) do
		if point.z > height + right * point.x + forward * point.y + travel then
			return
		end
	end
	return right, forward, height
end

local function fitted_normal (heights, settings, rotation)
	local points = {}
	for index, wheel in ipairs(settings.wheels) do
		if heights[index] then
			local offset = Quaternion.rotate(rotation, Vector3(unpack(wheel.position)))
			points[#points + 1] = { x = offset.x, y = offset.y, z = heights[index] + offset.z }
		end
	end
	local right, forward, lowest
	for first = 1, #points - 2 do
		for second = first + 1, #points - 1 do
			for third = second + 1, #points do
				local x, y, height = support_plane(points, first, second, third, settings.suspension_travel)
				if height and (not lowest or height < lowest) then
					right, forward, lowest = x, y, height
				end
			end
		end
	end
	if not lowest then
		return
	end
	-- Gravity settles on a supporting triangle around the centre, rather than balancing on one high corner.
	local slope = math.sqrt(right * right + forward * forward)
	local limit = math.tan(settings.max_slope)
	if slope > limit then
		right, forward = right * limit / slope, forward * limit / slope
	end
	return Vector3.normalize(Vector3(-right, -forward, 1))
end

WheelTerrain.support = function (vehicle, position, yaw)
	local rotation = WheelTerrain.rotation(yaw, vehicle.normal:unbox())
	local heights, contact_normal = WheelTerrain.contacts(vehicle, position, rotation)
	return fitted_normal(heights, vehicle.type.settings, rotation) or contact_normal
end

WheelTerrain.height = function (vehicle, position, rotation)
	local heights, _, actor = WheelTerrain.contacts(vehicle, position, rotation)
	local total, highest, count = 0, -math.huge, 0
	for _, height in pairs(heights) do
		total = total + height
		highest = math.max(highest, height)
		count = count + 1
	end
	if count >= MIN_SUPPORTS then
		-- Balance individual contacts within suspension travel; the chassis spring follows this target.
		return math.max(total / count, highest - vehicle.type.settings.suspension_travel), actor
	end
end

WheelTerrain.ground = function (world, position, settings)
	return Surfaces.ground(world, position, settings.max_step_height, PROBE_DEPTH - settings.max_step_height, math.cos(settings.max_slope))
end

return WheelTerrain
