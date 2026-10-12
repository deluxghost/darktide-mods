local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/lionheart/settings")
local View = mod.load_module("camera")
local Collision = mod.load_module("physics/collision")
local Terrain = mod.load_module("vehicles/lionheart/terrain")
local Motion = mod.load_module("physics/motion")
local GroundMotion = mod.load_module("physics/ground_motion")
local GroundInertia = mod.load_module("physics/ground_inertia")
local Contacts = mod.load_module("physics/contacts")
local Vehicle = {}
local TRACK_LINKS = 70
local TAU = math.pi * 2
local TURRET_SOUND_START_ANGLE = math.rad(1)
local TURRET_SOUND_STOP_SPEED = math.rad(0.5)
local TURRET_SOUND_STOP_DELAY = 0.2
local EXHAUST_EFFECT = "content/fx/particles/environment/smoke_cooling_ground_directional_thin"
local EXHAUST_SCALE = 0.7
local EXHAUST_EMISSION = 2
local MAX_MOVEMENT_STEP = 1 / 60
local GROUND_EPSILON = 0.001
local FRONT_PIVOT = { -0.456, 3.859, 2.809 }
local FRONT_MUZZLE = { -0.456, 5.45, 2.9 }
-- The model's authored exhaust locators have no recovered string names.
local EXHAUST_NODES = { 5, 6 }

local function approach (value, target, amount)
	return value + math.clamp(target - value, -amount, amount)
end

local function drive_towards (value, target, acceleration, braking, dt)
	if value * target < 0 then
		local stopping_time = math.abs(value) / braking
		if stopping_time >= dt then
			return approach(value, 0, braking * dt)
		end
		return approach(0, target, acceleration * (dt - stopping_time))
	end
	local rate = math.abs(target) < math.abs(value) and braking or acceleration
	return approach(value, target, rate * dt)
end

local function angle_delta (target, value)
	return (target - value + math.pi) % TAU - math.pi
end

Vehicle.spawn_position = Terrain.ground
Vehicle.support_height = function (v, position, rotation)
	return Terrain.height(v.world, position, rotation)
end

Vehicle.supports_contact = function (v, normal)
	return normal.z >= math.cos(Settings.max_slope)
end
Vehicle.sweep_support = function (v, origin, destination, rotation)
	return Terrain.sweep(v.world, origin, destination, rotation, Settings.suspension_travel)
end

local function capture_tracks (unit, side)
	local nodes, positions, rotations = {}, {}, {}
	for index = 0, TRACK_LINKS - 1 do
		local node = Unit.node(unit, string.format("loc_g_%s_trread_01_%02d", side, index))
		nodes[index + 1] = node
		local position = Unit.local_position(unit, node)
		positions[index + 1] = Vector3Box(position)
		rotations[index + 1] = QuaternionBox(Unit.local_rotation(unit, node))
	end
	return {
		nodes = nodes,
		positions = positions,
		rotations = rotations,
		phase = 0,
		pitch = Vector3.distance(positions[1]:unbox(), positions[2]:unbox()),
	}
end

local function create_exhausts (world, unit)
	local exhausts = {}
	local group = World.create_particle_group(world)
	local scale = Vector3(EXHAUST_SCALE, EXHAUST_SCALE, EXHAUST_SCALE)
	for _, node in ipairs(EXHAUST_NODES) do
		local effect = World.create_particles(world, EXHAUST_EFFECT, Unit.world_position(unit, node), Quaternion.identity(), scale, group)
		World.set_particles_emit_rate_multiplier(world, effect, EXHAUST_EMISSION)
		local pose = Matrix4x4.from_quaternion_position(Quaternion.inverse(Unit.world_rotation(unit, node)), Vector3.zero())
		Matrix4x4.set_scale(pose, scale)
		World.link_particles(world, effect, unit, node, pose, "destroy")
		exhausts[#exhausts + 1] = { id = effect, node = node }
	end
	return exhausts, group
end

Vehicle.create = function (world, position, yaw)
	-- Measure the authored collision bounds before applying the requested heading.
	-- Skip the authored spawn flow so it cannot create an uncontrolled exhaust plume.
	local unit = World.spawn_unit_ex(world, Settings.unit, nil, position, Quaternion.identity(), false)
	local exhausts, exhaust_group = create_exhausts(world, unit)
	-- Lower model detail levels omit the individual tread links.
	Unit.set_unit_culling(unit, false)
	LODObject.set_static_select(Unit.lod_object(unit, 1), 0)
	local lower = Vector3(math.huge, math.huge, math.huge)
	local upper = Vector3(-math.huge, -math.huge, -math.huge)
	-- Vehicle collision is swept as a hull; the decorative actors must not trap its driver.
	for index = 1, Unit.num_actors(unit) do
		local actor = Unit.actor(unit, index)
		local center, half_extents = Actor.world_bounds(actor)
		lower = Vector3.min(lower, center - half_extents - position)
		upper = Vector3.max(upper, center + half_extents - position)
		Actor.set_collision_enabled(actor, false)
		Actor.set_scene_query_enabled(actor, true)
	end
	local wwise = Managers.world:wwise_world(world)
	local source = WwiseWorld.make_manual_source(wwise, unit, 1)
	WwiseWorld.set_source_parameter(wwise, source, "payload_speed", 0)
	local speed_variable = Unit.animation_find_variable(unit, "speed")
	Unit.animation_set_variable(unit, speed_variable, 0)
	-- Character collision includes the tracks down to their contact plane.
	lower.z = 0
	return {
		unit = unit,
		parts = { [unit] = true },
		hit_actor = Unit.actor(unit, 1),
		exhausts = exhausts,
		exhaust_group = exhaust_group,
		world = world,
		position = Vector3Box(position),
		normal = Vector3Box(Vector3.up()),
		hull_center = Vector3Box((lower + upper) * 0.5),
		hull_half_extents = Vector3Box((upper - lower) * 0.5),
		yaw = yaw,
		turret_yaw = yaw,
		pitch = 0,
		front_yaw = 0,
		front_pitch = 0,
		drive_speed = 0,
		vertical_speed = 0,
		horizontal_velocity = Vector3Box(Vector3.zero()),
		airborne = false,
		turn_velocity = 0,
		speed = 0,
		turn = 0,
		left_speed = 0,
		right_speed = 0,
		left = capture_tracks(unit, "l"),
		right = capture_tracks(unit, "r"),
		yaw_node = Unit.node(unit, "j_turret_yaw"),
		muzzle_node = Unit.node(unit, "muzzle_flash"),
		front_node = Unit.node(unit, "j_frontgun_com_01"),
		front_rest_position = Vector3Box(Unit.local_position(unit, Unit.node(unit, "j_frontgun_com_01"))),
		front_rest_rotation = QuaternionBox(Unit.local_rotation(unit, Unit.node(unit, "j_frontgun_com_01"))),
		speed_variable = speed_variable,
		wwise = wwise,
		source = source,
		engine = WwiseWorld.trigger_resource_event(wwise, "wwise/events/world/play_tank_mission_engine_loop", source),
		rounds = Settings.magazine_size,
		next_shot = 0,
		front_rounds = Settings.front_magazine_size,
		next_front_shot = 0,
	}
end

local function hull_clear (v, position, yaw, normal, vehicles, ignored_units, filter)
	filter = filter or "filter_player_mover"
	local rotation = Terrain.rotation(yaw, normal)
	if not Collision.clear_players(v, position, rotation, ignored_units)
		or not Collision.clear_vehicles(v, position, rotation, vehicles)
	then
		return false
	end
	for _, actor in ipairs(Motion.overlap(v, position, rotation, filter)) do
		local unit = Actor.unit(actor)
		local relevant = filter == "filter_player_mover" or ScriptUnit.has_extension(unit, "health_system")
		if relevant and unit ~= v.unit and not (ignored_units and ignored_units[unit]) and not Collision.contains_player(v, unit) then
			return false
		end
	end
	return true
end

Vehicle.bounds = function (v)
	return v.hull_center:unbox(), v.hull_half_extents:unbox()
end

Vehicle.can_spawn = function (v, vehicles, ignored_units)
	local point, normal = Terrain.support(v.world, v.position:unbox(), v.yaw)
	if not point then
		return false
	end
	local height = Terrain.height(v.world, point, Terrain.rotation(v.yaw, normal))
	if not height then
		return false
	end
	point.z = height
	v.position:store(point)
	v.normal:store(normal)
	return hull_clear(v, point, v.yaw, normal, vehicles, ignored_units)
		and hull_clear(v, point, v.yaw, normal, vehicles, ignored_units, "filter_player_character_shooting_raycast")
end

local function project_support (v, position, rotation, vehicles, dt)
	local height = Terrain.height(v.world, position, rotation)
	if not height or position.z >= height - Settings.suspension_travel then
		return position
	end
	-- Recover an existing penetration gradually; do not teleport the chassis or cancel horizontal travel.
	local lift = math.min(height - Settings.suspension_travel, position.z + Settings.suspension_lift_speed * dt)
	v.position:store(position)
	return Motion.translate(v, Vector3(position.x, position.y, lift), rotation, vehicles)
end

local function move (v, input, dt, vehicles)
	local origin = v.position:unbox()
	local old_yaw = v.yaw
	local throttle, steer = input.axes.throttle, input.axes.steer
	local target_speed = throttle * (throttle >= 0 and Settings.forward_speed or Settings.reverse_speed)
	v.drive_speed = drive_towards(v.drive_speed, target_speed, Settings.acceleration, Settings.braking_deceleration, dt)
	local steering_direction = throttle ~= 0 and throttle or v.drive_speed
	steering_direction = steering_direction < 0 and -1 or 1
	local target_turn = -steer * Settings.turn_speed * steering_direction
	v.turn_velocity = drive_towards(v.turn_velocity, target_turn, Settings.turn_acceleration, Settings.turn_deceleration, dt)
	local current_rotation = Terrain.rotation(v.yaw, v.normal:unbox())
	if GroundInertia.step(v, Terrain.height(v.world, origin, current_rotation), current_rotation, dt, vehicles) then
		v.turn = 0
		if v.airborne then
			v.left_speed = v.drive_speed + v.turn_velocity * Settings.track_half_width
			v.right_speed = v.drive_speed - v.turn_velocity * Settings.track_half_width
		else
			v.turn_velocity = 0
			v.left_speed, v.right_speed = v.speed, v.speed
		end
		return
	end
	local yaw = v.yaw + v.turn_velocity * dt
	local forward = Quaternion.forward(Quaternion.from_yaw_pitch_roll(yaw, 0, 0))
	local destination = origin + forward * v.drive_speed * dt
	local resistance = Contacts.resistance(v, destination, Terrain.rotation(yaw, v.normal:unbox()))
	destination = origin + (destination - origin) * resistance
	yaw = v.yaw + v.turn_velocity * dt * resistance
	local old_normal = v.normal:unbox()
	local point, normal = Terrain.support(v.world, destination, yaw)
	if point then
		local tilt = math.acos(math.clamp(Vector3.dot(old_normal, normal), -1, 1))
		if tilt > 0 then
			local blend = math.min(1 - math.exp(-Settings.suspension_response * dt), Settings.suspension_speed * dt / tilt)
			normal = Vector3.normalize(Vector3.lerp(old_normal, normal, blend))
		end
	else
		normal = old_normal
	end
	yaw, normal = GroundMotion.turn(v, yaw, normal, vehicles, Terrain.rotation)
	local rotation = Terrain.rotation(yaw, normal)
	local height = Terrain.height(v.world, destination, rotation)
	destination.z = GroundInertia.height(v, height, dt)
	local position = Motion.translate(v, destination, rotation, vehicles)
	if position.z > destination.z + GROUND_EPSILON and v.vertical_speed < 0 then
		v.vertical_speed = 0
	end
	position = project_support(v, position, rotation, vehicles, dt)
	v.position:store(position)
	v.normal:store(normal)
	v.yaw = yaw
	v.turn = angle_delta(yaw, old_yaw) / dt
	local horizontal = Vector3.flat(position - origin)
	v.speed = Vector3.length(horizontal) / dt * (v.drive_speed < 0 and -1 or 1)
	-- A wall cannot accumulate engine speed that reappears when the obstruction clears.
	v.drive_speed = math.min(math.abs(v.drive_speed), math.abs(v.speed) / resistance) * (v.drive_speed < 0 and -1 or 1)
	v.turn_velocity = math.min(math.abs(v.turn_velocity), math.abs(v.turn) / resistance) * (v.turn_velocity < 0 and -1 or 1)
	v.left_speed = v.speed + v.turn * Settings.track_half_width
	v.right_speed = v.speed - v.turn * Settings.track_half_width
	GroundInertia.record(v, origin, dt)
end

Vehicle.step = function (v, input, dt, vehicles)
	if dt <= 0 then
		return
	end
	local count = math.ceil(dt / MAX_MOVEMENT_STEP)
	for _ = 1, count do
		local vectors, quaternions, matrices = Script.temp_count()
		move(v, input, dt / count, vehicles)
		Script.set_temp_count(vectors, quaternions, matrices)
	end
	local main = input.actions.main
	if main then
		local pivot = Vehicle.muzzle(v)
		local direction = View.direction(v, main.yaw, main.pitch, pivot, Settings.shot_range)
		local body = Terrain.rotation(v.yaw, v.normal:unbox())
		local main_direction = Quaternion.rotate(Quaternion.inverse(body), direction)
		local main_rotation = Quaternion.look(main_direction)
		local desired_yaw = v.yaw + Quaternion.yaw(main_rotation)
		local desired_pitch = (Quaternion.pitch(main_rotation) + math.pi) % TAU - math.pi
		local turn = math.clamp(angle_delta(desired_yaw, v.turret_yaw), -Settings.turret_speed * dt, Settings.turret_speed * dt)
		v.turret_yaw = v.turret_yaw + turn
		v.pitch = approach(v.pitch, math.clamp(desired_pitch, Settings.min_pitch, Settings.max_pitch), Settings.pitch_speed * dt)
	end
	local front = input.actions.front
	if not front then
		return
	end
	local body_rotation = Terrain.rotation(v.yaw, v.normal:unbox())
	local pivot = Vehicle.front_muzzle(v)
	local direction = View.direction(v, front.yaw, front.pitch, pivot, Settings.shot_range)
	local local_direction = Quaternion.rotate(Quaternion.inverse(body_rotation), direction)
	local front_rotation = Quaternion.look(local_direction)
	local front_yaw = angle_delta(Quaternion.yaw(front_rotation), 0)
	local front_pitch = angle_delta(Quaternion.pitch(front_rotation), 0)
	local target_yaw = math.clamp(front_yaw, -Settings.front_yaw_limit, Settings.front_yaw_limit)
	local target_pitch = math.clamp(front_pitch, Settings.front_min_pitch, Settings.front_max_pitch)
	v.front_yaw = approach(v.front_yaw, target_yaw, Settings.front_turn_speed * dt)
	v.front_pitch = approach(v.front_pitch, target_pitch, Settings.pitch_speed * dt)
end

Vehicle.animate = function (v, dt)
	v.left.phase = (v.left.phase - v.left_speed * dt / v.left.pitch) % TRACK_LINKS
	v.right.phase = (v.right.phase - v.right_speed * dt / v.right.pitch) % TRACK_LINKS
	local track_speed = math.max(math.abs(v.left_speed), math.abs(v.right_speed))
	WwiseWorld.set_source_parameter(v.wwise, v.source, "payload_speed", math.min(track_speed / Settings.forward_speed, 1))
	local delta = math.abs(angle_delta(v.turret_yaw, v.sound_yaw or v.turret_yaw))
	local moving = dt > 0 and delta / dt > TURRET_SOUND_STOP_SPEED
	v.turret_idle = moving and 0 or (v.turret_idle or 0) + dt
	v.turret_sound_anchor = v.turret_sound_anchor or v.turret_yaw
	local travel = math.abs(angle_delta(v.turret_yaw, v.turret_sound_anchor))
	if moving and not v.turret_moving and travel >= TURRET_SOUND_START_ANGLE then
		if v.turret_stop_event then
			WwiseWorld.stop_event(v.wwise, v.turret_stop_event)
			v.turret_stop_event = nil
		end
		v.turret_event = WwiseWorld.trigger_resource_event(v.wwise, "wwise/events/world/play_tank_mission_turret_move_start", v.source)
		v.turret_moving = true
	elseif v.turret_moving and v.turret_idle >= TURRET_SOUND_STOP_DELAY then
		WwiseWorld.stop_event(v.wwise, v.turret_event)
		v.turret_stop_event = WwiseWorld.trigger_resource_event(v.wwise, "wwise/events/world/play_tank_mission_turret_move_stop", v.source)
		v.turret_moving = false
		v.turret_sound_anchor = v.turret_yaw
	end
	v.sound_yaw = v.turret_yaw
end

local function pose_track (unit, track)
	for index, node in ipairs(track.nodes) do
		local sample = (index - 1 + track.phase) % TRACK_LINKS
		local first = math.floor(sample) + 1
		local second = first % TRACK_LINKS + 1
		local blend = sample - math.floor(sample)
		Unit.set_local_position(unit, node, Vector3.lerp(track.positions[first]:unbox(), track.positions[second]:unbox(), blend))
		Unit.set_local_rotation(unit, node, Quaternion.lerp(track.rotations[first]:unbox(), track.rotations[second]:unbox(), blend))
	end
end

Vehicle.pose = function (v)
	local body_rotation = Terrain.rotation(v.yaw, v.normal:unbox())
	Unit.set_local_position(v.unit, 1, v.position:unbox())
	Unit.set_local_rotation(v.unit, 1, body_rotation)
	Unit.set_local_rotation(v.unit, v.yaw_node, Quaternion.from_yaw_pitch_roll(angle_delta(v.turret_yaw, v.yaw), 0, 0))
	local front_rotation = Quaternion.from_yaw_pitch_roll(v.front_yaw, v.front_pitch, 0)
	local pivot = Vector3(unpack(FRONT_PIVOT))
	Unit.set_local_position(v.unit, v.front_node, pivot + Quaternion.rotate(front_rotation, v.front_rest_position:unbox() - pivot))
	Unit.set_local_rotation(v.unit, v.front_node, Quaternion.multiply(front_rotation, v.front_rest_rotation:unbox()))
	pose_track(v.unit, v.left)
	pose_track(v.unit, v.right)
	World.update_unit_and_children(v.world, v.unit)
end

Vehicle.muzzle = function (v)
	-- The stock visible barrel is rigid. Elevation affects the shot, not the mesh.
	local rotation = Quaternion.multiply(Unit.world_rotation(v.unit, v.yaw_node), Quaternion.from_yaw_pitch_roll(0, v.pitch, 0))
	return Unit.world_position(v.unit, v.muzzle_node), rotation
end

Vehicle.front_muzzle = function (v)
	local body = Unit.world_rotation(v.unit, 1)
	local rotation = Quaternion.multiply(body, Quaternion.from_yaw_pitch_roll(v.front_yaw, v.front_pitch, 0))
	local pivot = Vector3(unpack(FRONT_PIVOT))
	local offset = Quaternion.rotate(Quaternion.from_yaw_pitch_roll(v.front_yaw, v.front_pitch, 0), Vector3(unpack(FRONT_MUZZLE)) - pivot)
	return v.position:unbox() + Quaternion.rotate(body, pivot + offset), rotation
end

Vehicle.fire_fx = function (v)
	Vehicle.pose(v)
	local position, rotation = Vehicle.muzzle(v)
	World.create_particles(v.world, "content/fx/particles/environment/no_mans_land/tank_muzzle_flash", position, rotation)
end

Vehicle.destroy = function (v)
	for _, exhaust in ipairs(v.exhausts) do
		World.destroy_particles(v.world, exhaust.id)
	end
	World.destroy_particle_group(v.world, v.exhaust_group)
	WwiseWorld.stop_event(v.wwise, v.engine)
	if v.turret_moving then
		WwiseWorld.stop_event(v.wwise, v.turret_event)
	end
	if v.turret_stop_event then
		WwiseWorld.stop_event(v.wwise, v.turret_stop_event)
	end
	WwiseWorld.destroy_manual_source(v.wwise, v.source)
	World.destroy_unit(v.world, v.unit)
end

return Vehicle
