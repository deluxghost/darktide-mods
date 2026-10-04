local Motion = {}
local LEG_SIGNS = { 1, -1, -1, 1 }
local MINECRAFT_HEIGHT = 26 / 16
local TORSO_NODES = { "j_hips", "j_spine", "j_spine1" }

local function horizontal_position(parent, nodes, root_position)
	local center = Vector3.zero()
	for _, node in ipairs(nodes) do
		center = center + Unit.world_position(parent, node)
	end
	center = center / #nodes
	return Vector3(center.x, center.y, root_position.z)
end

function Motion.create(parent, visual, breed, unit_data)
	local nodes = {}
	for _, name in ipairs({ "body", "head", "leg0", "leg1", "leg2", "leg3" }) do
		nodes[name] = Unit.node(visual, name)
	end
	local torso_nodes = {}
	for _, name in ipairs(TORSO_NODES) do
		torso_nodes[#torso_nodes + 1] = Unit.node(parent, name)
	end
	local size = breed.base_height / MINECRAFT_HEIGHT * unit_data:breed_size_variation()
	local position = horizontal_position(parent, torso_nodes, Unit.world_position(parent, 1))
	Unit.set_local_scale(visual, 1, Vector3(size, size, size))
	Unit.set_visibility(visual, "flash", false)
	Unit.set_local_position(visual, 1, position)
	return {
		unit = visual,
		world = Unit.world(parent),
		nodes = nodes,
		torso_nodes = torso_nodes,
		position = Vector3Box(position),
		distance = 0,
		flash = false,
	}
end

function Motion.update(parent, record, dt, t)
	local visual = record.unit
	local position = horizontal_position(parent, record.torso_nodes, Unit.world_position(parent, 1))
	local delta = position - record.position:unbox()
	delta.z = 0
	local distance = Vector3.length(delta)
	record.distance = record.distance + distance
	record.position:store(position)
	-- Follow the animated torso horizontally while keeping the feet at root height.
	Unit.set_local_position(visual, 1, position)
	Unit.set_local_rotation(visual, 1, Quaternion.flat_no_roll(Unit.world_rotation(parent, 1)))

	-- The original Molang expressions use degrees and opposing diagonal legs.
	local speed = math.min(distance / dt, 1)
	local angle = math.rad(math.cos(math.rad(record.distance * 38.17326)) * 80.22 * speed)
	for i = 1, 4 do
		Unit.set_local_rotation(visual, record.nodes["leg" .. (i - 1)], Quaternion.axis_angle(Vector3.right(), angle * LEG_SIGNS[i]))
	end

	local swell = record.fuse_start and math.clamp((t - record.fuse_start) / record.fuse_duration, 0, 1) or 0
	local wobble = math.sin(math.rad(swell * 5730)) * swell * 0.01 + 1
	local horizontal = (swell ^ 4 * 0.4 + 1) * wobble
	local vertical = (swell ^ 4 * 0.1 + 1) / wobble
	local scale = Vector3(horizontal, horizontal, vertical)
	for _, node in pairs(record.nodes) do
		Unit.set_local_scale(visual, node, scale)
	end
	local flash = math.floor(swell * 10 + 0.5) % 2 == 1
	if flash ~= record.flash then
		Unit.set_visibility(visual, "normal", not flash)
		Unit.set_visibility(visual, "flash", flash)
		record.flash = flash
	end
end

return Motion
