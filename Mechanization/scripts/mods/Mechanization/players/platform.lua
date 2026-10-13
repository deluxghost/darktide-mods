local mod = get_mod("Mechanization")
local Collision = mod.load_module("physics/collision")
local Network = mod.load_module("network/transport")
local Surface = mod.load_module("physics/platform_surface")
local Platform = {}
local CONTACT_GAP = 0.03
local NETWORK_RESPONSE = 20
local MAX_WALK_STEP = 0.1
local MAX_SLIDES = 3
local SWEEP_SEARCH_STEPS = 10
local MIN_MOVE_SQUARED = 0.000001
local MAX_VERTICAL_SPEED = 20

local function settings (vehicle, occupant)
	return assert(vehicle.type.platforms[occupant.seat.platform], "Unknown vehicle platform")
end

local function constrain (vehicle, occupant, destination)
	local region = settings(vehicle, occupant)
	local radius = Collision.player_footprint(occupant.unit) + CONTACT_GAP
	destination.x = math.clamp(destination.x, region.min[1] + radius, region.max[1] - radius)
	destination.y = math.clamp(destination.y, region.min[2] + radius, region.max[2] - radius)
	return destination
end

local function slide_step (vehicle, occupant, position, destination)
	local remaining = Vector3.flat(destination - position)
	for _ = 1, MAX_SLIDES do
		if Vector3.length_squared(remaining) < MIN_MOVE_SQUARED then
			break
		end
		local candidate = constrain(vehicle, occupant, position + remaining)
		local height = Surface.height(vehicle, occupant, candidate)
		if height then
			return candidate
		end
		local low, high = 0, 1
		for _ = 1, SWEEP_SEARCH_STEPS do
			local fraction = (low + high) * 0.5
			local point = position + remaining * fraction
			local support = Surface.height(vehicle, occupant, point)
			if support then
				low = fraction
			else
				high = fraction
			end
		end
		position = position + remaining * low
		remaining = remaining * (1 - low)
		local normal = Surface.normal(vehicle, occupant, position)
		remaining = remaining - normal * math.min(0, Vector3.dot(remaining, normal))
	end
	return position
end

local function walk (vehicle, occupant, destination)
	local state = occupant.platform
	local origin = state.position:unbox()
	destination = constrain(vehicle, occupant, destination)
	local count = math.max(1, math.ceil(Vector3.length(Vector3.flat(destination - origin)) / MAX_WALK_STEP))
	local position = origin
	for index = 1, count do
		position = slide_step(vehicle, occupant, position, Vector3.lerp(origin, destination, index / count))
	end
	local floor = assert(Surface.height(vehicle, occupant, position), "Vehicle platform has no floor")
	local following_floor = state.grounded and destination.z <= origin.z
	position.z = following_floor and floor or math.max(floor, destination.z)
	return position, position.z <= floor + CONTACT_GAP
end

Platform.start = function (vehicle, occupant)
	local position = constrain(vehicle, occupant, Vector3(unpack(occupant.seat.position)))
	position.z = assert(Surface.height(vehicle, occupant, position), "Vehicle platform entry has no floor")
	occupant.platform = {
		position = Vector3Box(position),
		previous = Vector3Box(position),
		render = Vector3Box(position),
		target = Vector3Box(position),
		velocity = Vector3Box(Vector3.zero()),
		elapsed = 0,
		grounded = true,
	}
end

Platform.simulate = function (vehicle, occupant, locomotion, dt, t)
	local state = occupant.platform
	local component = locomotion._locomotion_component
	local inair = locomotion._inair_state_component
	if occupant.peer == Network.local_peer() and (not state.time or t > state.time) then
		local region = settings(vehicle, occupant)
		local steering = locomotion._locomotion_steering_component
		local velocity = locomotion:_handle_push_velocity(steering.velocity_wanted, inair.on_ground, dt, t)
		local inverse = Quaternion.inverse(Unit.world_rotation(vehicle.unit, 1))
		velocity = Quaternion.rotate(inverse, velocity)
		local speed = Vector3.length(Vector3.flat(velocity))
		if speed > region.max_speed then
			velocity.x, velocity.y = velocity.x * region.max_speed / speed, velocity.y * region.max_speed / speed
		end
		local jumping = locomotion._character_state_component.state_name == "jumping"
		-- Following a raised floor is support motion, not a new jump impulse.
		if state.grounded and not jumping then
			velocity.z = 0
		elseif steering.calculate_fall_velocity then
			velocity.z = Quaternion.rotate(inverse, component.velocity_current).z - locomotion._constants.gravity * dt
		end
		local origin = state.position:unbox()
		local position, grounded = walk(vehicle, occupant, origin + velocity * dt)
		state.previous:store(origin)
		state.position:store(position)
		local resolved_velocity = (position - origin) / dt
		if grounded then
			resolved_velocity.z = 0
		end
		state.velocity:store(resolved_velocity)
		state.elapsed = state.elapsed + dt
		state.time, state.dt = t, dt
		state.grounded = grounded
		inair.on_ground = grounded
		inair.flying_frames = grounded and 0 or inair.flying_frames + 1
		inair.standing_frames = grounded and inair.standing_frames + 1 or 0
		locomotion:_decay_push_velocity(grounded, dt, component.velocity_current)
	elseif occupant.peer ~= Network.local_peer() then
		inair.on_ground = state.grounded
		inair.flying_frames = inair.on_ground and 0 or 1
		inair.standing_frames = inair.on_ground and 1 or 0
	end
	local position = vehicle.position:unbox() + Quaternion.rotate(Unit.world_rotation(vehicle.unit, 1), state.position:unbox())
	component.position = position
	component.velocity_current = Quaternion.rotate(Unit.world_rotation(vehicle.unit, 1), state.velocity:unbox())
	component.velocity_current_before_z_stepup_cut = component.velocity_current
	inair.fell_from_height = position.z
	Mover.set_position(Unit.mover(occupant.unit), position)
	locomotion._old_position:store(position)
	locomotion._latest_simulated_position:store(position)
end

Platform.update = function (vehicle, dt)
	if not Network.is_host() then
		return
	end
	for _, occupant in pairs(vehicle.occupants) do
		local state = occupant.platform
		if state and occupant.peer ~= Network.local_peer() then
			state.position:store(Vector3.lerp(state.position:unbox(), state.target:unbox(), 1 - math.exp(-NETWORK_RESPONSE * dt)))
			state.render:store(state.position:unbox())
		end
	end
end

Platform.prepare = function (occupant, t)
	local state = occupant.platform
	if state and occupant.peer == Network.local_peer() and state.time then
		local fraction = math.clamp((t - state.time) / state.dt, 0, 1)
		state.render:store(Vector3.lerp(state.previous:unbox(), state.position:unbox(), fraction))
	end
end

Platform.snapshot = function (occupant)
	local state = occupant.platform
	if not state then
		return false
	end
	local position = occupant.peer == Network.local_peer() and state.position:unbox() or state.target:unbox()
	local velocity = state.velocity:unbox()
	return {
		p = { position.x, position.y, position.z },
		v = { velocity.x, velocity.y, velocity.z },
		time = state.elapsed,
		peer = occupant.peer,
		grounded = state.grounded,
	}
end

Platform.receive_input = function (vehicle, occupant, data, finite)
	assert(type(data) == "table" and type(data.p) == "table" and #data.p == 3, "Invalid platform position")
	assert(type(data.v) == "table" and #data.v == 3 and finite(data.time) and data.time >= 0, "Invalid platform movement")
	assert(type(data.grounded) == "boolean", "Invalid platform ground contact")
	assert(data.peer == occupant.peer, "Invalid platform input owner")
	local region = settings(vehicle, occupant)
	for index = 1, 3 do
		assert(finite(data.p[index]) and finite(data.v[index]), "Invalid platform coordinate")
		local limit = index == 3 and MAX_VERTICAL_SPEED or region.max_speed + CONTACT_GAP
		assert(math.abs(data.v[index]) <= limit, "Invalid platform velocity")
	end
	local state = occupant.platform
	if occupant.peer == Network.local_peer() or data.time <= state.elapsed then
		return
	end
	local position = Vector3(unpack(data.p))
	local bounded = constrain(vehicle, occupant, Vector3(unpack(data.p)))
	assert(Vector3.distance_squared(position, bounded) < CONTACT_GAP * CONTACT_GAP, "Platform position is outside its region")
	local distance = Vector3.length(Vector3.flat(position - state.target:unbox()))
	assert(distance <= region.max_speed * (data.time - state.elapsed) + CONTACT_GAP, "Platform movement exceeds walking speed")
	assert(position.z >= region.floor_height - CONTACT_GAP and position.z <= region.floor_height + region.jump_height, "Invalid platform height")
	state.target:store(position)
	state.velocity:store(Vector3(unpack(data.v)))
	state.elapsed = data.time
	state.grounded = data.grounded
end

Platform.interpolate = function (occupant, from, to, fraction)
	if not occupant.platform or occupant.peer == Network.local_peer() or not to or to.peer ~= occupant.peer then
		return
	end
	from = from and from.peer == to.peer and from or to
	local state = occupant.platform
	local position = Vector3.lerp(Vector3(unpack(from.p)), Vector3(unpack(to.p)), fraction)
	state.position:store(position)
	state.render:store(position)
	state.target:store(position)
	state.velocity:store(Vector3.lerp(Vector3(unpack(from.v)), Vector3(unpack(to.v)), fraction))
	state.grounded = to.grounded
end

return Platform
