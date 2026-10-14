local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/lionheart/settings")
local Surfaces = mod.load_module("physics/surfaces")
local Terrain = {}
local MIN_GROUND_NORMAL = 0.55
local MIN_SUPPORTS = 3
local GROUND_PROBE_HEIGHT = Settings.max_step_height + Settings.suspension_travel
local TRACK_THICKNESS = 0.03
local CONTACT_CLEARANCE = 0.01
local TRACK_HALF_WIDTH = 0.3
local MAX_CONTACTS = 32
local PROBE_START = 8

Terrain.ground = function (world, position)
	local hits = PhysicsWorld.raycast(
		World.physics_world(world), position + Vector3(0, 0, PROBE_START), Vector3.down(), PROBE_START + 4,
		"all", "types", "both", "collision_filter", "filter_player_mover"
	)
	local point, normal
	for _, hit in ipairs(hits or {}) do
		if Surfaces.is_ground(hit[4]) and hit[3].z > MIN_GROUND_NORMAL and hit[1].z <= position.z + GROUND_PROBE_HEIGHT and (not point or hit[1].z > point.z) then
			point, normal = hit[1], hit[3]
		end
	end
	return point, normal
end

Terrain.rotation = function (yaw, normal)
	local forward = Quaternion.forward(Quaternion.from_yaw_pitch_roll(yaw, 0, 0))
	forward = Vector3.normalize(forward - normal * Vector3.dot(forward, normal))
	return Quaternion.look(forward, normal)
end

local function fit_plane (points)
	local count = #points
	if count < MIN_SUPPORTS then
		return
	end
	local x, y, z, xx, yy, xy, xz, yz = 0, 0, 0, 0, 0, 0, 0, 0
	for _, sample in ipairs(points) do
		local sx, sy, sz = sample.x, sample.y, sample.z
		x, y, z = x + sx, y + sy, z + sz
		xx, yy, xy = xx + sx * sx, yy + sy * sy, xy + sx * sy
		xz, yz = xz + sx * sz, yz + sy * sz
	end
	local a, b, c = xx - x * x / count, xy - x * y / count, yy - y * y / count
	local d, e = xz - x * z / count, yz - y * z / count
	local determinant = a * c - b * b
	if determinant <= a * c * 0.000001 then
		return
	end
	local right_slope = (d * c - b * e) / determinant
	local forward_slope = (a * e - b * d) / determinant
	return right_slope, forward_slope, (z - right_slope * x - forward_slope * y) / count
end

local function track_segments ()
	local segments = { { first = { -Settings.track_contact_half_length, 0 }, last = { Settings.track_contact_half_length, 0 } } }
	for _, contact in ipairs(Settings.track_leading_contacts) do
		local bottom = (contact.y < 0 and -1 or 1) * Settings.track_contact_half_length
		segments[#segments + 1] = { first = { bottom, 0 }, last = { contact.y, contact.height } }
	end
	return segments
end

local SEGMENTS = track_segments()

Terrain.sweep = function (world, origin, destination, rotation, compression)
	local results = {}
	-- These are the lower contact faces; the solid hull handles ceilings during upward correction.
	if destination.x == origin.x and destination.y == origin.y and destination.z > origin.z then
		return results
	end
	for _, side in ipairs({ -1, 1 }) do
		for index, segment in ipairs(SEGMENTS) do
			local first = Vector3(side * Settings.track_half_width, segment.first[1], segment.first[2])
			local last = Vector3(side * Settings.track_half_width, segment.last[1], segment.last[2])
			local tangent = Vector3.normalize(last - first)
			local local_rotation = Quaternion.look(tangent, Vector3.cross(Vector3.right(), tangent))
			local offset = Quaternion.rotate(rotation, (first + last) * 0.5 + Vector3(0, 0, TRACK_THICKNESS + compression))
			local hits = PhysicsWorld.linear_obb_sweep(
				World.physics_world(world), origin + offset, destination + offset,
				Vector3(TRACK_HALF_WIDTH, Vector3.distance(first, last) * 0.5, TRACK_THICKNESS),
				Quaternion.multiply(rotation, local_rotation),
				MAX_CONTACTS, "collision_filter", "filter_player_mover"
			)
			for _, hit in ipairs(hits or {}) do
				if Surfaces.is_ground(hit.actor) then
					hit.support = true
					hit.track = side * index
					results[#results + 1] = hit
				end
			end
		end
	end
	return results
end

local function track_contacts (world, position, rotation)
	local height, points, normals = -math.huge, {}, Vector3.zero()
	local actor
	local inverse = Quaternion.inverse(rotation)
	local start = GROUND_PROBE_HEIGHT
	local contacts = {}
	for _, hit in ipairs(Terrain.sweep(world, position + Vector3(0, 0, start), position - Vector3(0, 0, 4), rotation, 0)) do
		if hit.normal.z > MIN_GROUND_NORMAL and (not contacts[hit.track] or hit.distance < contacts[hit.track].distance) then
			contacts[hit.track] = hit
		end
	end
	for _, hit in pairs(contacts) do
		local sample = Quaternion.rotate(inverse, hit.position - position)
		local clearance = 0
		for _, leading in ipairs(Settings.track_leading_contacts) do
			local bottom = (leading.y < 0 and -1 or 1) * Settings.track_contact_half_length
			if leading.y > 0 and sample.y > bottom or leading.y < 0 and sample.y < bottom then
				clearance = math.clamp((sample.y - bottom) / (leading.y - bottom), 0, 1) * leading.height
			end
		end
		points[#points + 1] = { x = sample.x, y = sample.y, z = sample.z - clearance }
		local contact_height = position.z + start - hit.distance
		if contact_height > height then
			height, actor = contact_height, hit.actor
		end
		normals = normals + hit.normal
	end
	if #points > 0 then
		return height, points, Vector3.normalize(normals), actor
	end
end

Terrain.height = function (world, position, rotation)
	local height, _, _, actor = track_contacts(world, position, rotation)
	return height and height + CONTACT_CLEARANCE, actor
end

Terrain.support = function (world, position, yaw)
	local rotation = Quaternion.from_yaw_pitch_roll(yaw, 0, 0)
	local height, points, contact_normal = track_contacts(world, position, rotation)
	if not height then
		return
	end
	local right_slope, forward_slope, plane_height = fit_plane(points)
	-- Partial support remains a real contact even when a fitted plane is underdetermined.
	local normal = plane_height and Vector3.normalize(Vector3(-right_slope, -forward_slope, 1))
		or Quaternion.rotate(Quaternion.inverse(rotation), contact_normal)
	local slope = Vector3.length(Vector3.flat(normal)) / normal.z
	if slope > math.tan(Settings.max_slope) then
		local horizontal = Vector3.normalize(Vector3.flat(normal)) * math.sin(Settings.max_slope)
		normal = Vector3(horizontal.x, horizontal.y, math.cos(Settings.max_slope))
	end
	local point = Vector3(position.x, position.y, height)
	return point, Quaternion.rotate(rotation, normal)
end

return Terrain
