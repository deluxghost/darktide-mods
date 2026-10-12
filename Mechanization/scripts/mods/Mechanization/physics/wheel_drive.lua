local mod = get_mod("Mechanization")
local Terrain = mod.load_module("physics/wheel_terrain")
local GroundMotion = mod.load_module("physics/ground_motion")
local GroundInertia = mod.load_module("physics/ground_inertia")
local Motion = mod.load_module("physics/motion")
local Contacts = mod.load_module("physics/contacts")
local WheelDrive = {}
local MAX_MOVEMENT_STEP = 1 / 60
local MIN_TRACTION_FRACTION = 0.01

local function approach (value, target, amount)
	return value + math.clamp(target - value, -amount, amount)
end

local function accelerate (speed, target, settings, dt)
	if speed * target < 0 then
		local stopping_time = math.abs(speed) / settings.braking_deceleration
		if stopping_time >= dt then
			return approach(speed, 0, settings.braking_deceleration * dt)
		end
		return approach(0, target, settings.acceleration * (dt - stopping_time))
	end
	local rate = math.abs(target) < math.abs(speed) and settings.braking_deceleration or settings.acceleration
	return approach(speed, target, rate * dt)
end

local function move (v, input, dt, vehicles)
	local settings = v.type.settings
	local origin = v.position:unbox()
	v.steering = approach(v.steering, -input.axes.steer * settings.steering_angle, settings.steering_speed * dt)
	local throttle = input.axes.throttle
	local target = throttle * (throttle >= 0 and settings.forward_speed or settings.reverse_speed)
	if not v.airborne and throttle ~= v.throttle and (target == 0 or target * v.drive_speed < 0) then
		v.drive_speed = math.min(math.abs(v.drive_speed), math.abs(v.speed)) * (v.drive_speed < 0 and -1 or 1)
	end
	v.throttle = throttle
	v.drive_speed = accelerate(v.drive_speed, target, settings, dt)
	local current_rotation = Terrain.rotation(v.yaw, v.normal:unbox())
	if GroundInertia.step(v, Terrain.height(v, origin, current_rotation), current_rotation, dt, vehicles) then
		v.wheel_speed = v.airborne and v.drive_speed or v.speed
		return
	end
	-- A bicycle steering model makes yaw proportional to actual wheel travel,
	-- so the vehicle cannot pivot at rest and reverse steering follows motion.
	local turn = math.clamp(math.tan(v.steering) * v.speed / settings.wheelbase, -settings.max_yaw_rate, settings.max_yaw_rate)
	local yaw = v.yaw + turn * dt
	local normal = v.normal:unbox()
	local forward = Quaternion.forward(Terrain.rotation(v.yaw + turn * dt * 0.5, normal))
	local destination = origin + forward * v.drive_speed * dt
	local resistance = Contacts.resistance(v, destination, Terrain.rotation(yaw, normal))
	destination = origin + (destination - origin) * resistance
	yaw = v.yaw + turn * dt * resistance
	local support = Terrain.support(v, destination, yaw)
	if support then
		local angle = math.acos(math.clamp(Vector3.dot(normal, support), -1, 1))
		if angle > 0 then
			local blend = math.min(1 - math.exp(-settings.suspension_response * dt), settings.suspension_speed * dt / angle)
			normal = Vector3.normalize(Vector3.lerp(normal, support, blend))
		end
	end
	yaw, normal = GroundMotion.turn(v, yaw, normal, vehicles, Terrain.rotation)
	local rotation = Terrain.rotation(yaw, normal)
	local height = Terrain.height(v, destination, rotation)
	destination.z = GroundInertia.height(v, height, dt)
	local position = Motion.translate(v, destination, rotation, vehicles)
	local floor = Terrain.height(v, position, rotation)
	if floor and position.z < floor - settings.suspension_travel then
		local lift = math.min(floor - settings.suspension_travel, position.z + settings.suspension_lift_speed * dt)
		v.position:store(position)
		position = Motion.translate(v, Vector3(position.x, position.y, lift), rotation, vehicles)
	end
	if floor and position.z <= floor + 0.01 and v.vertical_speed < 0 then
		v.vertical_speed = 0
	end
	local travel = Vector3.length(Vector3.flat(position - origin))
	v.speed = travel / dt * (v.drive_speed < 0 and -1 or 1)
	-- A glancing wall contact keeps tangential traction. Only a blocked chassis
	-- cancels drive speed; braking starts from the vehicle's actual travel speed.
	if travel < math.abs(v.drive_speed) * dt * resistance * MIN_TRACTION_FRACTION then
		v.drive_speed = 0
	end
	v.position:store(position)
	v.normal:store(normal)
	v.yaw = yaw
	v.wheel_speed = v.speed
	GroundInertia.record(v, origin, dt)
end

WheelDrive.step = function (v, input, dt, vehicles)
	if dt <= 0 then
		return
	end
	local count = math.ceil(dt / MAX_MOVEMENT_STEP)
	for _ = 1, count do
		local vectors, quaternions, matrices = Script.temp_count()
		move(v, input, dt / count, vehicles)
		Script.set_temp_count(vectors, quaternions, matrices)
	end
end

return WheelDrive
