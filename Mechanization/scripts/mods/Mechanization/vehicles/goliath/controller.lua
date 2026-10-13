local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/goliath/settings")
local Terrain = mod.load_module("physics/wheel_terrain")
local WheelDrive = mod.load_module("physics/wheel_drive")
local Chassis = mod.load_module("physics/wheel_chassis")
local Exhaust = mod.load_module("vehicles/exhaust")
local Vehicle = {}
local ENGINE_EVENT = "wwise/events/world/play_tank_mission_engine_loop"
local ENGINE_VOLUME = 1
local ENGINE_RESPONSE = 6

local function spawn_body (world, resource, position)
	local unit = World.spawn_unit_ex(world, resource, nil, position, Quaternion.identity(), false)
	local facing = Quaternion.from_yaw_pitch_roll(math.pi, 0, 0)
	local actors = Chassis.capture_actors(unit, position, facing)
	-- Keep the root facing forward for shared seating and camera calculations.
	for node = 2, Unit.num_scene_graph_items(unit) do
		if Unit.scene_graph_parent(unit, node) == 1 then
			Unit.set_local_position(unit, node, Quaternion.rotate(facing, Unit.local_position(unit, node)))
			Unit.set_local_rotation(unit, node, Quaternion.multiply(facing, Unit.local_rotation(unit, node)))
		end
	end
	World.update_unit_and_children(world, unit)
	return { unit = unit, actors = actors, position = Vector3Box(Vector3.zero()), rotation = QuaternionBox(Quaternion.identity()) }
end

local function spawn_attachment (world, resource, parent, node, origin)
	local position, rotation = Unit.world_position(parent, node), Unit.world_rotation(parent, node)
	local unit = World.spawn_unit_ex(world, resource, nil, position, rotation, false)
	return {
		unit = unit,
		actors = Chassis.capture_actors(unit, position, Quaternion.inverse(rotation)),
		position = Vector3Box(position - origin),
		rotation = QuaternionBox(rotation),
	}
end

Vehicle.spawn_position = function (world, position)
	return Terrain.ground(world, position, Settings)
end

Vehicle.bounds = function (v)
	return Vector3(0, 0.72, 1.82), Vector3(2.95, 4.92, 1.92)
end

Vehicle.supports_contact = function (v, normal)
	return normal.z >= math.cos(Settings.max_slope)
end

Vehicle.support_height = Terrain.height
Vehicle.can_spawn = Chassis.can_spawn
Vehicle.step = WheelDrive.step

Vehicle.create = function (world, position, yaw)
	local models = { spawn_body(world, Settings.unit, position), spawn_body(world, Settings.rear, position) }
	local root = models[1].unit
	for _, name in ipairs({ "ap_04", "ap_05" }) do
		models[#models + 1] = spawn_attachment(world, Settings.door, root, Unit.node(root, name), position)
	end
	local wheels = {}
	for index, settings in ipairs(Settings.wheels) do
		local parent = models[settings.parent].unit
		local wheel = spawn_attachment(world, Settings.tyre, parent, Unit.node(parent, settings.node), position)
		wheel.phase, wheel.compression = 0, 0
		wheels[index] = wheel
	end
	local parts = {}
	for _, group in ipairs({ models, wheels }) do
		for _, entry in ipairs(group) do
			parts[entry.unit] = true
			Unit.set_unit_culling(entry.unit, false)
			-- Lower detail levels remove decoration as the follow camera changes angle.
			for index = 1, Unit.num_lod_objects(entry.unit) do
				LODObject.set_static_select(Unit.lod_object(entry.unit, index), 0)
			end
			for index, actor in ipairs(entry.actors) do
				Actor.set_collision_enabled(actor.actor, false)
				-- The additional interaction hull fills the open cargo bed. Only the
				-- first, physical mesh belongs in weapon and disabler scene queries.
				Actor.set_scene_query_enabled(actor.actor, index == 1)
			end
		end
	end
	local wwise = Managers.world:wwise_world(world)
	local source = WwiseWorld.make_manual_source(wwise, root, 1)
	WwiseWorld.set_source_parameter(wwise, source, "payload_speed", 0)
	WwiseWorld.set_dry_environment_for_source(wwise, source, ENGINE_VOLUME)
	return {
		unit = root,
		parts = parts,
		models = models,
		wheels = wheels,
		exhausts = Exhaust.create(world, root, Settings.exhausts),
		hit_actor = Unit.actor(root, 1),
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
		throttle = 0,
		engine_speed = 0,
		wwise = wwise,
		source = source,
		engine = WwiseWorld.trigger_resource_event(wwise, ENGINE_EVENT, source),
	}
end

Vehicle.animate = function (v, dt)
	Chassis.animate(v, dt)
	local maximum = v.speed < 0 and Settings.reverse_speed or Settings.forward_speed
	local speed = math.clamp(math.abs(v.speed) / maximum, 0, 1)
	v.engine_speed = math.lerp(v.engine_speed, speed, 1 - math.exp(-ENGINE_RESPONSE * dt))
	WwiseWorld.set_source_parameter(v.wwise, v.source, "payload_speed", v.engine_speed)
end

Vehicle.pose = function (v)
	local origin = v.position:unbox()
	local body = Terrain.rotation(v.yaw, v.normal:unbox())
	for _, entry in ipairs(v.models) do
		local position = origin + Quaternion.rotate(body, entry.position:unbox())
		local rotation = Quaternion.multiply(body, entry.rotation:unbox())
		Unit.set_local_position(entry.unit, 1, position)
		Unit.set_local_rotation(entry.unit, 1, rotation)
		World.update_unit_and_children(v.world, entry.unit)
		Chassis.pose_actors(entry.actors, position, rotation)
	end
	for index, wheel in ipairs(v.wheels) do
		local offset = wheel.position:unbox() + Vector3.up() * wheel.compression
		local steering = Settings.wheels[index].front and v.steering or 0
		local turn = Quaternion.from_yaw_pitch_roll(steering, 0, 0)
		local roll = Quaternion.axis_angle(Vector3.right(), wheel.phase)
		local rotation = Quaternion.multiply(Quaternion.multiply(body, turn), Quaternion.multiply(roll, wheel.rotation:unbox()))
		local position = origin + Quaternion.rotate(body, offset)
		Unit.set_local_position(wheel.unit, 1, position)
		Unit.set_local_rotation(wheel.unit, 1, rotation)
		World.update_unit_and_children(v.world, wheel.unit)
		Chassis.pose_actors(wheel.actors, position, rotation)
	end
end

Vehicle.destroy = function (v)
	Exhaust.destroy(v.exhausts)
	WwiseWorld.stop_event(v.wwise, v.engine)
	WwiseWorld.destroy_manual_source(v.wwise, v.source)
	for unit in pairs(v.parts) do
		World.destroy_unit(v.world, unit)
	end
end

return Vehicle
