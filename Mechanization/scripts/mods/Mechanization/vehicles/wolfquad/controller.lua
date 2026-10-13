local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/wolfquad/settings")
local Terrain = mod.load_module("physics/wheel_terrain")
local WheelDrive = mod.load_module("physics/wheel_drive")
local Chassis = mod.load_module("physics/wheel_chassis")
local Vehicle = {}
local ENGINE_IDLE_THROTTLE = 0.6
local ENGINE_PITCH_MIN = 0.82506
local ENGINE_VOLUME = 0.21
local ENGINE_RESPONSE_TIME = 0.1
local ENGINE_NEAR_FIELD_RADIUS = 6
local ENGINE_EVENT = "wwise/events/weapon/play_2h_chainsword"

local function create_engine_layer (wwise, position, throttle, volume)
	-- Unit/node sources are shared; each layer needs independent RTPC values.
	local source = WwiseWorld.make_manual_source(wwise, position, Quaternion.identity())
	WwiseWorld.set_source_parameter(wwise, source, "combat_chainsword_throttle", throttle)
	WwiseWorld.set_source_parameter(wwise, source, "combat_chainsword_cut", ENGINE_PITCH_MIN)
	WwiseWorld.set_dry_environment_for_source(wwise, source, volume)
	return { source = source, event = WwiseWorld.trigger_resource_event(wwise, ENGINE_EVENT, source) }
end

local function update_engine (v, dt)
	local player = Managers.player:local_player(1)
	local listener = Managers.state.camera:camera_position(player.viewport_name)
	local origin = v.position:unbox() + Vector3.up() * 0.6
	local offset = listener - origin
	local distance = Vector3.length(offset)
	-- A uniform near field compensates for this handheld event's short range.
	local position = distance > ENGINE_NEAR_FIELD_RADIUS and origin + offset * (ENGINE_NEAR_FIELD_RADIUS / distance) or listener
	for _, layer in pairs(v.engine) do
		WwiseWorld.set_source_position(v.wwise, layer.source, position)
	end
	local max_speed = v.speed < 0 and Settings.reverse_speed or Settings.forward_speed
	local speed = math.clamp(math.abs(v.speed) / max_speed, 0, 1)
	local response = 1 - math.exp(-dt / ENGINE_RESPONSE_TIME)
	-- Smooth the mixing angle so both layer gains settle without a long quiet tail.
	v.engine_blend = math.lerp(v.engine_blend, math.asin(math.sqrt(speed)), response)
	speed = math.sin(v.engine_blend) ^ 2
	-- Fixed throttle layers avoid the event's built-in RTPC slew on stopping.
	-- Equal-power mixing keeps intermediate speeds from losing engine volume.
	WwiseWorld.set_dry_environment_for_source(v.wwise, v.engine.idle.source, ENGINE_VOLUME * math.sqrt(1 - speed))
	WwiseWorld.set_dry_environment_for_source(v.wwise, v.engine.drive.source, ENGINE_VOLUME * math.sqrt(speed))
	-- The final rising segment changes pitch/gain without selecting cutting clips.
	WwiseWorld.set_source_parameter(v.wwise, v.engine.drive.source, "combat_chainsword_cut", math.lerp(ENGINE_PITCH_MIN, 1, speed))
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
	local actors = Chassis.capture_actors(unit, position, facing)
	for node = 2, Unit.num_scene_graph_items(unit) do
		Unit.set_local_position(unit, node, Quaternion.rotate(facing, Unit.local_position(unit, node)))
		Unit.set_local_rotation(unit, node, Quaternion.multiply(facing, Unit.local_rotation(unit, node)))
	end
	local parts = { [unit] = true }
	local wheels = {}
	for index, wheel in ipairs(Settings.wheels) do
		local tyre = World.spawn_unit_ex(world, Settings.tyre, nil, position, Quaternion.identity(), false)
		parts[tyre] = true
		wheels[index] = { unit = tyre, actors = Chassis.capture_actors(tyre, position, Quaternion.identity()), phase = 0, compression = 0 }
	end
	for part in pairs(parts) do
		Unit.set_unit_culling(part, false)
		for index = 1, Unit.num_actors(part) do
			local actor = Unit.actor(part, index)
			Actor.set_collision_enabled(actor, false)
			Actor.set_scene_query_enabled(actor, true)
		end
	end
	local wwise = Managers.world:wwise_world(world)
	return {
		unit = unit,
		wwise = wwise,
		engine_blend = 0,
		engine = {
			idle = create_engine_layer(wwise, position, ENGINE_IDLE_THROTTLE, ENGINE_VOLUME),
			drive = create_engine_layer(wwise, position, 1, 0),
		},
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

Vehicle.can_spawn = Chassis.can_spawn

Vehicle.step = WheelDrive.step

Vehicle.animate = function (v, dt)
	update_engine(v, dt)
	Chassis.animate(v, dt)
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
		Chassis.pose_actors(wheel.actors, wheel_position, rotation)
	end
	World.update_unit_and_children(v.world, v.unit)
	Chassis.pose_actors(v.actors, position, body)
end

Vehicle.destroy = function (v)
	for _, layer in pairs(v.engine) do
		WwiseWorld.stop_event(v.wwise, layer.event)
		WwiseWorld.destroy_manual_source(v.wwise, layer.source)
	end
	for _, wheel in ipairs(v.wheels) do
		World.destroy_unit(v.world, wheel.unit)
	end
	World.destroy_unit(v.world, v.unit)
end

return Vehicle
