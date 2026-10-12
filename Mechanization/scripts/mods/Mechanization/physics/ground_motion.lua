local mod = get_mod("Mechanization")
local Motion = mod.load_module("physics/motion")
local GroundMotion = {}
local TURN_STEP = math.rad(1)

GroundMotion.turn = function (vehicle, target, normal, vehicles, rotation_at)
	local delta = (target - vehicle.yaw + math.pi) % (math.pi * 2) - math.pi
	local old_normal = vehicle.normal:unbox()
	local yaw, accepted_normal = vehicle.yaw, old_normal
	local count = math.max(1, math.ceil(math.abs(delta) / TURN_STEP))
	for index = 1, count do
		local candidate = vehicle.yaw + delta * index / count
		if not Motion.rotation_clear(vehicle, rotation_at(yaw, old_normal), rotation_at(candidate, old_normal), vehicles) then
			break
		end
		yaw = candidate
	end
	-- A blocked suspension adjustment must not cancel independently valid steering.
	local tilt = math.acos(math.clamp(Vector3.dot(old_normal, normal), -1, 1))
	count = math.max(1, math.ceil(tilt / TURN_STEP))
	for index = 1, count do
		local candidate = Vector3.normalize(Vector3.lerp(old_normal, normal, index / count))
		if not Motion.rotation_clear(vehicle, rotation_at(yaw, accepted_normal), rotation_at(yaw, candidate), vehicles) then
			break
		end
		accepted_normal = candidate
	end
	return yaw, accepted_normal
end

return GroundMotion
