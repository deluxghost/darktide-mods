local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/wolfquad/settings")
local Terrain = mod.load_module("physics/wheel_terrain")
local WheelDrive = mod.load_module("physics/wheel_drive")
local Motion = mod.load_module("physics/motion")
local Collision = mod.load_module("physics/collision")
local Vehicle = {}

local function capture_actors (unit, origin, facing)
	local actors = {}
	for index = 1, Unit.num_actors(unit) do
		local actor = Unit.actor(unit, index)
		actors[index] = {
			actor = actor,
			position = Vector3Box(Quaternion.rotate(facing, Actor.position(actor) - origin)),
			rotation = QuaternionBox(Quaternion.multiply(facing, Actor.rotation(actor))),
		}
	end
	return actors
end

local function pose_actors (actors, position, rotation)
	-- Static prop actors do not follow their scene graph after spawning.
	for _, entry in ipairs(actors) do
		Actor.teleport_position(entry.actor, position + Quaternion.rotate(rotation, entry.position:unbox()))
		Actor.teleport_rotation(entry.actor, Quaternion.multiply(rotation, entry.rotation:unbox()))
	end
end

Vehicle.spawn_position = function (world, position)
	return Terrain.ground(world, position, Settings)
end

Vehicle.bounds = function (v)
	return Vector3(0, 0.08, 0.57), Vector3(0.7, 1.22, 0.57)
end

Vehicle.supports_contact = function (v, normal)
	return normal.z >= math.cos(Settings.max_slope)
end

Vehicle.support_height = Terrain.height

Vehicle.create = function (world, position, yaw)
	-- The prop's customization component normally creates static wheel children.
	-- Create movable wheels explicitly without the level-prop flow or chunk culling.
	local unit = World.spawn_unit_ex(world, Settings.unit, nil, position, Quaternion.identity(), false)
	local facing = Quaternion.from_yaw_pitch_roll(math.pi, 0, 0)
	local actors = capture_actors(unit, position, facing)
	for node = 2, Unit.num_scene_graph_items(unit) do
		Unit.set_local_position(unit, node, Quaternion.rotate(facing, Unit.local_position(unit, node)))
		Unit.set_local_rotation(unit, node, Quaternion.multiply(facing, Unit.local_rotation(unit, node)))
	end
	local parts = { [unit] = true }
	local wheels = {}
	for index, wheel in ipairs(Settings.wheels) do
		local tyre = World.spawn_unit_ex(world, Settings.tyre, nil, position, Quaternion.identity(), false)
		parts[tyre] = true
		wheels[index] = { unit = tyre, actors = capture_actors(tyre, position, Quaternion.identity()), phase = 0, compression = 0 }
	end
	for part in pairs(parts) do
		Unit.set_unit_culling(part, false)
		for index = 1, Unit.num_actors(part) do
			local actor = Unit.actor(part, index)
			Actor.set_collision_enabled(actor, false)
			Actor.set_scene_query_enabled(actor, true)
		end
	end
	return {
		unit = unit,
		parts = parts,
		hit_actor = Unit.actor(unit, 1),
		world = world,
		position = Vector3Box(position),
		normal = Vector3Box(Vector3.up()),
		yaw = yaw,
		speed = 0,
		wheel_speed = 0,
		drive_speed = 0,
		vertical_speed = 0,
		horizontal_velocity = Vector3Box(Vector3.zero()),
		airborne = false,
		steering = 0,
		wheels = wheels,
		actors = actors,
		throttle = 0,
	}
end

Vehicle.can_spawn = function (v, vehicles, ignored_units)
	local position = v.position:unbox()
	local normal = Terrain.support(v, position, v.yaw)
	if not normal then
		return false
	end
	local rotation = Terrain.rotation(v.yaw, normal)
	local height = Terrain.height(v, position, rotation)
	if not height then
		return false
	end
	position.z = height
	v.position:store(position)
	v.normal:store(normal)
	Vehicle.pose(v)
	if not Collision.clear_players(v, position, rotation, ignored_units) or not Collision.clear_vehicles(v, position, rotation, vehicles) then
		return false
	end
	for _, filter in ipairs({ "filter_player_mover", "filter_player_character_shooting_raycast" }) do
		for _, actor in ipairs(Motion.overlap(v, position, rotation, filter)) do
			local unit = Actor.unit(actor)
			local relevant = filter == "filter_player_mover" or ScriptUnit.has_extension(unit, "health_system")
			if relevant and not Collision.contains_unit(v, unit) and not ignored_units[unit] then
				return false
			end
		end
	end
	return true
end

Vehicle.step = WheelDrive.step

Vehicle.animate = function (v, dt)
	local rotation = Terrain.rotation(v.yaw, v.normal:unbox())
	local heights = Terrain.contacts(v, v.position:unbox(), rotation)
	local response = 1 - math.exp(-Settings.suspension_response * dt)
	for index, wheel in ipairs(v.wheels) do
		wheel.phase = (wheel.phase - v.wheel_speed * dt / Settings.wheel_radius) % (math.pi * 2)
		local height = heights[index]
		local target = height and math.clamp(height - v.position:unbox().z, -Settings.suspension_travel, Settings.suspension_travel) or -Settings.suspension_travel
		wheel.compression = math.lerp(wheel.compression, target, response)
	end
end

Vehicle.pose = function (v)
	local position = v.position:unbox()
	local body = Terrain.rotation(v.yaw, v.normal:unbox())
	Unit.set_local_position(v.unit, 1, position)
	Unit.set_local_rotation(v.unit, 1, body)
	for index, wheel in ipairs(v.wheels) do
		local settings = Settings.wheels[index]
		local offset = Vector3(unpack(settings.position)) + Vector3.up() * wheel.compression
		local steering = settings.front and v.steering or 0
		local turn = Quaternion.from_yaw_pitch_roll(steering, 0, 0)
		local roll = Quaternion.axis_angle(Vector3.right(), wheel.phase)
		local facing = Quaternion.from_yaw_pitch_roll(settings.side > 0 and math.pi or 0, 0, 0)
		local rotation = Quaternion.multiply(Quaternion.multiply(body, turn), Quaternion.multiply(roll, facing))
		local wheel_position = position + Quaternion.rotate(body, offset)
		Unit.set_local_position(wheel.unit, 1, wheel_position)
		Unit.set_local_rotation(wheel.unit, 1, rotation)
		World.update_unit_and_children(v.world, wheel.unit)
		pose_actors(wheel.actors, wheel_position, rotation)
	end
	World.update_unit_and_children(v.world, v.unit)
	pose_actors(v.actors, position, body)
end

Vehicle.destroy = function (v)
	for _, wheel in ipairs(v.wheels) do
		World.destroy_unit(v.world, wheel.unit)
	end
	World.destroy_unit(v.world, v.unit)
end

return Vehicle
