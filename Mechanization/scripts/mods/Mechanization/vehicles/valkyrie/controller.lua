local mod = get_mod("Mechanization")
local Settings = mod.load_module("vehicles/valkyrie/settings")
local Collision = mod.load_module("physics/collision")
local Motion = mod.load_module("physics/motion")
local Contacts = mod.load_module("physics/contacts")
local ExtensionConfig = require("scripts/foundation/managers/extension/extension_config")
local Vehicle = {}
local MAX_MOVEMENT_STEP = 1 / 60
local ROTATION_STEP = math.rad(1)
local SPAWN_CLEARANCE = 2
local IGNITION_DURATION = 1

local function collect_parts (unit, parts)
	parts[unit] = true
	for _, child in pairs(Unit.get_child_units(unit) or {}) do
		collect_parts(child, parts)
	end
end

local function approach (value, target, amount)
	return value + math.clamp(target - value, -amount, amount)
end

local function angle_delta (target, current)
	return (target - current + math.pi) % (2 * math.pi) - math.pi
end

Vehicle.rotation = function (v)
	return Quaternion.from_yaw_pitch_roll(v.yaw, v.pitch, v.bank)
end

Vehicle.pose = function (v)
	Unit.set_local_position(v.unit, 1, v.position:unbox())
	Unit.set_local_rotation(v.unit, 1, Vehicle.rotation(v))
	World.update_unit_and_children(v.world, v.unit)
end

Vehicle.bounds = function (v)
	return Vector3(0, -0.8, 2.7), Vector3(2.2, 9.6, 2.5)
end

Vehicle.spawn_position = function (world, position)
	local hit, ground = PhysicsWorld.raycast(
		World.physics_world(world), position + Vector3.up() * 2, Vector3.down(), 8,
		"closest", "types", "statics", "collision_filter", "filter_player_mover"
	)
	return hit and ground + Vector3.up() * SPAWN_CLEARANCE
end

Vehicle.create = function (world, position, yaw)
	local unit = World.spawn_unit_ex(world, Settings.unit, nil, position, Quaternion.identity())
	local config = ExtensionConfig:new()
	config:add("ComponentExtension", {})
	Managers.state.extension:add_unit_extensions(world, unit, config)
	-- The original flying animation flips the authored, backward-facing skeleton.
	Unit.set_local_rotation(unit, Unit.node(unit, "anim_global"), Quaternion.axis_angle(Vector3.up(), math.pi))
	World.update_unit_and_children(world, unit)
	local parts = {}
	collect_parts(unit, parts)
	for part in pairs(parts) do
		Unit.set_unit_culling(part, false)
		for index = 1, Unit.num_actors(part) do
			local actor = Unit.actor(part, index)
			Actor.set_collision_enabled(actor, false)
			Actor.set_scene_query_enabled(actor, true)
		end
	end
	local body = Unit.get_data(unit, "attached_items", 1)
	Unit.flow_event(unit, "VFX_ignition_on")
	Unit.flow_event(unit, "VFX_thrusters_on")
	Unit.flow_event(unit, "VFX_vtol_thrusters_on")
	local wwise = Managers.world:wwise_world(world)
	local source = WwiseWorld.make_manual_source(wwise, unit, 1)
	return {
		unit = unit,
		parts = parts,
		hit_actor = Unit.actor(body, 1),
		world = world,
		position = Vector3Box(position),
		velocity = Vector3Box(Vector3.zero()),
		yaw = yaw,
		pitch = 0,
		yaw_velocity = 0,
		pitch_velocity = 0,
		bank = 0,
		speed = 0,
		wwise = wwise,
		source = source,
		ignition_elapsed = 0,
		laser_rounds = Settings.laser_capacity,
		rocket_rounds = Settings.rocket_capacity,
		next_laser = 0,
		next_rocket = 0,
		rocket_side = 1,
	}
end

Vehicle.can_spawn = function (v, vehicles, ignored_units)
	local position, rotation = v.position:unbox(), Vehicle.rotation(v)
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

local function turn_step (error, velocity, speed, acceleration, dt)
	local target = math.clamp(error * Settings.turn_response, -speed, speed)
	velocity = approach(velocity, target, acceleration * dt)
	local delta = velocity * dt
	if delta * error >= 0 and math.abs(delta) >= math.abs(error) then
		return error, 0
	end
	return delta, velocity
end

local function apply_rotation (v, yaw, pitch, bank, vehicles)
	local rotation = Quaternion.from_yaw_pitch_roll(yaw, pitch, bank)
	local position = Motion.rotation_position(v, Vehicle.rotation(v), rotation, vehicles)
	if not position then
		return false
	end
	v.position:store(position)
	v.yaw, v.pitch, v.bank = yaw, pitch, bank
	return true
end

local function rotate (v, controls, dt, vehicles)
	local delta
	delta, v.yaw_velocity = turn_step(angle_delta(controls.yaw, v.yaw), v.yaw_velocity, Settings.yaw_speed, Settings.yaw_acceleration, dt)
	local pitch_error = math.clamp(controls.pitch, Settings.min_pitch, Settings.max_pitch) - v.pitch
	local pitch_delta
	pitch_delta, v.pitch_velocity = turn_step(pitch_error, v.pitch_velocity, Settings.pitch_speed, Settings.pitch_acceleration, dt)
	local pitch = math.clamp(v.pitch + pitch_delta, Settings.min_pitch, Settings.max_pitch)
	if pitch ~= v.pitch + pitch_delta then
		v.pitch_velocity = 0
	end
	local heading = Quaternion.from_yaw_pitch_roll(v.yaw, 0, 0)
	local lateral = Vector3.dot(v.velocity:unbox(), Quaternion.right(heading)) / Settings.strafe_speed
	local bank = -Settings.bank_angle * math.clamp(v.yaw_velocity / Settings.yaw_speed + lateral * 0.5, -1, 1)
	bank = math.lerp(v.bank, bank, 1 - math.exp(-Settings.bank_response * dt))
	local count = math.max(1, math.ceil(math.max(math.abs(delta), math.abs(pitch - v.pitch), math.abs(bank - v.bank)) / ROTATION_STEP))
	local yaw, old_pitch, old_bank = v.yaw, v.pitch, v.bank
	for index = 1, count do
		local fraction = index / count
		local target_yaw = yaw + delta * fraction
		local target_pitch = math.lerp(old_pitch, pitch, fraction)
		local target_bank = math.lerp(old_bank, bank, fraction)
		if not apply_rotation(v, target_yaw, target_pitch, target_bank, vehicles) then
			if not apply_rotation(v, target_yaw, v.pitch, v.bank, vehicles) then
				v.yaw_velocity = 0
			end
			if not apply_rotation(v, v.yaw, target_pitch, v.bank, vehicles) then
				v.pitch_velocity = 0
			end
			apply_rotation(v, v.yaw, v.pitch, target_bank, vehicles)
		end
	end
end

local function accelerate (current, target, acceleration, braking, dt)
	local slowing = current * target < 0 or math.abs(target) < math.abs(current)
	return approach(current, target, (slowing and braking or acceleration) * dt)
end

local function step (v, controls, dt, vehicles)
	rotate(v, controls, dt, vehicles)
	local heading = Quaternion.from_yaw_pitch_roll(v.yaw, 0, 0)
	local throttle = controls.axes.throttle
	local forward_speed = throttle >= 0 and Settings.forward_speed or Settings.reverse_speed
	local local_velocity = Quaternion.rotate(Quaternion.inverse(heading), v.velocity:unbox())
	-- Horizontal thrust and lift have independent responses, including simultaneous input.
	local_velocity.x = accelerate(local_velocity.x, controls.axes.strafe * Settings.strafe_speed, Settings.acceleration, Settings.braking, dt)
	local_velocity.y = accelerate(local_velocity.y, throttle * forward_speed, Settings.acceleration, Settings.braking, dt)
	local_velocity.z = accelerate(local_velocity.z, controls.axes.lift * Settings.lift_speed, Settings.lift_acceleration, Settings.lift_braking, dt)
	local velocity = Quaternion.rotate(heading, local_velocity)
	local origin = v.position:unbox()
	local rotation = Vehicle.rotation(v)
	local resistance = Contacts.resistance(v, origin + velocity * dt, rotation)
	local destination = Motion.translate(v, origin + velocity * (dt * resistance), rotation, vehicles)
	-- Retain tangential velocity after contact; blocked velocity must not accumulate against a wall.
	local actual_velocity = (destination - origin) / dt
	velocity = actual_velocity / resistance
	v.position:store(destination)
	v.velocity:store(velocity)
	v.speed = Vector3.length(actual_velocity)
end

Vehicle.step = function (v, controls, dt, vehicles)
	if dt <= 0 then
		return
	end
	local count = math.max(1, math.ceil(dt / MAX_MOVEMENT_STEP))
	for _ = 1, count do
		step(v, controls, dt / count, vehicles)
	end
end

Vehicle.animate = function (v, dt)
	if v.ignition_elapsed then
		v.ignition_elapsed = v.ignition_elapsed + dt
		if v.ignition_elapsed >= IGNITION_DURATION then
			Unit.flow_event(v.unit, "VFX_ignition_off")
			v.ignition_elapsed = nil
		end
	end
end

Vehicle.destroy = function (v)
	WwiseWorld.destroy_manual_source(v.wwise, v.source)
	Unit.flow_event(v.unit, "VFX_off")
	Unit.flow_event(v.unit, "SFX_off")
	Managers.state.extension:unregister_unit(v.unit)
	for part in pairs(v.parts) do
		if Unit.alive(part) then
			World.destroy_unit(v.world, part)
		end
	end
end

return Vehicle
